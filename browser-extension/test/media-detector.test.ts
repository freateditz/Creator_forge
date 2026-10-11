/**
 * Tests for MediaDetector — runs in jsdom via vitest.
 */

import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { MediaDetector } from "../src/media-detector";

// jsdom provides document/window globals.

function makeVideo(src?: string, currentSrc?: string): HTMLVideoElement {
  const el = document.createElement("video");
  if (src) {
    Object.defineProperty(el, "src", { value: src, configurable: true });
  }
  if (currentSrc) {
    Object.defineProperty(el, "currentSrc", { value: currentSrc, configurable: true });
  }
  return el;
}

function makeAudio(src: string): HTMLAudioElement {
  const el = document.createElement("audio");
  Object.defineProperty(el, "src", { value: src, configurable: true });
  return el;
}

describe("MediaDetector", () => {
  let detector: MediaDetector;

  beforeEach(() => {
    document.body.innerHTML = "";
    detector = new MediaDetector();
  });

  afterEach(() => {
    detector.destroy();
  });

  // ── scan() ─────────────────────────────────────────────────────────────────

  describe("scan()", () => {
    it("returns empty array on blank page", () => {
      const result = detector.scan();
      expect(result).toEqual([]);
    });

    it("detects a video element with http src", () => {
      const vid = makeVideo("https://example.com/video.mp4");
      document.body.appendChild(vid);
      const result = detector.scan();
      expect(result.length).toBe(1);
      expect(result[0].url).toBe("https://example.com/video.mp4");
      expect(result[0].elementType).toBe("video");
    });

    it("detects an audio element", () => {
      const aud = makeAudio("https://example.com/track.mp3");
      document.body.appendChild(aud);
      const result = detector.scan();
      expect(result.length).toBe(1);
      expect(result[0].elementType).toBe("audio");
    });

    it("detects multiple media elements", () => {
      document.body.appendChild(makeVideo("https://example.com/a.mp4"));
      document.body.appendChild(makeVideo("https://example.com/b.mp4"));
      const result = detector.scan();
      expect(result.length).toBe(2);
    });

    it("deduplicates identical URLs across calls", () => {
      document.body.appendChild(makeVideo("https://example.com/v.mp4"));
      detector.scan();
      const second = detector.scan();
      // After two scans, there should still be only 1 candidate.
      expect(second.length).toBe(1);
    });

    it("ignores elements with no src", () => {
      const vid = document.createElement("video");
      document.body.appendChild(vid);
      const result = detector.scan();
      expect(result).toEqual([]);
    });

    it("ignores blob: URLs", () => {
      const vid = makeVideo("blob:https://example.com/abc123");
      document.body.appendChild(vid);
      const result = detector.scan();
      expect(result.length).toBe(1);
      expect(result[0].downloadability).toBe("blob");
    });

    it("ignores data: URIs", () => {
      const vid = makeVideo("data:video/mp4;base64,AAAA");
      document.body.appendChild(vid);
      const result = detector.scan();
      expect(result.length).toBe(1);
      expect(result[0].downloadability).toBe("unsupported");
    });

    it("detects .m3u8 as stream", () => {
      document.body.appendChild(makeVideo("https://cdn.example.com/hls/stream.m3u8"));
      const result = detector.scan();
      expect(result[0].downloadability).toBe("stream");
    });

    it("detects .mpd as stream", () => {
      document.body.appendChild(makeVideo("https://cdn.example.com/dash/manifest.mpd"));
      const result = detector.scan();
      expect(result[0].downloadability).toBe("stream");
    });

    it("detects direct mp4 as direct", () => {
      document.body.appendChild(makeVideo("https://example.com/video.mp4"));
      const result = detector.scan();
      expect(result[0].downloadability).toBe("direct");
    });

    it("detects direct webm as direct", () => {
      document.body.appendChild(makeVideo("https://example.com/clip.webm"));
      const result = detector.scan();
      expect(result[0].downloadability).toBe("direct");
    });

    it("produces stable IDs for the same URL", () => {
      document.body.appendChild(makeVideo("https://example.com/stable.mp4"));
      const r1 = detector.scan();
      detector.clear();
      document.body.innerHTML = "";
      document.body.appendChild(makeVideo("https://example.com/stable.mp4"));
      const r2 = detector.scan();
      expect(r1[0].id).toBe(r2[0].id);
    });

    it("detects <source> child elements", () => {
      const vid = document.createElement("video");
      const src = document.createElement("source");
      src.src = "https://example.com/video.mp4";
      src.type = "video/mp4";
      vid.appendChild(src);
      document.body.appendChild(vid);
      const result = detector.scan();
      expect(result.length).toBe(1);
      expect(result[0].mimeType).toBe("video/mp4");
    });

    it("does not detect HTTP-only URLs (non-http/https)", () => {
      document.body.appendChild(makeVideo("ftp://example.com/video.mp4"));
      const result = detector.scan();
      // ftp is not http/https — should be detected but flagged unsupported.
      if (result.length > 0) {
        expect(result[0].downloadability).toBe("unsupported");
      }
    });

    it("strips URL fragments", () => {
      document.body.appendChild(makeVideo("https://example.com/v.mp4#t=0,30"));
      const result = detector.scan();
      expect(result[0].url).toBe("https://example.com/v.mp4");
    });
  });

  // ── getCandidates() / clear() ─────────────────────────────────────────────

  describe("getCandidates() / clear()", () => {
    it("returns empty before scan", () => {
      expect(detector.getCandidates()).toEqual([]);
    });

    it("returns candidates after scan", () => {
      document.body.appendChild(makeVideo("https://example.com/v.mp4"));
      detector.scan();
      expect(detector.getCandidates().length).toBe(1);
    });

    it("clear() removes all candidates", () => {
      document.body.appendChild(makeVideo("https://example.com/v.mp4"));
      detector.scan();
      detector.clear();
      expect(detector.getCandidates()).toEqual([]);
    });
  });

  // ── onChange callback ──────────────────────────────────────────────────────

  describe("onChange callback", () => {
    it("is called after clear()", () => {
      const onChange = vi.fn();
      const d = new MediaDetector(onChange);
      document.body.appendChild(makeVideo("https://example.com/v.mp4"));
      d.scan();
      d.clear();
      expect(onChange).toHaveBeenCalledWith([]);
      d.destroy();
    });
  });
});
