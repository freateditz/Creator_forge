import 'dart:io';

import '../../core/errors/app_exception.dart';
import '../../core/logging/app_logger.dart';
import '../../models/media_probe_result.dart';

abstract interface class FfmpegService {
  Future<bool> isAvailable();
  Future<String?> getVersion();
  Future<String?> getPath();

  /// Probe a media file using ffprobe. Returns codec, stream, and duration info.
  Future<MediaProbeResult> probeMedia(String inputPath);

  Future<void> extractAudio({
    required String inputPath,
    required String outputPath,
    String format = 'mp3',
    int? bitrate,
    void Function(double progress)? onProgress,
  });
  Future<void> convert({
    required String inputPath,
    required String outputPath,
    Map<String, String> extraArgs = const {},
    void Function(double progress)? onProgress,
  });
  Future<void> mergeVideoAudio({
    required String videoPath,
    required String audioPath,
    required String outputPath,
    void Function(double progress)? onProgress,
  });
  Future<Map<String, dynamic>> getMediaInfo(String inputPath);
}

class FfmpegServiceImpl implements FfmpegService {
  final _log = AppLogger.get('FfmpegService');
  String? _ffmpegPath;

  static final List<String> _candidates = _buildCandidates();

  static List<String> _buildCandidates() {
    final c = <String>[
      'ffmpeg',
      '/opt/homebrew/bin/ffmpeg',
      '/usr/local/bin/ffmpeg',
      '/usr/bin/ffmpeg',
    ];
    if (Platform.isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA'] ?? '';
      final userProfile = Platform.environment['USERPROFILE'] ?? '';
      c.addAll([
        // Documented manual install location (see INSTALLATION.md).
        r'C:\Program Files\CreatorForge\bin\ffmpeg.exe',
        // Official ffmpeg.org builds extracted to Program Files.
        r'C:\Program Files\ffmpeg\bin\ffmpeg.exe',
        r'C:\ffmpeg\bin\ffmpeg.exe',
        // WinGet (gyan.dev build).
        if (localAppData.isNotEmpty)
          '$localAppData\\Microsoft\\WinGet\\Packages\\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\\ffmpeg-release-full\\bin\\ffmpeg.exe',
        // Scoop install.
        if (userProfile.isNotEmpty) '$userProfile\\scoop\\shims\\ffmpeg.exe',
        // Chocolatey.
        r'C:\ProgramData\chocolatey\bin\ffmpeg.exe',
        // Last resort: PATH.
        'ffmpeg.exe',
      ]);
    }
    return c;
  }

  Future<String?> _resolvePath() async {
    if (_ffmpegPath != null) return _ffmpegPath;
    for (final candidate in _candidates) {
      try {
        final result = await Process.run(candidate, [
          '-version',
        ], runInShell: false);
        if (result.exitCode == 0) {
          _ffmpegPath = candidate;
          _log.info('FFmpeg found at: $candidate');
          return candidate;
        }
      } catch (_) {}
    }
    return null;
  }

  @override
  Future<bool> isAvailable() async => (await _resolvePath()) != null;

  @override
  Future<String?> getPath() => _resolvePath();

  @override
  Future<String?> getVersion() async {
    final path = await _resolvePath();
    if (path == null) return null;
    try {
      final result = await Process.run(path, ['-version'], runInShell: false);
      if (result.exitCode == 0) {
        final out = result.stdout as String;
        final match = RegExp(r'ffmpeg version (\S+)').firstMatch(out);
        return match?.group(1);
      }
    } catch (e) {
      _log.warning('Could not get FFmpeg version.', e);
    }
    return null;
  }

  @override
  Future<void> extractAudio({
    required String inputPath,
    required String outputPath,
    String format = 'mp3',
    int? bitrate,
    void Function(double progress)? onProgress,
  }) async {
    final path = await _resolvePath();
    if (path == null) {
      throw const DependencyException(
        'FFmpeg is not installed or could not be found.',
        dependency: 'ffmpeg',
      );
    }
    final args = [
      '-i',
      inputPath,
      '-vn',
      if (bitrate != null) ...['-ab', '${bitrate}k'],
      '-y',
      outputPath,
    ];
    await _runProcess(path, args, onProgress: onProgress);
  }

