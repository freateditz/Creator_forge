import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/logging/app_logger.dart';

/// Progress snapshot for a single byte-range segment.
class SegmentProgress {
  final int index;
  final int received;
  final int total;

  const SegmentProgress({
    required this.index,
    required this.received,
    required this.total,
  });

  double get fraction => total > 0 ? received / total : 0;
}

/// Overall download progress snapshot.
class SegmentedDownloadProgress {
  final List<SegmentProgress> segments;
  final int totalBytes;
  final int receivedBytes;
  final bool isRangeSupported;

  const SegmentedDownloadProgress({
    required this.segments,
    required this.totalBytes,
    required this.receivedBytes,
    required this.isRangeSupported,
  });

  double get fraction => totalBytes > 0 ? receivedBytes / totalBytes : 0;
  int get activeSegments => segments.where((s) => s.received < s.total).length;
}

/// Downloads a file over HTTP(S) using parallel byte-range segments (IDM-style).
///
/// - Does a HEAD request to probe Content-Length and Accept-Ranges support.
/// - If the server supports ranges: splits into [segmentCount] parallel
///   connections and merges the segments in order.
/// - If the server does NOT support ranges: falls back to a single connection.
/// - [segmentCount] is clamped to [1, 16].
///
/// Security: only downloads to a caller-controlled path; does not execute
/// or interpret the downloaded bytes.
class SegmentedHttpDownloader {
  static const _log = _Logger();
  static const _maxRedirects = 10;
  static const _connectTimeoutMs = 30000;
  static const _defaultSegmentCount = 8;

  /// Download [url] to [destPath], splitting into up to [segmentCount] parallel
  /// byte-range segments when the server supports it.
  ///
  /// [onProgress] is called from the download isolates approximately every
  /// 64 KB of received data.
  ///
  /// Returns the final [destPath] on success.
  static Future<String> download({
    required String url,
    required String destPath,
    int segmentCount = _defaultSegmentCount,
    void Function(SegmentedDownloadProgress)? onProgress,
    CancellationToken? cancellationToken,
  }) async {
    final clampedSegments = segmentCount.clamp(1, 16);
    final uri = Uri.parse(url);

    // Probe server capabilities
    final probeResult = await _probeUrl(uri);
    final contentLength = probeResult.contentLength;
    final useSegmented =
        probeResult.acceptsRanges &&
        contentLength != null &&
        contentLength > 0 &&
        clampedSegments > 1;

    _log.info(
      'Download: $url → $destPath | '
      'size=${contentLength ?? "unknown"} '
      'ranges=${probeResult.acceptsRanges} segments=$clampedSegments',
    );

    if (!useSegmented) {
      // Fallback: single connection download
      await _downloadSingle(
        uri: uri,
        destPath: destPath,
        totalBytes: contentLength ?? 0,
        onProgress: onProgress,
        cancellationToken: cancellationToken,
      );
      return destPath;
    }

    // useSegmented == true implies contentLength != null
    await _downloadSegmented(
      uri: uri,
      destPath: destPath,
      totalBytes: contentLength,
      segmentCount: clampedSegments,
      onProgress: onProgress,
      cancellationToken: cancellationToken,
    );
    return destPath;
  }

  // ── Probe ──────────────────────────────────────────────────────────────────

