/**
 * Content script — runs in the context of each page.
 *
 * Responsibilities:
 * - Instantiate MediaDetector to scan the live DOM.
 * - Start observing for dynamic media element additions.
 * - Respond to "scan" requests from the background service worker.
 * - Push updated candidate lists back to the background.
 *
 * Security notes:
 * - Only communicates with the extension's own service worker via
 *   chrome.runtime.sendMessage (no cross-origin messaging).
 * - Does not modify the page DOM in any way that could affect site behaviour.
 */

import { MediaDetector } from "./media-detector";
import type { BackgroundToContentMsg, ContentToBackgroundMsg } from "./types";

let detector: MediaDetector | null = null;

function getOrCreateDetector(): MediaDetector {
  if (!detector) {
    detector = new MediaDetector((candidates) => {
      const msg: ContentToBackgroundMsg = { kind: "candidates", candidates };
      chrome.runtime.sendMessage(msg).catch(() => {
        // Background may be restarting; ignore the error.
      });
    });
    detector.observe();
  }
  return detector;
}

function runScan(): void {
  const d = getOrCreateDetector();
  const candidates = d.scan();
  const msg: ContentToBackgroundMsg = { kind: "candidates", candidates };
  chrome.runtime.sendMessage(msg).catch(() => {});
}

// ── Listen for scan requests from background ──────────────────────────────────

chrome.runtime.onMessage.addListener(
  (message: BackgroundToContentMsg, _sender, sendResponse) => {
    if (message.kind === "scan") {
      const d = getOrCreateDetector();
      const candidates = d.scan();
      sendResponse(candidates);
    }
    return false; // synchronous response
  }
);

// ── Initial scan on page load (document_idle) ─────────────────────────────────

runScan();
