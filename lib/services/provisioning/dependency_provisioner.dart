import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/logging/app_logger.dart';

/// Downloads and installs yt-dlp and FFmpeg into the app-managed bin directory.
///
/// Security constraints:
/// - Downloads are saved exclusively to the app's own binDir.
/// - No user-global PATH or registry is modified.
/// - Only the official GitHub release URLs are used (no arbitrary server).
/// - No DRM circumvention tools are included.
class DependencyProvisioner {
  final String binDir;
  final _log = AppLogger.get('DependencyProvisioner');

  // yt-dlp standalone Windows release
  static const _ytDlpWindowsUrl =
      'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe';
  // yt-dlp standalone macOS binary (universal)
  static const _ytDlpMacosUrl =
      'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos';

  // FFmpeg for Windows — BtbN GPL-small build (ffmpeg + ffprobe, ~30 MB zip)
  static const _ffmpegWindowsZipUrl =
      'https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl-shared.zip';

  DependencyProvisioner({required this.binDir});

  // ── yt-dlp ─────────────────────────────────────────────────────────────────

  String get ytDlpPath => Platform.isWindows
      ? p.join(binDir, 'yt-dlp.exe')
      : p.join(binDir, 'yt-dlp');

  bool get isYtDlpProvisioned => File(ytDlpPath).existsSync();

  /// Downloads the yt-dlp standalone binary to [binDir].
  ///
  /// [onProgress] receives 0.0–1.0 as download progresses.
  /// Returns the path to the downloaded binary.
  Future<String> provisionYtDlp({
    void Function(double progress)? onProgress,
  }) async {
    if (!Platform.isWindows && !Platform.isMacOS) {
      throw UnsupportedError(
        'Automatic yt-dlp provisioning is only supported on Windows and macOS.',
      );
    }
    final url = Platform.isWindows ? _ytDlpWindowsUrl : _ytDlpMacosUrl;
    _log.info('Downloading yt-dlp from: $url');
    await _downloadFile(url: url, destPath: ytDlpPath, onProgress: onProgress);
    if (!Platform.isWindows) {
      // Make executable on Unix
      await Process.run('chmod', ['+x', ytDlpPath]);
    }
    _log.info('yt-dlp provisioned at: $ytDlpPath');
    return ytDlpPath;
  }

  // ── FFmpeg ─────────────────────────────────────────────────────────────────

  String get ffmpegPath => Platform.isWindows
      ? p.join(binDir, 'ffmpeg.exe')
      : p.join(binDir, 'ffmpeg');

  String get ffprobePath => Platform.isWindows
      ? p.join(binDir, 'ffprobe.exe')
      : p.join(binDir, 'ffprobe');

  bool get isFfmpegProvisioned => File(ffmpegPath).existsSync();

  /// Downloads FFmpeg to [binDir].
  ///
  /// On Windows: downloads a pre-built zip and extracts ffmpeg.exe/ffprobe.exe
  /// using PowerShell Expand-Archive (available on Windows 10+).
  ///
  /// On macOS: FFmpeg auto-download is not supported — users must install via
  /// Homebrew (`brew install ffmpeg`). Throws [UnsupportedError] on macOS.
  ///
  /// [onProgress] receives 0.0–1.0 as download progresses (extraction not
  /// separately reported).
  Future<String> provisionFfmpeg({
    void Function(double progress)? onProgress,
  }) async {
    if (!Platform.isWindows) {
      throw UnsupportedError(
        'Automatic FFmpeg provisioning is only supported on Windows. '
        'On macOS, install FFmpeg with: brew install ffmpeg',
      );
    }
    final zipPath = p.join(binDir, '_ffmpeg_download.zip');
    _log.info('Downloading FFmpeg from: $_ffmpegWindowsZipUrl');
    await _downloadFile(
      url: _ffmpegWindowsZipUrl,
      destPath: zipPath,
      onProgress: onProgress,
    );

    _log.info('Extracting FFmpeg…');
    await _extractFfmpegFromZip(zipPath: zipPath, destDir: binDir);

    // Clean up zip after extraction
    try {
      await File(zipPath).delete();
    } catch (_) {}

    if (!File(ffmpegPath).existsSync()) {
      throw StateError(
        'FFmpeg extraction completed but ffmpeg.exe was not found at $ffmpegPath',
      );
    }

    _log.info('FFmpeg provisioned at: $ffmpegPath');
    return ffmpegPath;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<void> _downloadFile({
    required String url,
    required String destPath,
    void Function(double)? onProgress,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 30);
    try {
      final uri = Uri.parse(url);
      final request = await client.getUrl(uri);
      request.followRedirects = true;
      request.maxRedirects = 10;
      final response = await request.close();

      if (response.statusCode != 200) {
        throw HttpException(
          'Download failed with HTTP ${response.statusCode}',
          uri: uri,
        );
      }

      final contentLength = response.contentLength;
      final destFile = File(destPath);
      await destFile.parent.create(recursive: true);
      final sink = destFile.openWrite();

      int received = 0;
      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        if (contentLength > 0 && onProgress != null) {
          onProgress(received / contentLength);
        }
      }
      await sink.flush();
      await sink.close();
      if (onProgress != null) onProgress(1.0);
    } finally {
      client.close();
    }
  }

  Future<void> _extractFfmpegFromZip({
    required String zipPath,
    required String destDir,
  }) async {
    // Use PowerShell's Expand-Archive (Windows 10+)
    final extractDir = p.join(destDir, '_ffmpeg_extracted');

    final result = await Process.run('powershell', [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      'Expand-Archive -LiteralPath "${zipPath.replaceAll("'", "''")}" '
          '-DestinationPath "${extractDir.replaceAll("'", "''")}" -Force',
    ]);

    if (result.exitCode != 0) {
      throw ProcessException(
        'powershell',
        [],
        'Expand-Archive failed: ${result.stderr}',
        result.exitCode,
      );
    }

    // BtbN zips contain a single top-level dir; find ffmpeg.exe inside bin/
    final candidates = [
      p.join(extractDir, 'bin', 'ffmpeg.exe'),
      p.join(extractDir, 'ffmpeg.exe'),
    ];

    // Also search one level deep
    final extractDirEntity = Directory(extractDir);
    if (extractDirEntity.existsSync()) {
      for (final entry in extractDirEntity.listSync()) {
        if (entry is Directory) {
          candidates.add(p.join(entry.path, 'bin', 'ffmpeg.exe'));
          candidates.add(p.join(entry.path, 'ffmpeg.exe'));
        }
      }
    }

    String? foundFfmpeg;
    String? foundFfprobe;
    for (final c in candidates) {
      if (File(c).existsSync()) {
        foundFfmpeg ??= c;
        final probePath = c.replaceAll('ffmpeg.exe', 'ffprobe.exe');
        if (File(probePath).existsSync()) {
          foundFfprobe ??= probePath;
        }
        break;
      }
    }

    if (foundFfmpeg == null) {
      throw StateError('Could not find ffmpeg.exe inside downloaded zip.');
    }

    await File(foundFfmpeg).copy(p.join(destDir, 'ffmpeg.exe'));
    if (foundFfprobe != null) {
      await File(foundFfprobe).copy(p.join(destDir, 'ffprobe.exe'));
    }

    // Clean up extracted dir
    try {
      await Directory(extractDir).delete(recursive: true);
    } catch (_) {}
  }
}
