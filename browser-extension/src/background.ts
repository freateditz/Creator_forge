/**
 * Background service worker — the hub of the CreatorForge extension.
 *
 * Responsibilities:
 * - Manage the Native Messaging port to the desktop application.
 * - Route analysis and download requests to the native host.
 * - Cache the latest media candidates per tab.
 * - Notify the popup of state changes.
 * - Keep the badge count updated.
 *
 * Security notes:
 * - All messages received from content scripts are treated as untrusted and
 *   forwarded to the desktop app for independent validation.
 * - No browsing history is recorded.
 * - No data is sent to any external server; all communication is local-only.
 */

import {
  NATIVE_HOST_NAME,
  PROTOCOL_VERSION,
  ANALYSIS_TIMEOUT_MS,
  MAX_CANDIDATES,
} from "./types";
import type {
  BgToPopupMsg,
  ConnectionState,
  ContentToBackgroundMsg,
  DownloadType,
  IncomingMessage,
  MediaCandidate,
  PopupToBgMsg,
} from "./types";

// ── State ────────────────────────────────────────────────────────────────────

let nativePort: chrome.runtime.Port | null = null;
let connectionState: ConnectionState = "disconnected";

// Map<tabId, candidates[]>
const tabCandidates = new Map<number, MediaCandidate[]>();

// Pending request callbacks: requestId → { resolve, reject, timer }
interface PendingRequest {
  resolve: (msg: IncomingMessage) => void;
  reject: (reason: string) => void;
  timer: ReturnType<typeof setTimeout>;
}
const pendingRequests = new Map<string, PendingRequest>();

let _reqCounter = 0;
function _newRequestId(): string {
  return `cf-${Date.now()}-${++_reqCounter}`;
}

// ── Native Messaging port management ─────────────────────────────────────────

function connectNativeHost(): void {
  if (nativePort) return;

  setConnectionState("connecting");

  try {
    nativePort = chrome.runtime.connectNative(NATIVE_HOST_NAME);
  } catch (e) {
    setConnectionState("error");
    return;
  }

  nativePort.onMessage.addListener(onNativeMessage);
  nativePort.onDisconnect.addListener(onNativeDisconnect);

  // Send a ping to verify the desktop app is running.
  sendNative({ version: PROTOCOL_VERSION, type: "PING", requestId: _newRequestId() })
    .then(() => setConnectionState("connected"))
    .catch(() => setConnectionState("error"));
}

function onNativeMessage(message: IncomingMessage): void {
  const { requestId, type } = message;

  // Resolve any pending promise for this requestId.
  const pending = pendingRequests.get(requestId);
  if (pending) {
    clearTimeout(pending.timer);
    pendingRequests.delete(requestId);
    pending.resolve(message);
    return;
  }

  // Handle unsolicited messages (e.g. APP_NOT_RUNNING from the host).
  if (type === "APP_NOT_RUNNING" || type === "ERROR") {
    setConnectionState("error");
  }
}

function onNativeDisconnect(): void {
  nativePort = null;
  setConnectionState("disconnected");

  // Reject all pending requests.
  for (const [id, pending] of pendingRequests) {
    clearTimeout(pending.timer);
    pending.reject("Native host disconnected.");
    pendingRequests.delete(id);
  }
}

function setConnectionState(state: ConnectionState): void {
  if (connectionState === state) return;
  connectionState = state;
  broadcastToPopups({ kind: "connection-state", state });
  updateBadge();
}

/** Send a message to the native host and await the correlated response. */
function sendNative(message: object): Promise<IncomingMessage> {
  return new Promise<IncomingMessage>((resolve, reject) => {
    if (!nativePort) {
      reject("No native port.");
      return;
    }

    const requestId = (message as { requestId?: string }).requestId ?? _newRequestId();
    const timer = setTimeout(() => {
      pendingRequests.delete(requestId);
      reject("Request timed out.");
    }, ANALYSIS_TIMEOUT_MS);

    pendingRequests.set(requestId, { resolve, reject, timer });

    try {
      nativePort.postMessage(message);
    } catch (e) {
      clearTimeout(timer);
      pendingRequests.delete(requestId);
      reject(`postMessage failed: ${e}`);
    }
  });
}

// ── Badge ─────────────────────────────────────────────────────────────────────

function updateBadge(tabId?: number): void {
  if (connectionState !== "connected") {
    chrome.action.setBadgeText({ text: "" });
    return;
  }

  if (tabId != null) {
    const count = tabCandidates.get(tabId)?.length ?? 0;
    const text = count > 0 ? String(count) : "";
    chrome.action.setBadgeText({ text, tabId });
    chrome.action.setBadgeBackgroundColor({ color: "#7B68EE", tabId });
  }
}

// ── Content-script → background messages ────────────────────────────────────