  @override
  Future<void> convert({
    required String inputPath,
    required String outputPath,
    Map<String, String> extraArgs = const {},
    void Function(double progress)? onProgress,
  }) async {
    final path = await _resolvePath();
    if (path == null) {
      throw const DependencyException(
        'FFmpeg is not installed or could not be found.',
        dependency: 'ffmpeg',
      );
    }
    final args = [
      '-i',
      inputPath,
      ...extraArgs.entries.expand((e) => [e.key, e.value]),
      '-y',
      outputPath,
    ];
    await _runProcess(path, args, onProgress: onProgress);
  }

  @override
  Future<void> mergeVideoAudio({
    required String videoPath,
    required String audioPath,
    required String outputPath,
    void Function(double progress)? onProgress,
  }) async {
    final path = await _resolvePath();
    if (path == null) {
      throw const DependencyException(
        'FFmpeg is not installed or could not be found.',
        dependency: 'ffmpeg',
      );
    }
    final args = [
      '-i',
      videoPath,
      '-i',
      audioPath,
      '-c:v',
      'copy',
      '-c:a',
      'aac',
      '-y',
      outputPath,
    ];
    await _runProcess(path, args, onProgress: onProgress);
  }

  @override
  Future<MediaProbeResult> probeMedia(String inputPath) async {
    final ffmpegPath = await _resolvePath();
    if (ffmpegPath == null) {
      throw const DependencyException(
        'FFmpeg is not installed or could not be found.',
        dependency: 'ffmpeg',
      );
    }
    final ffprobePath = ffmpegPath.replaceAll('ffmpeg', 'ffprobe');
    final args = [
      '-v',
      'quiet',
      '-print_format',
      'json',
      '-show_format',
      '-show_streams',
      inputPath,
    ];
    final result = await Process.run(ffprobePath, args, runInShell: false);
    if (result.exitCode != 0) {
      throw MediaException(
        'Could not read media information.',
        technicalDetails: result.stderr as String,
      );
    }
    try {
      return MediaProbeResult.fromRawJson(
        result.stdout as String,
        path: inputPath,
      );
    } catch (e) {
      throw MediaException(
        'Could not parse media information.',
        technicalDetails: e.toString(),
      );
    }
  }

  @override
  Future<Map<String, dynamic>> getMediaInfo(String inputPath) async {
    final path = await _resolvePath();
    if (path == null) {
      throw const DependencyException(
        'FFmpeg is not installed or could not be found.',
        dependency: 'ffmpeg',
      );
    }
    final ffprobePath = path.replaceAll('ffmpeg', 'ffprobe');
    final args = [
      '-v',
      'quiet',
      '-print_format',
      'json',
      '-show_format',
      '-show_streams',
      inputPath,
    ];
    final result = await Process.run(ffprobePath, args, runInShell: false);
    if (result.exitCode != 0) {
      throw MediaException(
        'Could not read media information.',
        technicalDetails: result.stderr as String,
      );
    }
    return {'raw': result.stdout as String};
  }

  Future<void> _runProcess(
    String executable,
    List<String> args, {
    void Function(double)? onProgress,
  }) async {
    _log.fine('Running: $executable ${args.join(' ')}');
    final process = await Process.start(executable, args, runInShell: false);
    process.stderr
        .transform(const SystemEncoding().decoder)
        .listen((data) => _parseProgress(data, onProgress));
    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      throw const ProcessingException(
        'Media processing failed.',
        technicalDetails: 'Non-zero exit code from FFmpeg.',
      );
    }
  }

  void _parseProgress(String output, void Function(double)? callback) {
    if (callback == null) return;
    // time= parsing requires knowing total duration for accurate %;
    // callers that need exact progress should pass duration separately.
    RegExp(r'time=(\d+):(\d+):(\d+\.\d+)').firstMatch(output);
  }
}
