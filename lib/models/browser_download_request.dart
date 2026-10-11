import 'dart:convert';

import 'download_task.dart';

const int kIpcProtocolVersion = 1;
const int kMaxMessageBytes = 1024 * 1024; // 1 MB guard

// ── Incoming message types (extension → native host → Flutter) ───────────────

enum IncomingMsgType {
  ping,
  connectionStatus,
  analyzeMedia,
  downloadRequest,
  unknown;

  static IncomingMsgType fromString(String? s) => switch (s) {
    'PING' => IncomingMsgType.ping,
    'CONNECTION_STATUS' => IncomingMsgType.connectionStatus,
    'ANALYZE_MEDIA' => IncomingMsgType.analyzeMedia,
    'DOWNLOAD_REQUEST' => IncomingMsgType.downloadRequest,
    _ => IncomingMsgType.unknown,
  };
}

// ── Outgoing message types (Flutter → native host → extension) ───────────────

enum OutgoingMsgType {
  pong('PONG'),
  connectionAck('CONNECTION_ACK'),
  analyzeResult('ANALYZE_RESULT'),
  downloadAccepted('DOWNLOAD_ACCEPTED'),
  downloadRejected('DOWNLOAD_REJECTED'),
  error('ERROR');

  final String wire;
  const OutgoingMsgType(this.wire);
}

// ── Incoming messages (sealed hierarchy) ─────────────────────────────────────

sealed class BrowserMessage {
  final int version;
  final String requestId;
  const BrowserMessage({required this.version, required this.requestId});

  static BrowserMessage? fromJson(Map<String, dynamic> json) {
    final type = IncomingMsgType.fromString(json['type'] as String?);
    final version = (json['version'] as num?)?.toInt() ?? kIpcProtocolVersion;
    final requestId = (json['requestId'] as String?) ?? '';
    return switch (type) {
      IncomingMsgType.ping => BrowserPingMsg(
        version: version,
        requestId: requestId,
      ),
      IncomingMsgType.connectionStatus => BrowserConnectionStatusMsg(
        version: version,
        requestId: requestId,
      ),
      IncomingMsgType.analyzeMedia => BrowserAnalyzeMsg(
        version: version,
        requestId: requestId,
        url: (json['url'] as String?) ?? '',
        pageUrl: (json['pageUrl'] as String?) ?? '',
        pageTitle: (json['pageTitle'] as String?) ?? '',
      ),
      IncomingMsgType.downloadRequest => BrowserDownloadMsg(
        version: version,
        requestId: requestId,
        url: (json['url'] as String?) ?? '',
        pageUrl: (json['pageUrl'] as String?) ?? '',
        pageTitle: (json['pageTitle'] as String?) ?? '',
        title: json['title'] as String?,
        mimeType: json['mimeType'] as String?,
        downloadType: _parseDownloadType(json['downloadType'] as String?),
        formatSelector: json['formatSelector'] as String?,
        durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
      ),
      IncomingMsgType.unknown => null,
    };
  }

  static DownloadType _parseDownloadType(String? s) => switch (s) {
    'videoOnly' => DownloadType.videoOnly,
    'audioOnly' => DownloadType.audioOnly,
    _ => DownloadType.videoAndAudio,
  };
}

class BrowserPingMsg extends BrowserMessage {
  const BrowserPingMsg({required super.version, required super.requestId});
}

class BrowserConnectionStatusMsg extends BrowserMessage {
  const BrowserConnectionStatusMsg({
    required super.version,
    required super.requestId,
  });
}

class BrowserAnalyzeMsg extends BrowserMessage {
  final String url;
  final String pageUrl;
  final String pageTitle;
  const BrowserAnalyzeMsg({
    required super.version,
    required super.requestId,
    required this.url,
    required this.pageUrl,
    required this.pageTitle,
  });
}

class BrowserDownloadMsg extends BrowserMessage {
  final String url;
  final String pageUrl;
  final String pageTitle;
  final String? title;
  final String? mimeType;
  final DownloadType downloadType;
  final String? formatSelector;
  final int? durationSeconds;
  const BrowserDownloadMsg({
    required super.version,
    required super.requestId,
    required this.url,
    required this.pageUrl,
    required this.pageTitle,
    this.title,
    this.mimeType,
    this.downloadType = DownloadType.videoAndAudio,
    this.formatSelector,
    this.durationSeconds,
  });
}

// ── Outgoing responses ────────────────────────────────────────────────────────

class BrowserResponse {
  final OutgoingMsgType type;
  final String requestId;
  final Map<String, Object?> extra;

  const BrowserResponse({
    required this.type,
    required this.requestId,
    this.extra = const {},
  });

  Map<String, Object?> toJson() => {
    'version': kIpcProtocolVersion,
    'type': type.wire,
    'requestId': requestId,
    ...extra,
  };

  String toJsonLine() => '${jsonEncode(toJson())}\n';

  static BrowserResponse pong(String requestId) =>
      BrowserResponse(type: OutgoingMsgType.pong, requestId: requestId);

  static BrowserResponse connectionAck(String requestId) => BrowserResponse(
    type: OutgoingMsgType.connectionAck,
    requestId: requestId,
    extra: {'appVersion': '1.0.0'},
  );

  static BrowserResponse downloadAccepted({
    required String requestId,
    required String taskId,
  }) => BrowserResponse(
    type: OutgoingMsgType.downloadAccepted,
    requestId: requestId,
    extra: {'taskId': taskId},
  );

  static BrowserResponse downloadRejected({
    required String requestId,
    required String error,
  }) => BrowserResponse(
    type: OutgoingMsgType.downloadRejected,
    requestId: requestId,
    extra: {'error': error},
  );

  static BrowserResponse error({
    required String requestId,
    required String error,
  }) => BrowserResponse(
    type: OutgoingMsgType.error,
    requestId: requestId,
    extra: {'error': error},
  );
}
