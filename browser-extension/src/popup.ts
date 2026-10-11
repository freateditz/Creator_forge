/**
 * Popup script — controls the extension popup UI.
 *
 * Communicates with the background service worker via chrome.runtime.sendMessage.
 * Never communicates directly with the native host or any external service.
 */

import type {
  AnalysisResult,
  BgToPopupMsg,
  ConnectionState,
  DownloadType,
  MediaCandidate,
  MediaFormat,
  PopupToBgMsg,
} from "./types";

// ── DOM references ────────────────────────────────────────────────────────────

const $ = <T extends HTMLElement>(id: string): T =>
  document.getElementById(id) as T;

const statusDot = $<HTMLElement>("status-dot");
const statusLabel = $<HTMLElement>("status-label");
const pageTitle = $<HTMLElement>("page-title");
const pageDomain = $<HTMLElement>("page-domain");
const mediaList = $<HTMLElement>("media-list");
const emptyState = $<HTMLElement>("empty-state");
const refreshBtn = $<HTMLButtonElement>("refresh-btn");
const clearBtn = $<HTMLButtonElement>("clear-btn");
const setupLink = $<HTMLAnchorElement>("setup-link");

// ── State ─────────────────────────────────────────────────────────────────────

let connectionState: ConnectionState = "disconnected";
let candidates: MediaCandidate[] = [];
let analysisByUrl = new Map<string, AnalysisResult>();
let pendingDownloads = new Set<string>();

// ── IPC helpers ───────────────────────────────────────────────────────────────

function send(msg: PopupToBgMsg): Promise<unknown> {
  return chrome.runtime.sendMessage(msg);
}

// ── Rendering ─────────────────────────────────────────────────────────────────

function renderConnection(state: ConnectionState): void {
  connectionState = state;
  statusDot.dataset["state"] = state;
  statusLabel.textContent = {
    disconnected: "Not connected",
    connecting: "Connecting…",
    connected: "Connected",
    error: "Connection error",
  }[state];
}

function renderCandidates(items: MediaCandidate[]): void {
  candidates = items;

  if (items.length === 0) {
    mediaList.innerHTML = "";
    emptyState.hidden = false;
    clearBtn.disabled = true;
    return;
  }

  emptyState.hidden = true;
  clearBtn.disabled = false;

  mediaList.innerHTML = "";
  items.forEach((c) => {
    const card = buildCandidateCard(c);
    mediaList.appendChild(card);
  });
}

function buildCandidateCard(c: MediaCandidate): HTMLElement {
  const analysis = analysisByUrl.get(c.url);
  const isPending = pendingDownloads.has(c.url);

  const card = document.createElement("div");
  card.className = "media-card";
  card.dataset["id"] = c.id;

  // ── Header row ──
  const header = document.createElement("div");
  header.className = "media-card-header";

  const icon = document.createElement("span");
  icon.className = "media-icon";
  icon.textContent = c.elementType === "audio" ? "🎵" : "🎬";
  header.appendChild(icon);

  const info = document.createElement("div");
  info.className = "media-info";

  const title = document.createElement("div");
  title.className = "media-title";
  title.textContent = analysis?.title || _basename(c.url);
  info.appendChild(title);

  const meta = document.createElement("div");
  meta.className = "media-meta";
  const parts: string[] = [];
  if (analysis?.durationSeconds) parts.push(_formatDuration(analysis.durationSeconds));
  if (c.width && c.height) parts.push(`${c.width}×${c.height}`);
  parts.push(_downloadabilityLabel(c));
  meta.textContent = parts.join(" · ");
  info.appendChild(meta);

  header.appendChild(info);
  card.appendChild(header);

  // ── Format selector (shown after analysis) ──
  if (analysis?.formats && analysis.formats.length > 0 && !analysis.isDirectDownload) {
    const formatRow = document.createElement("div");
    formatRow.className = "format-row";

    const select = document.createElement("select");
    select.id = `fmt-${c.id}`;
    analysis.formats.forEach((f) => {
      const opt = document.createElement("option");
      opt.value = f.id;
      opt.textContent = f.label;
      select.appendChild(opt);
    });
    formatRow.appendChild(select);
    card.appendChild(formatRow);
  }

  // ── Action row ──
  const actions = document.createElement("div");
  actions.className = "card-actions";

  const canDownload =
    c.downloadability !== "drm-protected" &&
    c.downloadability !== "unsupported" &&
    connectionState === "connected";

  if (!analysis && canDownload) {
    const analyzeBtn = document.createElement("button");
    analyzeBtn.className = "btn btn-outline";
    analyzeBtn.textContent = "Analyze";
    analyzeBtn.addEventListener("click", () => onAnalyze(c));
    actions.appendChild(analyzeBtn);
  }

  if (canDownload) {
    const downloadBtn = document.createElement("button");
    downloadBtn.className = "btn btn-primary";
    downloadBtn.disabled = isPending;
    downloadBtn.textContent = isPending ? "Sending…" : "Send to CreatorForge";
    downloadBtn.addEventListener("click", () => {
      const select = document.getElementById(`fmt-${c.id}`) as HTMLSelectElement | null;
      const fmt = select?.value || undefined;
      onDownload(c, fmt);
    });
    actions.appendChild(downloadBtn);
  }

  if (c.downloadability === "drm-protected") {
    const label = document.createElement("span");
    label.className = "status-label status-drm";
    label.textContent = "Protected — cannot download";
    actions.appendChild(label);
  }

  if (c.downloadability === "blob") {
    const label = document.createElement("span");
    label.className = "status-label status-info";
    label.textContent = "Blob URL — use page controls";
    actions.appendChild(label);
  }

  if (c.downloadability === "unsupported") {
    const label = document.createElement("span");
    label.className = "status-label status-dim";
    label.textContent = "Unsupported source";
    actions.appendChild(label);
  }

  if (connectionState !== "connected" && c.downloadability !== "drm-protected") {
    const label = document.createElement("span");
    label.className = "status-label status-error";
    label.textContent = "CreatorForge not connected";
    actions.appendChild(label);
  }

  card.appendChild(actions);
  return card;
}

