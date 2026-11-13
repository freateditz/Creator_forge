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
  CONNECT_RETRY_DELAY_MS,
  MAX_CONNECT_RETRIES,
} from "./types";
import type {
  BgToPopupMsg,
  ConnectionState,
  ContentToBackgroundMsg,
  DownloadType,
  IncomingMessage,
  MediaCandidate,
  MediaFormat,
  OrdinaryFileDownloadMessage,
  PopupToBgMsg,
} from "./types";

// ── State ────────────────────────────────────────────────────────────────

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

// In-flight ordinary file downloads: downloadId → requestId (for cancellation after acceptance)
const inFlightDownloads = new Map<number, string>();

// Interception config (synced from storage)
let interceptionEnabled = true;
const INTERCEPTED_EXTENSIONS = new Set([
  "zip", "rar", "7z", "tar", "gz", "bz2", "xz",
  "exe", "msi", "dmg", "pkg", "apk", "appimage",
  "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx",
  "mp4", "mkv", "avi", "mov", "webm", "flv", "wmv",
  "mp3", "wav", "flac", "aac", "ogg", "m4a",
  "jpg", "jpeg", "png", "gif", "webp", "bmp", "tiff", "svg",
  "iso", "img", "vhd", "vmdk",
  "torrent", "magnet"
]);
const EXCLUDED_DOMAINS = new Set([
  "accounts.google.com",
  "login.microsoftonline.com",
  "github.com",
  "gitlab.com"
]);
const BROWSER_INTERNAL_SCHEMES = new Set([
  "chrome:", "chrome-extension:", "edge:", "brave:", "vivaldi:",
  "firefox:", "about:", "chrome-devtools:", "view-source:"
]);

let _reqCounter = 0;
function _newRequestId(): string {
  return `cf-${Date.now()}-${++_reqCounter}`;
}

// ── Interception logic ─────────────────────────────────────────────────────────

/** Check if a URL should be intercepted (not browser-internal, not excluded domain, valid extension). */
function shouldInterceptDownload(item: chrome.downloads.DownloadItem): boolean {
  if (!interceptionEnabled) return false;
  if (!item.url || item.url.startsWith("blob:")) return false;

  try {
    const url = new URL(item.url);
    // Skip browser-internal schemes
    if (BROWSER_INTERNAL_SCHEMES.has(url.protocol)) return false;
    // Skip excluded domains
    if (EXCLUDED_DOMAINS.has(url.hostname)) return false;
    // Skip if already handled by CreatorForge (we track by downloadId)
    if (inFlightDownloads.has(item.id!)) return false;
    // Check file extension
    const ext = url.pathname.split(".").pop()?.toLowerCase() ?? "";
    if (!INTERCEPTED_EXTENSIONS.has(ext)) return false;
    // Skip very small files (< 1 KB)
    if (item.totalBytes !== undefined && item.totalBytes > 0 && item.totalBytes < 1024) return false;
    return true;
  } catch {
    return false;
  }
}

/** Extract filename from download item or URL. */
function getFilename(item: chrome.downloads.DownloadItem): string {
  if (item.filename) return item.filename;
  try {
    const url = new URL(item.url);
    const pathname = url.pathname;
    const name = pathname.split("/").pop() || "download";
    return name;
  } catch {
    return "download";
  }
}

/** Send ordinary file download request to native host. */
async function sendOrdinaryFileDownload(item: chrome.downloads.DownloadItem): Promise<boolean> {
  const requestId = _newRequestId();
  const filename = getFilename(item);

  const message: OrdinaryFileDownloadMessage = {
    version: PROTOCOL_VERSION,
    type: "ORDINARY_FILE_DOWNLOAD",
    requestId,
    url: item.url,
    filename,
    mimeType: item.mime,
    fileSize: item.totalBytes,
    referrer: item.referrer,
    pageUrl: item.url, // For ordinary files, the URL is the page URL too
    pageTitle: filename,
  };

  try {
    const response = await sendNative(message);
    if (response.type === "DOWNLOAD_ACCEPTED") {
      // Track this download for cancellation
      inFlightDownloads.set(item.id!, requestId);
      // Cancel the browser's download now that CreatorForge has accepted it
      chrome.downloads.cancel(item.id!);
      // Erase from browser's download history (optional, keeps UI clean)
      chrome.downloads.erase({ id: item.id! });
      return true;
    } else if (response.type === "DOWNLOAD_REJECTED") {
      // Let browser continue the download
      return false;
    }
  } catch (err) {
    console.error("[CreatorForge] Ordinary file download request failed:", err);
  }
  return false;
}

/** Handle chrome.downloads.onCreated - intercept ordinary file downloads. */
chrome.downloads.onCreated.addListener(async (item: chrome.downloads.DownloadItem) => {
  // Skip if already complete or interrupted
  if (item.state === "complete" || item.state === "interrupted") return;

  if (shouldInterceptDownload(item)) {
    await sendOrdinaryFileDownload(item);
  }
});

