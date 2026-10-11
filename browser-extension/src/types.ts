/**
 * Shared type definitions for CreatorForge browser extension.
 * Protocol version must match the Dart/Python native-host side.
 */

export const PROTOCOL_VERSION = 1;
export const NATIVE_HOST_NAME = "com.creatorforge.native_host";
export const MAX_CANDIDATES = 50;
export const ANALYSIS_TIMEOUT_MS = 15_000;
export const CONNECT_RETRY_DELAY_MS = 2_000;
export const MAX_CONNECT_RETRIES = 3;

// ── Media candidate ───────────────────────────────────────────────────────────

export type MediaElementType = "video" | "audio" | "unknown";

export type DetectionSource =
  | "html-video"
  | "html-audio"
  | "source-element"
  | "mutation-observer"
  | "manual";

export type DownloadabilityStatus =
  | "unknown"
  | "direct"
  | "stream"
  | "blob"
  | "drm-protected"
  | "unsupported";

export interface MediaCandidate {
  id: string;            // Stable deduplication key (derived from URL)
  url: string;
  pageUrl: string;
  pageTitle: string;
  elementType: MediaElementType;
  mimeType?: string;
  durationSeconds?: number;
  width?: number;
  height?: number;
  detectionSource: DetectionSource;
  downloadability: DownloadabilityStatus;
  detectedAt: number;   // Date.now()
}

// ── Analysis result (returned by ANALYZE_RESULT response) ────────────────────

export interface MediaFormat {
  id: string;
  label: string;
  ext: string;
}

export interface AnalysisResult {
  url: string;
  title?: string;
  thumbnailUrl?: string;
  durationSeconds?: number;
  uploaderName?: string;
  supported: boolean;
  isDirectDownload?: boolean;
  formats?: MediaFormat[];
  error?: string;
}

// ── IPC connection state ───────────────────────────────────────────────────────

export type ConnectionState =
  | "disconnected"
  | "connecting"
  | "connected"
  | "error";

// ── Outgoing messages (extension → native host → Flutter) ────────────────────

export interface BaseMessage {
  version: number;
  type: string;
  requestId: string;
}

export interface PingMessage extends BaseMessage {
  type: "PING";
}

export interface ConnectionStatusMessage extends BaseMessage {
  type: "CONNECTION_STATUS";
}

export interface AnalyzeMediaMessage extends BaseMessage {
  type: "ANALYZE_MEDIA";
  url: string;
  pageUrl: string;
  pageTitle: string;
}

export type DownloadType = "videoAndAudio" | "videoOnly" | "audioOnly";

export interface DownloadRequestMessage extends BaseMessage {
  type: "DOWNLOAD_REQUEST";
  url: string;
  pageUrl: string;
  pageTitle: string;
  title?: string;
  mimeType?: string;
  downloadType?: DownloadType;
  formatSelector?: string;
  durationSeconds?: number;
}

export type OutgoingMessage =
  | PingMessage
  | ConnectionStatusMessage
  | AnalyzeMediaMessage
  | DownloadRequestMessage;

// ── Incoming messages (Flutter → native host → extension) ────────────────────

export type IncomingMessageType =
  | "PONG"
  | "CONNECTION_ACK"
  | "ANALYZE_RESULT"
  | "DOWNLOAD_ACCEPTED"
  | "DOWNLOAD_REJECTED"
  | "APP_NOT_RUNNING"
  | "ERROR";

export interface IncomingMessage {
  version: number;
  type: IncomingMessageType;
  requestId: string;
  [key: string]: unknown;
}

export interface PongMessage extends IncomingMessage {
  type: "PONG";
}

export interface ConnectionAckMessage extends IncomingMessage {
  type: "CONNECTION_ACK";
  appVersion?: string;
}

export interface AnalyzeResultMessage extends IncomingMessage {
  type: "ANALYZE_RESULT";
  url: string;
  title?: string;
  thumbnailUrl?: string;
  durationSeconds?: number;
  uploaderName?: string;
  supported: boolean;
  isDirectDownload?: boolean;
  formats?: MediaFormat[];
  error?: string;
}

export interface DownloadAcceptedMessage extends IncomingMessage {
  type: "DOWNLOAD_ACCEPTED";
  taskId: string;
}

export interface DownloadRejectedMessage extends IncomingMessage {
  type: "DOWNLOAD_REJECTED";
  error: string;
}

export interface ErrorMessage extends IncomingMessage {
  type: "ERROR";
  error: string;
}

// ── Background ↔ popup message bus ───────────────────────────────────────────

export type BgToPopupMsg =
  | { kind: "candidates-updated"; candidates: MediaCandidate[] }
  | { kind: "connection-state"; state: ConnectionState }
  | { kind: "analysis-result"; requestId: string; result: AnalysisResult }
  | { kind: "download-accepted"; requestId: string; taskId: string }
  | { kind: "download-rejected"; requestId: string; error: string };

export type PopupToBgMsg =
  | { kind: "get-candidates" }
  | { kind: "get-connection-state" }
  | { kind: "analyze"; candidate: MediaCandidate }
  | { kind: "download"; candidate: MediaCandidate; formatSelector?: string; downloadType?: DownloadType }
  | { kind: "refresh-detection" }
  | { kind: "clear-candidates" };

export type ContentToBackgroundMsg =
  | { kind: "candidates"; candidates: MediaCandidate[] }
  | { kind: "candidate-update"; candidate: MediaCandidate };

export type BackgroundToContentMsg =
  | { kind: "scan" };