// ── Actions ───────────────────────────────────────────────────────────────────

async function onAnalyze(c: MediaCandidate): Promise<void> {
  const result = await send({ kind: "analyze", candidate: c } as PopupToBgMsg) as
    | { ok: true; result: AnalysisResult }
    | { ok: false; error: string };

  if (result?.ok) {
    analysisByUrl.set(c.url, result.result);
  }
  renderCandidates(candidates);
}

async function onDownload(c: MediaCandidate, formatSelector?: string): Promise<void> {
  pendingDownloads.add(c.url);
  renderCandidates(candidates);

  const downloadType: DownloadType =
    c.elementType === "audio" ? "audioOnly" : "videoAndAudio";

  const result = await send({
    kind: "download",
    candidate: c,
    formatSelector,
    downloadType,
  } as PopupToBgMsg) as
    | { ok: true; taskId: string }
    | { ok: false; error: string };

  pendingDownloads.delete(c.url);

  if (result?.ok) {
    showToast("Sent to CreatorForge ✓", "success");
  } else {
    showToast(result?.error ?? "Failed to send", "error");
  }

  renderCandidates(candidates);
}

// ── Toast ──────────────────────────────────────────────────────────────────────

function showToast(msg: string, kind: "success" | "error"): void {
  const existing = document.getElementById("toast");
  if (existing) existing.remove();

  const el = document.createElement("div");
  el.id = "toast";
  el.className = `toast toast-${kind}`;
  el.textContent = msg;
  document.body.appendChild(el);
  setTimeout(() => el.remove(), 3000);
}

// ── Utilities ─────────────────────────────────────────────────────────────────

function _basename(url: string): string {
  try {
    const path = new URL(url).pathname;
    return path.split("/").filter(Boolean).pop() || url;
  } catch {
    return url;
  }
}

function _formatDuration(s: number): string {
  if (s < 60) return `${s}s`;
  const m = Math.floor(s / 60);
  const sec = s % 60;
  if (m < 60) return `${m}:${String(sec).padStart(2, "0")}`;
  const h = Math.floor(m / 60);
  const min = m % 60;
  return `${h}:${String(min).padStart(2, "0")}:${String(sec).padStart(2, "0")}`;
}

function _downloadabilityLabel(c: MediaCandidate): string {
  return {
    direct: "Direct",
    stream: "Stream",
    blob: "Blob",
    "drm-protected": "DRM",
    unsupported: "Unsupported",
    unknown: "Detected",
  }[c.downloadability];
}

// ── Background message listener ───────────────────────────────────────────────

chrome.runtime.onMessage.addListener((message: BgToPopupMsg) => {
  switch (message.kind) {
    case "candidates-updated":
      renderCandidates(message.candidates);
      break;
    case "connection-state":
      renderConnection(message.state);
      renderCandidates(candidates); // re-render to update button states
      break;
    case "analysis-result":
      if (message.result) {
        analysisByUrl.set(message.result.url, message.result);
        renderCandidates(candidates);
      }
      break;
  }
});

// ── Initialise on popup open ─────────────────────────────────────────────────

async function init(): Promise<void> {
  // Get page info.
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (tab) {
    pageTitle.textContent = tab.title || "Unknown page";
    try {
      const url = new URL(tab.url ?? "");
      pageDomain.textContent = url.hostname;
    } catch {
      pageDomain.textContent = "";
    }
  }

  // Get current state.
  const state = await send({ kind: "get-connection-state" } as PopupToBgMsg) as ConnectionState;
  renderConnection(state);

  const items = await send({ kind: "get-candidates" } as PopupToBgMsg) as MediaCandidate[];
  renderCandidates(items ?? []);

  // Trigger a fresh scan.
  await send({ kind: "refresh-detection" } as PopupToBgMsg);
}

refreshBtn.addEventListener("click", async () => {
  await send({ kind: "refresh-detection" } as PopupToBgMsg);
});

clearBtn.addEventListener("click", async () => {
  analysisByUrl.clear();
  pendingDownloads.clear();
  await send({ kind: "clear-candidates" } as PopupToBgMsg);
});

setupLink.addEventListener("click", (e) => {
  e.preventDefault();
  chrome.tabs.create({ url: "https://github.com/creatorforge/setup" });
});

document.addEventListener("DOMContentLoaded", () => { init().catch(console.error); });