/** Handle chrome.downloads.onChanged - clean up tracking when download finishes. */
chrome.downloads.onChanged.addListener((delta: chrome.downloads.DownloadDelta) => {
  if (delta.id && inFlightDownloads.has(delta.id)) {
    if (delta.state && (delta.state.current === "complete" || delta.state.current === "interrupted")) {
      inFlightDownloads.delete(delta.id);
    }
  }
});

/** Load interception settings from storage on startup. */
async function loadInterceptionSettings(): Promise<void> {
  try {
    const result = await chrome.storage.sync.get(["interceptionEnabled"]);
    if (result.interceptionEnabled !== undefined) {
      interceptionEnabled = result.interceptionEnabled;
    }
  } catch {
    // Default to enabled
    interceptionEnabled = true;
  }
}

/** Create context menu for "Download with CreatorForge". */
function createContextMenu(): void {
  chrome.contextMenus.create({
    id: "creatorforge-download-link",
    title: "Download with CreatorForge",
    contexts: ["link"],
    targetUrlPatterns: ["http://*/*", "https://*/*"],
    documentUrlPatterns: ["http://*/*", "https://*/*"],
  });

  chrome.contextMenus.create({
    id: "creatorforge-download-image",
    title: "Download image with CreatorForge",
    contexts: ["image"],
    targetUrlPatterns: ["http://*/*", "https://*/*"],
    documentUrlPatterns: ["http://*/*", "https://*/*"],
  });

  chrome.contextMenus.create({
    id: "creatorforge-download-media",
    title: "Download video/audio with CreatorForge",
    contexts: ["video", "audio"],
    targetUrlPatterns: ["http://*/*", "https://*/*"],
    documentUrlPatterns: ["http://*/*", "https://*/*"],
  });
}

chrome.contextMenus.onClicked.addListener(async (info, tab) => {
  if (!tab?.id) return;

  let url = info.linkUrl || info.srcUrl || info.mediaUrl;
  if (!url) return;

  // For context menu, we need to create a synthetic download item
  // We'll send the URL directly as an ordinary file download
  const requestId = _newRequestId();
  const filename = url.split("/").pop()?.split("?")[0] || "download";

  const message: OrdinaryFileDownloadMessage = {
    version: PROTOCOL_VERSION,
    type: "ORDINARY_FILE_DOWNLOAD",
    requestId,
    url,
    filename,
    pageUrl: tab.url || url,
    pageTitle: tab.title || filename,
  };

  try {
    const response = await sendNative(message);
    if (response.type === "DOWNLOAD_ACCEPTED") {
      // Show notification to user
      chrome.notifications.create({
        type: "basic",
        iconUrl: "icons/icon48.png",
        title: "CreatorForge",
        message: `Download started: ${filename}`,
      });
    }
  } catch (err) {
    console.error("[CreatorForge] Context menu download failed:", err);
  }
});

// Initialize context menu on install/update
chrome.runtime.onInstalled.addListener(async () => {
  await loadInterceptionSettings();
  createContextMenu();
});

// Load settings on startup
loadInterceptionSettings();
createContextMenu();

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
      let candidates = tab?.id ? (tabCandidates.get(tab.id) ?? []) : [];
      if (candidates.length === 0 && tab?.id) {
        try {
          const res = (await chrome.tabs.sendMessage(tab.id, { kind: "scan" })) as MediaCandidate[];
          if (Array.isArray(res) && res.length > 0) {
            candidates = res.slice(0, MAX_CANDIDATES);
            tabCandidates.set(tab.id, candidates);
            updateBadge(tab.id);
          }
        } catch (_) {}
      }
      sendResponse(candidates);
      break;
    }

    case "get-connection-state": {
      if (connectionState === "disconnected" || connectionState === "error" || !nativePort) {
        connectNativeHost();
      }
      sendResponse(connectionState);
      break;
    }

    case "reconnect": {
      if (nativePort) {
        try {
          nativePort.disconnect();
        } catch (_) {}
        nativePort = null;
      }
      connectionState = "disconnected";
      connectNativeHost();
      sendResponse(connectionState);
      break;
    }

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
      const targetUrl =
        message.candidate.url && !message.candidate.url.startsWith("blob:")
          ? message.candidate.url
          : message.candidate.pageUrl || message.candidate.url;

      try {
        const response = await sendNative({
          version: PROTOCOL_VERSION,
          type: "ANALYZE_MEDIA",
          requestId: rid,
          url: targetUrl,
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
      const targetUrl =
        message.candidate.url && !message.candidate.url.startsWith("blob:")
          ? message.candidate.url
          : message.candidate.pageUrl || message.candidate.url;

      try {
        const response = await sendNative({
          version: PROTOCOL_VERSION,
          type: "DOWNLOAD_REQUEST",
          requestId: rid,
          url: targetUrl,
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
    formats: (response as { formats?: MediaFormat[] }).formats ?? [],
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
