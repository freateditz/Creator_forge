/**
 * MediaDetector — discovers downloadable media candidates from the live DOM.
 *
 * Runs inside the content-script context. Inspects HTMLVideoElement and
 * HTMLAudioElement nodes, their <source> children, and media lifecycle events.
 * Uses a MutationObserver to catch dynamically added elements, cleaned up when
 * the detector is destroyed.
 *
 * Security notes:
 * - This code never uploads media URLs to any external server.
 * - It only reads URLs already exposed by the page DOM to the content script.
 * - Blob URLs, data: URIs, and empty src values are flagged as non-downloadable.
 * - DRM-protected streams are detected heuristically and flagged accordingly.
 */

import type {
  DetectionSource,
  DownloadabilityStatus,
  MediaCandidate,
  MediaElementType,
} from "./types";

let _candidateCounter = 0;

function _makeId(url: string): string {
  // Stable ID derived from normalized URL — used for deduplication.
  let hash = 0;
  for (let i = 0; i < url.length; i++) {
    hash = ((hash << 5) - hash + url.charCodeAt(i)) | 0;
  }
  return `cf-${(hash >>> 0).toString(36)}`;
}

function _guessDownloadability(
  url: string,
  mimeType?: string
): DownloadabilityStatus {
  if (!url) return "unsupported";
  if (url.startsWith("blob:")) return "blob";
  if (url.startsWith("data:")) return "unsupported";
  if (url.startsWith("mediastream:")) return "unsupported";
  if (!url.startsWith("http://") && !url.startsWith("https://")) {
    return "unsupported";
  }

  const lower = url.toLowerCase();

  // Known DRM-protected stream patterns (EME/Widevine/PlayReady indicators).
  if (lower.includes("widevine") || lower.includes("playready")) return "drm-protected";
  if (mimeType?.includes("com.widevine") || mimeType?.includes("com.microsoft.playready")) {
    return "drm-protected";
  }

  // HLS / DASH manifests — eligible but not a single standalone file.
  if (lower.endsWith(".m3u8") || lower.includes(".m3u8?") ||
      lower.endsWith(".mpd")  || lower.includes(".mpd?")) {
    return "stream";
  }

  // Direct media extensions.
  const directExts = [".mp4", ".webm", ".mkv", ".mov", ".avi",
                      ".mp3", ".m4a", ".ogg", ".opus", ".wav", ".flac",
                      ".ts", ".m2ts"];
  if (directExts.some((e) => lower.includes(e))) return "direct";

  // CDN-style media URLs (no recognizable extension).
  if (
    mimeType?.startsWith("video/") ||
    mimeType?.startsWith("audio/")
  ) return "direct";

  return "unknown";
}

function _extractFromElement(
  el: HTMLVideoElement | HTMLAudioElement,
  pageUrl: string,
  pageTitle: string,
  source: DetectionSource
): MediaCandidate[] {
  const results: MediaCandidate[] = [];
  const seen = new Set<string>();
  const elementType: MediaElementType = el instanceof HTMLVideoElement ? "video" : "audio";

  const pushCandidate = (
    url: string,
    mimeType?: string,
    width?: number,
    height?: number
  ): void => {
    const normalized = url.split("#")[0];  // strip fragment
    if (!normalized || seen.has(normalized)) return;
    seen.add(normalized);

    results.push({
      id: _makeId(normalized),
      url: normalized,
      pageUrl,
      pageTitle,
      elementType,
      mimeType,
      durationSeconds: Number.isFinite(el.duration) && el.duration > 0
        ? Math.round(el.duration)
        : undefined,
      width,
      height,
      detectionSource: source,
      downloadability: _guessDownloadability(normalized, mimeType),
      detectedAt: Date.now(),
    });
  };

  // Primary src attribute.
  if (el.src && !el.src.startsWith("about:")) {
    const w = el instanceof HTMLVideoElement ? el.videoWidth || undefined : undefined;
    const h = el instanceof HTMLVideoElement ? el.videoHeight || undefined : undefined;
    pushCandidate(el.src, el instanceof HTMLVideoElement ? "video/mp4" : "audio/mpeg", w, h);
  }

  // currentSrc (resolved after preload).
  if (el.currentSrc && el.currentSrc !== el.src) {
    pushCandidate(el.currentSrc);
  }

  // <source> children.
  el.querySelectorAll("source").forEach((s) => {
    if (s.src) pushCandidate(s.src, s.type || undefined);
  });

  return results;
}

export class MediaDetector {
  private _observer: MutationObserver | null = null;
  private _candidates = new Map<string, MediaCandidate>();
  private _onChange: ((candidates: MediaCandidate[]) => void) | null = null;

  constructor(onChange?: (candidates: MediaCandidate[]) => void) {
    this._onChange = onChange ?? null;
  }

  /** Run a full DOM scan and return all detected candidates. */
  scan(): MediaCandidate[] {
    this._candidates.clear();
    const pageUrl = location.href;
    const pageTitle = document.title || pageUrl;

    document
      .querySelectorAll<HTMLVideoElement | HTMLAudioElement>("video, audio")
      .forEach((el) => {
        const candidates = _extractFromElement(el, pageUrl, pageTitle, "html-video");
        candidates.forEach((c) => this._candidates.set(c.id, c));
        this._attachListeners(el);
      });

    return this._getAll();
  }

  /** Start watching for dynamically added/changed media elements. */
  observe(): void {
    if (this._observer) return;
    this._observer = new MutationObserver((mutations) => {
      let changed = false;
      for (const mut of mutations) {
        for (const node of Array.from(mut.addedNodes)) {
          if (node instanceof HTMLVideoElement || node instanceof HTMLAudioElement) {
            const cs = _extractFromElement(
              node,
              location.href,
              document.title,
              "mutation-observer"
            );
            cs.forEach((c) => { this._candidates.set(c.id, c); changed = true; });
            this._attachListeners(node);
          }
        }
      }
      if (changed) this._notify();
    });

    this._observer.observe(document.body || document.documentElement, {
      childList: true,
      subtree: true,
    });
  }

  /** Detach the MutationObserver and clean up. */
  destroy(): void {
    this._observer?.disconnect();
    this._observer = null;
    this._onChange = null;
  }

  getCandidates(): MediaCandidate[] {
    return this._getAll();
  }

  clear(): void {
    this._candidates.clear();
    this._notify();
  }

  private _getAll(): MediaCandidate[] {
    return Array.from(this._candidates.values()).sort(
      (a, b) => a.detectedAt - b.detectedAt
    );
  }

  private _notify(): void {
    this._onChange?.(this._getAll());
  }

  /** Listen for src-change events so we can update when playback changes. */
  private _attachListeners(el: HTMLVideoElement | HTMLAudioElement): void {
    const handler = () => {
      const cs = _extractFromElement(
        el,
        location.href,
        document.title,
        "html-video"
      );
      let changed = false;
      cs.forEach((c) => {
        if (!this._candidates.has(c.id) ||
            this._candidates.get(c.id)!.url !== c.url) {
          this._candidates.set(c.id, c);
          changed = true;
        }
      });
      if (changed) this._notify();
    };

    el.addEventListener("loadedmetadata", handler, { passive: true });
    el.addEventListener("emptied", handler, { passive: true });
  }
}