  static Future<_ProbeResult> _probeUrl(Uri uri) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: _connectTimeoutMs);
    try {
      final request = await client.headUrl(uri);
      request.followRedirects = true;
      request.maxRedirects = _maxRedirects;
      final response = await request.close();
      await response.drain<void>();

      final contentLength = response.contentLength > 0
          ? response.contentLength
          : null;
      final acceptsRanges =
          response.headers.value('accept-ranges')?.toLowerCase() == 'bytes';

      return _ProbeResult(
        contentLength: contentLength,
        acceptsRanges: acceptsRanges,
      );
    } catch (_) {
      return const _ProbeResult(contentLength: null, acceptsRanges: false);
    } finally {
      client.close();
    }
  }

  // ── Single-connection download ─────────────────────────────────────────────

  static Future<void> _downloadSingle({
    required Uri uri,
    required String destPath,
    required int totalBytes,
    void Function(SegmentedDownloadProgress)? onProgress,
    CancellationToken? cancellationToken,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: _connectTimeoutMs);
    try {
      final request = await client.getUrl(uri);
      request.followRedirects = true;
      request.maxRedirects = _maxRedirects;
      final response = await request.close();

      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode} for $uri', uri: uri);
      }

      await File(destPath).parent.create(recursive: true);
      final sink = File(destPath).openWrite();
      int received = 0;
      const notifyEvery = 65536; // 64 KB
      int lastNotify = 0;

      await for (final chunk in response) {
        cancellationToken?.throwIfCancelled();
        sink.add(chunk);
        received += chunk.length;
        if (onProgress != null && received - lastNotify >= notifyEvery) {
          lastNotify = received;
          onProgress(
            SegmentedDownloadProgress(
              segments: [
                SegmentProgress(
                  index: 0,
                  received: received,
                  total: totalBytes,
                ),
              ],
              totalBytes: totalBytes,
              receivedBytes: received,
              isRangeSupported: false,
            ),
          );
        }
      }
      await sink.flush();
      await sink.close();

      onProgress?.call(
        SegmentedDownloadProgress(
          segments: [
            SegmentProgress(
              index: 0,
              received: received,
              total: math.max(totalBytes, received),
            ),
          ],
          totalBytes: math.max(totalBytes, received),
          receivedBytes: received,
          isRangeSupported: false,
        ),
      );
    } finally {
      client.close();
    }
  }

  // ── Segmented download ─────────────────────────────────────────────────────

  static Future<void> _downloadSegmented({
    required Uri uri,
    required String destPath,
    required int totalBytes,
    required int segmentCount,
    void Function(SegmentedDownloadProgress)? onProgress,
    CancellationToken? cancellationToken,
  }) async {
    final tempDir = Directory(
      p.join(p.dirname(destPath), '.cf_dl_${const Uuid().v4()}'),
    );
    await tempDir.create(recursive: true);

    try {
      final segmentSize = (totalBytes / segmentCount).ceil();
      final ranges = <_ByteRange>[];
      for (var i = 0; i < segmentCount; i++) {
        final start = i * segmentSize;
        final end = math.min(start + segmentSize - 1, totalBytes - 1);
        ranges.add(_ByteRange(start: start, end: end));
      }

      // Shared progress state (accessed from concurrent async tasks)
      final receivedPerSegment = List<int>.filled(segmentCount, 0);
      final totalPerSegment = ranges.map((r) => r.end - r.start + 1).toList();

      void notify() {
        if (onProgress == null) return;
        final totalReceived = receivedPerSegment.fold(0, (a, b) => a + b);
        onProgress(
          SegmentedDownloadProgress(
            segments: [
              for (var i = 0; i < segmentCount; i++)
                SegmentProgress(
                  index: i,
                  received: receivedPerSegment[i],
                  total: totalPerSegment[i],
                ),
            ],
            totalBytes: totalBytes,
            receivedBytes: totalReceived,
            isRangeSupported: true,
          ),
        );
      }

      await Future.wait([
        for (var i = 0; i < segmentCount; i++)
          _downloadSegment(
            uri: uri,
            range: ranges[i],
            destPath: p.join(tempDir.path, 'seg_$i'),
            onReceived: (bytes) {
              receivedPerSegment[i] += bytes;
              notify();
            },
            cancellationToken: cancellationToken,
          ),
      ]);

      // Merge segments in order
      await File(destPath).parent.create(recursive: true);
      final output = File(destPath).openWrite();
      for (var i = 0; i < segmentCount; i++) {
        final segFile = File(p.join(tempDir.path, 'seg_$i'));
        await output.addStream(segFile.openRead());
      }
      await output.flush();
      await output.close();
    } finally {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  }

  static Future<void> _downloadSegment({
    required Uri uri,
    required _ByteRange range,
    required String destPath,
    required void Function(int bytes) onReceived,
    CancellationToken? cancellationToken,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: _connectTimeoutMs);
    try {
      final request = await client.getUrl(uri);
      request.followRedirects = true;
      request.maxRedirects = _maxRedirects;
      request.headers.set('Range', 'bytes=${range.start}-${range.end}');
      final response = await request.close();

      // 206 Partial Content is expected; 200 means server ignored Range
      if (response.statusCode != 206 && response.statusCode != 200) {
        throw HttpException(
          'HTTP ${response.statusCode} for segment ${range.start}-${range.end}',
          uri: uri,
        );
      }

      final sink = File(destPath).openWrite();
      const notifyEvery = 65536;
      int sinceLastNotify = 0;

      await for (final chunk in response) {
        cancellationToken?.throwIfCancelled();
        sink.add(chunk);
        sinceLastNotify += chunk.length;
        if (sinceLastNotify >= notifyEvery) {
          onReceived(sinceLastNotify);
          sinceLastNotify = 0;
        }
      }
      if (sinceLastNotify > 0) onReceived(sinceLastNotify);
      await sink.flush();
      await sink.close();
    } finally {
      client.close();
    }
  }
}

// ── Supporting types ──────────────────────────────────────────────────────────

class _ProbeResult {
  final int? contentLength;
  final bool acceptsRanges;
  const _ProbeResult({
    required this.contentLength,
    required this.acceptsRanges,
  });
}

class _ByteRange {
  final int start;
  final int end;
  const _ByteRange({required this.start, required this.end});
}

/// Token passed to downloads to request cooperative cancellation.
class CancellationToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
  void throwIfCancelled() {
    if (_cancelled) throw const _CancelledException();
  }
}

class _CancelledException implements Exception {
  const _CancelledException();
  @override
  String toString() => 'Download cancelled';
}

// Lightweight logger wrapper so the static class can log.
class _Logger {
  const _Logger();
  static final _inner = AppLogger.get('SegmentedDownloader');
  void info(String msg) => _inner.info(msg);
}
