// ignore_for_file: prefer_initializing_formals
import 'dart:async';

import '../../core/logging/app_logger.dart';
import '../../core/utils/validators.dart';
import '../../models/browser_download_request.dart';
import '../../models/media_info.dart';
import '../download/download_engine.dart';
import '../download/metadata_resolver.dart';

class BrowserRequestHandler {
  final DownloadEngine _downloadEngine;
  final MetadataResolver _metadataResolver;
  final void Function(String taskId)? _onTaskEnqueued;

  final _log = AppLogger.get('BrowserRequestHandler');

  BrowserRequestHandler({
    required DownloadEngine downloadEngine,
    required MetadataResolver metadataResolver,
    void Function(String taskId)? onTaskEnqueued,
  }) : _downloadEngine = downloadEngine,
       _metadataResolver = metadataResolver,
       _onTaskEnqueued = onTaskEnqueued;

  Future<BrowserResponse> handle(BrowserMessage message) async {
    return switch (message) {
      BrowserPingMsg() => _handlePing(message),
      BrowserConnectionStatusMsg() => _handleConnectionStatus(message),
      BrowserAnalyzeMsg() => await _handleAnalyze(message),
      BrowserDownloadMsg() => await _handleDownload(message),
    };
  }

  BrowserResponse _handlePing(BrowserPingMsg msg) =>
      BrowserResponse.pong(msg.requestId);

  BrowserResponse _handleConnectionStatus(BrowserConnectionStatusMsg msg) =>
      BrowserResponse.connectionAck(msg.requestId);

  Future<BrowserResponse> _handleAnalyze(BrowserAnalyzeMsg msg) async {
    final rid = msg.requestId;
    if (msg.url.isEmpty) {
      return BrowserResponse.downloadRejected(
        requestId: rid,
        error: 'URL is required.',
      );
    }

    try {
      Validators.validateUrl(msg.url);
    } catch (e) {
      return BrowserResponse.downloadRejected(
        requestId: rid,
        error: e.toString(),
      );
    }

    try {
      final info = await _metadataResolver.resolve(msg.url);
      return BrowserResponse(
        type: OutgoingMsgType.analyzeResult,
        requestId: rid,
        extra: {
          'url': info.url,
          'title': info.title,
          'thumbnailUrl': info.thumbnailUrl,
          'durationSeconds': info.durationSeconds,
          'uploaderName': info.uploaderName,
          'supported': true,
          'formats': _formatList(info),
        },
      );
    } catch (e) {
      // Not a yt-dlp-resolvable URL — return basic direct-download info.
      _log.info(
        'Metadata resolver failed for ${msg.url}: $e; treating as direct.',
      );
      final filename =
          Uri.tryParse(msg.url)?.pathSegments.lastOrNull ?? 'media';
      return BrowserResponse(
        type: OutgoingMsgType.analyzeResult,
        requestId: rid,
        extra: {
          'url': msg.url,
          'title': filename,
          'supported': true,
          'isDirectDownload': true,
          'formats': [
            {
              'id': 'direct',
              'label': 'Direct download',
              'ext': _guessExt(msg.url),
            },
          ],
        },
      );
    }
  }

  Future<BrowserResponse> _handleDownload(BrowserDownloadMsg msg) async {
    final rid = msg.requestId;
    if (msg.url.isEmpty) {
      return BrowserResponse.downloadRejected(
        requestId: rid,
        error: 'URL is required.',
      );
    }

    // Validate URL — reject unsafe schemes, loopback, and local paths.
    Uri validated;
    try {
      validated = Validators.validateUrl(msg.url);
    } catch (e) {
      return BrowserResponse.downloadRejected(
        requestId: rid,
        error: e.toString(),
      );
    }

    // Reject loopback/private IP destinations from browser messages.
    if (_isLocalHost(validated.host)) {
      return BrowserResponse.downloadRejected(
        requestId: rid,
        error: 'Downloads from local network addresses are not permitted.',
      );
    }

    // Sanitize the title to avoid passing untrusted strings into filenames.
    // The download engine already sanitizes, but we strip here too.
    final safeTitle = msg.title != null
        ? Validators.sanitizeFilename(msg.title!)
        : null;

    // Build MediaInfo stub from the browser-supplied metadata so the download
    // engine can show a title without needing a separate resolve call.
    final cachedMeta = safeTitle != null
        ? MediaInfo(
            url: validated.toString(),
            title: safeTitle,
            durationSeconds: msg.durationSeconds,
            formats: const [],
            resolvedAt: DateTime.now(),
          )
        : null;

    try {
      final task = await _downloadEngine.enqueue(
        url: validated.toString(),
        formatSelector: msg.formatSelector,
        downloadType: msg.downloadType,
        cachedMetadata: cachedMeta,
      );
      _onTaskEnqueued?.call(task.id);
      _log.info('Browser download enqueued: ${task.id} for ${msg.url}');
      return BrowserResponse.downloadAccepted(requestId: rid, taskId: task.id);
    } catch (e) {
      _log.warning('Failed to enqueue browser download: $e');
      return BrowserResponse.downloadRejected(
        requestId: rid,
        error: 'Could not start download: $e',
      );
    }
  }

  static bool _isLocalHost(String host) {
    if (host == 'localhost' || host == '127.0.0.1' || host == '::1') {
      return true;
    }
    if (host.startsWith('192.168.') ||
        host.startsWith('10.') ||
        host.startsWith('172.')) {
      return true;
    }
    return false;
  }

  static List<Map<String, Object?>> _formatList(MediaInfo info) {
    final options = info.availableQualityOptions;
    return options
        .where((o) => o.available)
        .map((o) => {'id': o.formatSelector, 'label': o.label, 'ext': 'mp4'})
        .toList();
  }

  static String _guessExt(String url) {
    final path = Uri.tryParse(url)?.path ?? '';
    final idx = path.lastIndexOf('.');
    if (idx >= 0 && idx < path.length - 1) {
      final ext = path.substring(idx + 1).toLowerCase();
      if (ext.length <= 4) return ext;
    }
    return 'mp4';
  }
}
