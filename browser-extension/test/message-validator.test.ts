/**
 * Tests for message schema validation.
 * Validates that BrowserMessage parsing handles all edge cases correctly.
 */

import { describe, it, expect } from "vitest";
import { PROTOCOL_VERSION } from "../src/types";
import type {
  AnalyzeMediaMessage,
  DownloadRequestMessage,
  IncomingMessage,
  OutgoingMessage,
  PingMessage,
} from "../src/types";

// ── Minimal type-safe parse helpers ──────────────────────────────────────────
// Simulate the validation logic that the background script performs before
// forwarding to the native host.

function isValidOutgoingMessage(msg: unknown): msg is OutgoingMessage {
  if (typeof msg !== "object" || msg === null) return false;
  const m = msg as Record<string, unknown>;
  if (typeof m["version"] !== "number" || m["version"] < 1) return false;
  if (typeof m["requestId"] !== "string") return false;
  const validTypes = ["PING", "CONNECTION_STATUS", "ANALYZE_MEDIA", "DOWNLOAD_REQUEST"];
  return validTypes.includes(m["type"] as string);
}

function isValidUrl(url: unknown): boolean {
  if (typeof url !== "string" || !url) return false;
  try {
    const parsed = new URL(url);
    return parsed.protocol === "http:" || parsed.protocol === "https:";
  } catch {
    return false;
  }
}

function isLocalhostUrl(url: string): boolean {
  try {
    const parsed = new URL(url);
    return ["localhost", "127.0.0.1", "::1"].includes(parsed.hostname) ||
           parsed.hostname.startsWith("192.168.") ||
           parsed.hostname.startsWith("10.") ||
           parsed.hostname.startsWith("172.");
  } catch {
    return false;
  }
}

function validateDownloadRequest(msg: DownloadRequestMessage): string | null {
  if (!msg.url) return "URL is required.";
  if (!isValidUrl(msg.url)) return "Only HTTP/HTTPS URLs are supported.";
  if (isLocalhostUrl(msg.url)) return "Downloads from local addresses are not permitted.";
  return null; // valid
}

// ── Tests ─────────────────────────────────────────────────────────────────────

describe("Message validation", () => {

  describe("isValidOutgoingMessage", () => {
    it("accepts a valid PING message", () => {
      const msg: PingMessage = { version: 1, type: "PING", requestId: "r1" };
      expect(isValidOutgoingMessage(msg)).toBe(true);
    });

    it("accepts a valid ANALYZE_MEDIA message", () => {
      const msg: AnalyzeMediaMessage = {
        version: 1,
        type: "ANALYZE_MEDIA",
        requestId: "r2",
        url: "https://example.com/video.mp4",
        pageUrl: "https://example.com/watch",
        pageTitle: "Test",
      };
      expect(isValidOutgoingMessage(msg)).toBe(true);
    });

    it("rejects missing version", () => {
      expect(isValidOutgoingMessage({ type: "PING", requestId: "r1" })).toBe(false);
    });

    it("rejects missing requestId", () => {
      expect(isValidOutgoingMessage({ version: 1, type: "PING" })).toBe(false);
    });

    it("rejects unknown type", () => {
      expect(isValidOutgoingMessage({ version: 1, type: "EXECUTE_SHELL", requestId: "r1" })).toBe(false);
    });

    it("rejects non-object", () => {
      expect(isValidOutgoingMessage("string")).toBe(false);
      expect(isValidOutgoingMessage(null)).toBe(false);
      expect(isValidOutgoingMessage(42)).toBe(false);
    });
  });

  describe("URL validation", () => {
    it("accepts http URL", () => {
      expect(isValidUrl("http://example.com/video.mp4")).toBe(true);
    });

    it("accepts https URL", () => {
      expect(isValidUrl("https://example.com/video.mp4")).toBe(true);
    });

    it("rejects ftp URL", () => {
      expect(isValidUrl("ftp://example.com/video.mp4")).toBe(false);
    });

    it("rejects javascript: URL", () => {
      expect(isValidUrl("javascript:alert(1)")).toBe(false);
    });

    it("rejects file: URL", () => {
      expect(isValidUrl("file:///etc/passwd")).toBe(false);
    });

    it("rejects empty string", () => {
      expect(isValidUrl("")).toBe(false);
    });

    it("rejects malformed URL", () => {
      expect(isValidUrl("not a url")).toBe(false);
    });

    it("rejects data: URI", () => {
      expect(isValidUrl("data:video/mp4;base64,AAAA")).toBe(false);
    });
  });

  describe("Localhost detection", () => {
    it("detects localhost", () => {
      expect(isLocalhostUrl("http://localhost:8080/video")).toBe(true);
    });

    it("detects 127.0.0.1", () => {
      expect(isLocalhostUrl("http://127.0.0.1/video")).toBe(true);
    });

    it("detects 192.168.x.x", () => {
      expect(isLocalhostUrl("http://192.168.1.1/media")).toBe(true);
    });

    it("does not flag public IP", () => {
      expect(isLocalhostUrl("https://203.0.113.5/video.mp4")).toBe(false);
    });

    it("does not flag normal domain", () => {
      expect(isLocalhostUrl("https://example.com/video.mp4")).toBe(false);
    });
  });

  describe("validateDownloadRequest", () => {
    const base: DownloadRequestMessage = {
      version: 1,
      type: "DOWNLOAD_REQUEST",
      requestId: "r1",
      url: "https://example.com/video.mp4",
      pageUrl: "https://example.com",
      pageTitle: "Test",
    };

    it("returns null for valid request", () => {
      expect(validateDownloadRequest(base)).toBeNull();
    });

    it("returns error for empty URL", () => {
      expect(validateDownloadRequest({ ...base, url: "" })).toBeTruthy();
    });

    it("returns error for localhost URL", () => {
      expect(validateDownloadRequest({ ...base, url: "http://localhost/api" })).toBeTruthy();
    });

    it("returns error for ftp: scheme", () => {
      expect(validateDownloadRequest({ ...base, url: "ftp://example.com/file.mp4" })).toBeTruthy();
    });
  });

  describe("Protocol version", () => {
    it("is a positive integer", () => {
      expect(PROTOCOL_VERSION).toBeGreaterThan(0);
      expect(Number.isInteger(PROTOCOL_VERSION)).toBe(true);
    });

    it("is included in outgoing messages", () => {
      const msg: PingMessage = { version: PROTOCOL_VERSION, type: "PING", requestId: "r1" };
      expect(msg.version).toBe(PROTOCOL_VERSION);
    });
  });

  describe("Incoming message types", () => {
    it("DOWNLOAD_ACCEPTED has taskId", () => {
      const msg: IncomingMessage = {
        version: 1,
        type: "DOWNLOAD_ACCEPTED",
        requestId: "r1",
        taskId: "task-xyz",
      };
      expect(msg.taskId).toBe("task-xyz");
    });

    it("DOWNLOAD_REJECTED has error", () => {
      const msg: IncomingMessage = {
        version: 1,
        type: "DOWNLOAD_REJECTED",
        requestId: "r1",
        error: "URL not supported",
      };
      expect(msg.error).toBeTruthy();
    });

    it("ERROR has error message", () => {
      const msg: IncomingMessage = {
        version: 1,
        type: "ERROR",
        requestId: "",
        error: "Malformed JSON",
      };
      expect(msg.error).toBeTruthy();
    });
  });
});
