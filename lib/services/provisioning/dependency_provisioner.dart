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

  // FFmpeg for Windows — BtbN GPL static build (ffmpeg + ffprobe)
  static const _ffmpegWindowsX64Url =
      'https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip';
  static const _ffmpegWindowsArm64Url =
      'https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-winarm64-gpl.zip';

  // FFmpeg for macOS (Apple Silicon) — from GitHub releases (evermeet.cx is gone)
  // Using an XZ-compressed static build from the yt-dlp/FFmpeg-Builds mirror.
  static const _ffmpegMacosAarch64Url =
      'https://github.com/yt-dlp/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-macos64-gpl.tar.xz';
  // FFmpeg for macOS (Intel x86_64)
  static const _ffmpegMacosX64Url =
      'https://github.com/yt-dlp/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-macos64-gpl.tar.xz';

  // Python for Windows — official embeddable package (minimal, no installer needed)
  static const _pythonWindowsUrl =
      'https://www.python.org/ftp/python/3.12.8/python-3.12.8-embed-amd64.zip';

  DependencyProvisioner({required this.binDir});

  // ── yt-dlp ─────────────────────────────────────────────────────────────────

  String get ytDlpPath => Platform.isWindows
      ? p.join(binDir, 'yt-dlp.exe')
      : p.join(binDir, 'yt-dlp');

  bool get isYtDlpProvisioned {
    final f = File(ytDlpPath);
    return f.existsSync() && f.statSync().size > 0;
  }

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

  bool get isFfmpegProvisioned {
    final f = File(ffmpegPath);
    final pr = File(ffprobePath);
    return f.existsSync() &&
        f.statSync().size > 0 &&
        pr.existsSync() &&
        pr.statSync().size > 0;
  }

  /// Downloads FFmpeg to [binDir].
  ///
  /// On Windows: downloads a pre-built zip and extracts ffmpeg.exe/ffprobe.exe
  /// using PowerShell Expand-Archive (available on Windows 10+).
  ///
  /// On macOS: downloads a static tar.xz build from yt-dlp/FFmpeg-Builds,
  /// extracts ffmpeg and ffprobe, verifies both run, then removes the archive.
  ///
  /// [onProgress] receives 0.0–1.0 as download progresses (extraction not
  /// separately reported).
  /// [onStage] receives a human-readable stage description.
  Future<String> provisionFfmpeg({
    void Function(double progress)? onProgress,
    void Function(String stage)? onStage,
  }) async {
    if (!Platform.isWindows && !Platform.isMacOS) {
      throw UnsupportedError(
        'Automatic FFmpeg provisioning is only supported on Windows and macOS.',
      );
    }

    if (Platform.isWindows) {
      return _provisionFfmpegWindows(onProgress: onProgress, onStage: onStage);
    } else {
      return _provisionFfmpegMacos(onProgress: onProgress, onStage: onStage);
    }
  }

  bool _isWindowsArm64() {
    try {
      final arch =
          (Platform.environment['PROCESSOR_ARCHITEW6432'] ??
                  Platform.environment['PROCESSOR_ARCHITECTURE'] ??
                  '')
              .toLowerCase();
      return arch.contains('arm');
    } catch (_) {
      return false;
    }
  }

  Future<String> _provisionFfmpegWindows({
    void Function(double progress)? onProgress,
    void Function(String stage)? onStage,
  }) async {
    final isArm = _isWindowsArm64();
    final url = isArm ? _ffmpegWindowsArm64Url : _ffmpegWindowsX64Url;
    final zipPath = p.join(binDir, '_ffmpeg_download.zip');

    _log.info(
      'Downloading FFmpeg for Windows (${isArm ? "ARM64" : "x64"}) from: $url',
    );
    onStage?.call('Downloading');
    await _downloadFile(url: url, destPath: zipPath, onProgress: onProgress);

    _log.info('Extracting FFmpeg…');
    onStage?.call('Extracting');
    await _extractFfmpegFromZip(zipPath: zipPath, destDir: binDir);

    // Clean up zip after extraction
    try {
      await File(zipPath).delete();
    } catch (_) {}

    // Verify both ffmpeg and ffprobe exist and run successfully
    onStage?.call('Verifying');
    for (final exe in [ffmpegPath, ffprobePath]) {
      final file = File(exe);
      if (!file.existsSync()) {
        throw StateError(
          'FFmpeg extraction completed but expected binary was not found at $exe',
        );
      }
      final size = file.statSync().size;
      _log.info('Verifying binary at $exe (size: $size bytes)');

      final r = await Process.run(exe, ['-version'], runInShell: false);
      _log.info('$exe -version exitCode: ${r.exitCode}');

      if (r.exitCode != 0) {
        final stdoutStr = r.stdout.toString().trim();
        final stderrStr = r.stderr.toString().trim();
        _log.severe(
          'FFmpeg verification failed for $exe.\n'
          'Exit Code: ${r.exitCode}\n'
          'Stdout: $stdoutStr\n'
          'Stderr: $stderrStr',
        );
        throw StateError(
          'FFmpeg verification failed for $exe.\n'
          'Path: $exe\n'
          'File exists: true, Size: $size bytes\n'
          'Exit Code: ${r.exitCode}\n'
          'Stdout: $stdoutStr\n'
          'Stderr: $stderrStr',
        );
      }
    }

    _log.info('FFmpeg & ffprobe provisioned successfully at: $binDir');
    return ffmpegPath;
  }

  Future<String> _provisionFfmpegMacos({
    void Function(double progress)? onProgress,
    void Function(String stage)? onStage,
  }) async {
    // Determine the right build URL based on architecture.
    // yt-dlp/FFmpeg-Builds provides macOS builds as tar.xz archives.
    final isArm = _isMacOSArm64();
    final archiveUrl = isArm ? _ffmpegMacosAarch64Url : _ffmpegMacosX64Url;
    final archiveName = '_ffmpeg_macos.tar.xz';
    final archivePath = p.join(binDir, archiveName);

    _log.info(
      'Downloading FFmpeg for macOS (${isArm ? "arm64" : "x64"}) from: $archiveUrl',
    );
    onStage?.call('Downloading');
    await _downloadFile(
      url: archiveUrl,
      destPath: archivePath,
      onProgress: onProgress,
    );

    _log.info('Extracting FFmpeg archive…');
    onStage?.call('Extracting');
    await _extractFfmpegFromTarXz(archivePath: archivePath, destDir: binDir);

    // Clean up archive
    try {
      await File(archivePath).delete();
    } catch (_) {}

    // Verify both binaries work
    onStage?.call('Verifying');
    for (final binary in [ffmpegPath, ffprobePath]) {
      if (!File(binary).existsSync()) {
        throw StateError('Expected binary not found after extraction: $binary');
      }
      final result = await Process.run(binary, ['-version'], runInShell: false);
      if (result.exitCode != 0) {
        throw StateError(
          'Downloaded binary verification failed: $binary\n${result.stderr}',
        );
      }
    }

    _log.info('FFmpeg & ffprobe provisioned at: $binDir');
    return ffmpegPath;
  }

  /// Returns true when the current macOS process is running natively on Apple Silicon.
  static bool _isMacOSArm64() {
    // `uname -m` returns arm64 on Apple Silicon (even under Rosetta for native processes).
    try {
      final result = Process.runSync('uname', ['-m']);
      return result.exitCode == 0 &&
          (result.stdout as String).trim().toLowerCase().contains('arm');
    } catch (_) {
      return false;
    }
  }

  Future<void> _extractFfmpegFromTarXz({
    required String archivePath,
    required String destDir,
  }) async {
    // Use tar which is available on macOS (and all POSIX systems)
    final extractDir = p.join(destDir, '_ffmpeg_extracted');
    await Directory(extractDir).create(recursive: true);

    final result = await Process.run('tar', [
      '-xJf',
      archivePath,
      '-C',
      extractDir,
    ], runInShell: false);

    if (result.exitCode != 0) {
      throw ProcessException(
        'tar',
        [],
        'tar extraction failed: ${result.stderr}',
        result.exitCode,
      );
    }

    // Find ffmpeg and ffprobe inside the extracted directory tree
    String? foundFfmpeg;
    String? foundFfprobe;

    await for (final entity in Directory(extractDir).list(recursive: true)) {
      if (entity is File) {
        final base = p.basename(entity.path);
        if (base == 'ffmpeg' && foundFfmpeg == null) foundFfmpeg = entity.path;
        if (base == 'ffprobe' && foundFfprobe == null) {
          foundFfprobe = entity.path;
        }
      }
      if (foundFfmpeg != null && foundFfprobe != null) break;
    }

    if (foundFfmpeg == null) {
      throw StateError(
        'Could not find ffmpeg binary inside downloaded archive.',
      );
    }

    // Copy to binDir and make executable
    await File(foundFfmpeg).copy(ffmpegPath);
    await Process.run('chmod', ['+x', ffmpegPath]);

    if (foundFfprobe != null) {
      await File(foundFfprobe).copy(ffprobePath);
      await Process.run('chmod', ['+x', ffprobePath]);
    }

    // Clean up extracted dir
    try {
      await Directory(extractDir).delete(recursive: true);
    } catch (_) {}
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

  // ── Python ───────────────────────────────────────────────────────────────────

  String get pythonDir => p.join(binDir, 'python');

  bool get isPythonProvisioned =>
      File(p.join(pythonDir, 'python.exe')).existsSync();

  /// Downloads and extracts the Python embeddable package to [binDir]/python.
  ///
  /// This provides a minimal Python environment suitable for running the native
  /// messaging host and AI workers. The embeddable package doesn't include pip
  /// by default, but we can bootstrap it.
  ///
  /// [onProgress] receives 0.0–1.0 as download progresses.
  Future<String> provisionPython({
    void Function(double progress)? onProgress,
  }) async {
    if (!Platform.isWindows) {
      throw UnsupportedError(
        'Automatic Python provisioning is only supported on Windows. '
        'Please install Python from https://python.org',
      );
    }

    final zipPath = p.join(binDir, '_python_download.zip');
    _log.info('Downloading Python embeddable package from: $_pythonWindowsUrl');
    await _downloadFile(
      url: _pythonWindowsUrl,
      destPath: zipPath,
      onProgress: onProgress,
    );

    _log.info('Extracting Python…');
    await _extractPythonFromZip(zipPath: zipPath, destDir: binDir);

    // Clean up zip after extraction
    try {
      await File(zipPath).delete();
    } catch (_) {}

    // Bootstrap pip (the embeddable package doesn't include it by default)
    await _bootstrapPip();

    if (!File(p.join(pythonDir, 'python.exe')).existsSync()) {
      throw StateError(
        'Python extraction completed but python.exe was not found at $pythonDir',
      );
    }

    _log.info('Python provisioned at: $pythonDir');
    return pythonDir;
  }

  Future<void> _extractPythonFromZip({
    required String zipPath,
    required String destDir,
  }) async {
    final pythonDirPath = p.join(destDir, 'python');

    // Use Dart's built-in zip support or PowerShell
    final result = await Process.run('powershell', [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      'Expand-Archive -LiteralPath "${zipPath.replaceAll("'", "''")}" '
          '-DestinationPath "${pythonDirPath.replaceAll("'", "''")}" -Force',
    ]);

    if (result.exitCode != 0) {
      throw ProcessException(
        'powershell',
        [],
        'Expand-Archive failed: ${result.stderr}',
        result.exitCode,
      );
    }

    // The embeddable package extracts directly to python/ directory
    // Verify python.exe exists
    final pythonExe = p.join(pythonDirPath, 'python.exe');
    if (!File(pythonExe).existsSync()) {
      // Try one level deeper
      final dirs = Directory(pythonDirPath)
          .listSync()
          .whereType<Directory>()
          .toList();
      for (final d in dirs) {
        final exe = p.join(d.path, 'python.exe');
        if (File(exe).existsSync()) {
          // Move contents up
          for (final entry in Directory(d.path).listSync()) {
            await entry.rename(p.join(pythonDirPath, p.basename(entry.path)));
          }
          break;
        }
      }
    }
  }

  Future<void> _bootstrapPip() async {
    // The embeddable package includes a _pth file that controls sys.path
    // We need to ensure pip can be bootstrapped
    final pythonExe = p.join(pythonDir, 'python.exe');
    final getPipUrl = 'https://bootstrap.pypa.io/get-pip.py';
    final getPipPath = p.join(pythonDir, 'get-pip.py');

    try {
      _log.info('Bootstrapping pip…');
      await _downloadFile(url: getPipUrl, destPath: getPipPath);

      // Run get-pip.py
      final result = await Process.run(pythonExe, [
        getPipPath,
      ], runInShell: false);
      if (result.exitCode != 0) {
        _log.warning('pip bootstrap failed: ${result.stderr}');
        // Don't throw - pip is optional for our use case
      } else {
        _log.info('pip bootstrapped successfully');
      }

      // Clean up
      try {
        await File(getPipPath).delete();
      } catch (_) {}
    } catch (e) {
      _log.warning('Could not bootstrap pip: $e');
      // Non-fatal
    }
  }
}