chrome.runtime.onMessage.addListener(
  (message: ContentToBackgroundMsg, sender) => {
    if (!sender.tab?.id) return;
    const tabId = sender.tab.id;

    if (message.kind === "candidates") {
      const limited = message.candidates.slice(0, MAX_CANDIDATES);
      tabCandidates.set(tabId, limited);
      updateBadge(tabId);
      broadcastToPopups({ kind: "candidates-updated", candidates: limited });
    }
  }
);

// ── Popup → background messages ───────────────────────────────────────────────

chrome.runtime.onMessage.addListener(
  (message: PopupToBgMsg, _sender, sendResponse) => {
    handlePopupMessage(message, sendResponse);
    return true; // keep channel open for async response
  }
);

async function handlePopupMessage(
  message: PopupToBgMsg,
  sendResponse: (r: unknown) => void
): Promise<void> {
  switch (message.kind) {
    case "get-candidates": {
      const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
      const candidates = tab?.id ? (tabCandidates.get(tab.id) ?? []) : [];
      sendResponse(candidates);
      break;
    }

    case "get-connection-state":
      sendResponse(connectionState);
      break;

    case "refresh-detection": {
      const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
      if (tab?.id) {
        try {
          await chrome.scripting.executeScript({
            target: { tabId: tab.id },
            files: ["content.js"],
          });
        } catch (_) {}
      }
      sendResponse(null);
      break;
    }

    case "clear-candidates": {
      const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
      if (tab?.id) {
        tabCandidates.delete(tab.id);
        updateBadge(tab.id);
        broadcastToPopups({ kind: "candidates-updated", candidates: [] });
      }
      sendResponse(null);
      break;
    }

    case "analyze": {
      ensureConnected();
      const rid = _newRequestId();
      try {
        const response = await sendNative({
          version: PROTOCOL_VERSION,
          type: "ANALYZE_MEDIA",
          requestId: rid,
          url: message.candidate.url,
          pageUrl: message.candidate.pageUrl,
          pageTitle: message.candidate.pageTitle,
        });
        const result = buildAnalysisResult(response);
        sendResponse({ ok: true, result });
        broadcastToPopups({
          kind: "analysis-result",
          requestId: rid,
          result,
        });
      } catch (err) {
        sendResponse({ ok: false, error: String(err) });
      }
      break;
    }

    case "download": {
      ensureConnected();
      const rid = _newRequestId();
      try {
        const response = await sendNative({
          version: PROTOCOL_VERSION,
          type: "DOWNLOAD_REQUEST",
          requestId: rid,
          url: message.candidate.url,
          pageUrl: message.candidate.pageUrl,
          pageTitle: message.candidate.pageTitle,
          title: message.candidate.pageTitle,
          mimeType: message.candidate.mimeType,
          downloadType: (message.downloadType ?? "videoAndAudio") as DownloadType,
          formatSelector: message.formatSelector,
          durationSeconds: message.candidate.durationSeconds,
        });
        if (response.type === "DOWNLOAD_ACCEPTED") {
          sendResponse({ ok: true, taskId: response.taskId });
          broadcastToPopups({
            kind: "download-accepted",
            requestId: rid,
            taskId: String(response.taskId),
          });
        } else {
          const err = String((response as { error?: string }).error ?? "Rejected");
          sendResponse({ ok: false, error: err });
          broadcastToPopups({ kind: "download-rejected", requestId: rid, error: err });
        }
      } catch (err) {
        const msg = String(err);
        sendResponse({ ok: false, error: msg });
        broadcastToPopups({ kind: "download-rejected", requestId: rid, error: msg });
      }
      break;
    }
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

function ensureConnected(): void {
  if (!nativePort || connectionState === "disconnected" || connectionState === "error") {
    connectNativeHost();
  }
}

function buildAnalysisResult(response: IncomingMessage) {
  return {
    url: String((response as { url?: string }).url ?? ""),
    title: (response as { title?: string }).title,
    thumbnailUrl: (response as { thumbnailUrl?: string }).thumbnailUrl,
    durationSeconds: (response as { durationSeconds?: number }).durationSeconds,
    uploaderName: (response as { uploaderName?: string }).uploaderName,
    supported: Boolean((response as { supported?: boolean }).supported),
    isDirectDownload: Boolean((response as { isDirectDownload?: boolean }).isDirectDownload),
    formats: (response as { formats?: unknown[] }).formats ?? [],
    error: (response as { error?: string }).error,
  };
}

function broadcastToPopups(msg: BgToPopupMsg): void {
  chrome.runtime.sendMessage(msg).catch(() => {
    // No popup open; suppress error.
  });
}

// ── Lifecycle hooks ───────────────────────────────────────────────────────────

// Connect on startup.
connectNativeHost();

// Reconnect when the extension action button is clicked (popup will open).
chrome.action.onClicked?.addListener(() => {
  ensureConnected();
});

// Update badge when the active tab changes.
chrome.tabs.onActivated?.addListener(({ tabId }) => {
  updateBadge(tabId);
});

// Clean up closed tabs.
chrome.tabs.onRemoved?.addListener((tabId) => {
  tabCandidates.delete(tabId);
});
