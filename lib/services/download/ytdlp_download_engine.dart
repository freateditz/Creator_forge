import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/config/app_config.dart';
import '../../core/logging/app_logger.dart';
import '../../core/utils/validators.dart';
import '../../models/download_task.dart';
import '../../models/media_info.dart';
import '../../repositories/download_history_repository.dart';
import '../ffmpeg/ffmpeg_service.dart';
import 'download_engine.dart';
import 'download_progress_parser.dart';
import 'metadata_resolver.dart';
import 'ytdlp_locator.dart';

class YtDlpDownloadEngine implements DownloadEngine {
  final DownloadHistoryRepository _historyRepo;
  final FfmpegService _ffmpegService;
  final MetadataResolver _metadataResolver;
  final YtDlpLocator _locator;
  final _log = AppLogger.get('YtDlpDownloadEngine');
  final _uuid = const Uuid();

  int maxConcurrent;
  String defaultOutputDir;

  final _controller = StreamController<List<DownloadTask>>.broadcast();
  final _tasks = <String, DownloadTask>{};
  final _processes = <String, Process>{};
  final _queue = Queue<String>();
  int _activeCount = 0;
  bool _disposed = false;
  // Task IDs that are resuming after a pause (were killed mid-download).
  final _resumedTasks = <String>{};

  YtDlpDownloadEngine({
    required this._historyRepo,
    required this._ffmpegService,
    MetadataResolver? metadataResolver,
    YtDlpLocator? locator,
    this.maxConcurrent = 3,
    String? defaultOutputDir,
  }) : _metadataResolver =
           metadataResolver ?? MetadataResolver(locator: locator),
       _locator = locator ?? YtDlpLocator.instance,
       defaultOutputDir =
           defaultOutputDir ?? AppConfig.instance.defaultDownloadsDir;

  // ── Public interface ────────────────────────────────────────────────────────

  @override
  Stream<List<DownloadTask>> get tasksStream => _controller.stream;

  @override
  List<DownloadTask> get currentTasks =>
      _tasks.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<MediaInfo> resolveMetadata(String url) =>
      _metadataResolver.resolve(url);

  @override
  Future<DownloadTask> enqueue({
    required String url,
    String? formatSelector,
    DownloadType downloadType = DownloadType.videoAndAudio,
    String? outputDirectory,
    MediaInfo? cachedMetadata,
  }) async {
    final validated = Validators.validateUrl(url);
    final id = _uuid.v4();
    final dir = outputDirectory ?? defaultOutputDir;

    await Directory(dir).create(recursive: true);

    final task = DownloadTask(
      id: id,
      url: validated.toString(),
      title: cachedMetadata?.title,
      thumbnailUrl: cachedMetadata?.thumbnailUrl,
      channelName: cachedMetadata?.uploaderName,
      durationSeconds: cachedMetadata?.durationSeconds,
      downloadType: downloadType,
      selectedFormat: formatSelector,
      outputDirectory: dir,
      status: DownloadStatus.queued,
      createdAt: DateTime.now(),
    );

    _tasks[id] = task;
    _queue.add(id);
    await _persistTask(task);
    _emit();
    _processQueue();
    return task;
  }

  @override
  Future<void> pause(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) return;

    if (task.status == DownloadStatus.downloading ||
        task.status == DownloadStatus.resolving ||
        task.status == DownloadStatus.merging) {
      _processes[taskId]?.kill(ProcessSignal.sigterm);
      _updateTask(taskId, status: DownloadStatus.paused);
      // _activeCount is decremented in _startDownload when process exits
    } else if (task.status == DownloadStatus.queued) {
      _queue.remove(taskId);
      _updateTask(taskId, status: DownloadStatus.paused);
    }
  }

  @override
  Future<void> resume(String taskId) async {
    final task = _tasks[taskId];
    if (task == null || task.status != DownloadStatus.paused) return;
    _resumedTasks.add(taskId);
    _updateTask(taskId, status: DownloadStatus.queued);
    _queue.addFirst(taskId); // resume ahead of newly queued items
    _processQueue();
  }

  @override
  Future<void> cancel(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) return;

    _queue.remove(taskId);
    _processes[taskId]?.kill(ProcessSignal.sigterm);
    _processes.remove(taskId);

    _updateTask(
      taskId,
      status: DownloadStatus.cancelled,
      completedAt: DateTime.now(),
    );
    await _cleanTaskTempDir(taskId);
    await _persistTask(_tasks[taskId]!);
  }

  @override
  Future<void> retry(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) return;
    if (task.status != DownloadStatus.failed &&
        task.status != DownloadStatus.cancelled) {
      return;
    }

    // Rebuild from scratch to clear all transient fields (error, progress,
    // speed, ETA) — copyWith can't clear nullable fields to null.
    _tasks[taskId] = DownloadTask(
      id: task.id,
      url: task.url,
      title: task.title,
      thumbnailUrl: task.thumbnailUrl,
      channelName: task.channelName,
      durationSeconds: task.durationSeconds,
      downloadType: task.downloadType,
      selectedFormat: task.selectedFormat,
      selectedQuality: task.selectedQuality,
      outputDirectory: task.outputDirectory,
      status: DownloadStatus.queued,
      createdAt: task.createdAt,
    );
    _queue.add(taskId);
    await _persistTask(_tasks[taskId]!);
    _emit();
    _processQueue();
  }

  @override
  Future<void> remove(String taskId) async {
    await cancel(taskId);
    _tasks.remove(taskId);
    _emit();
  }

  @override
  Future<void> clearCompleted() async {
    final completed = _tasks.entries
        .where(
          (e) =>
              e.value.status == DownloadStatus.completed ||
              e.value.status == DownloadStatus.cancelled,
        )
        .map((e) => e.key)
        .toList();
    for (final id in completed) {
      _tasks.remove(id);
    }
    await _historyRepo.clearCompleted();
    _emit();
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    for (final process in _processes.values) {
      process.kill();
    }
    _processes.clear();
    await _controller.close();
  }

  // ── Initialisation ──────────────────────────────────────────────────────────

  /// Load interrupted tasks from DB on startup and mark them as failed.
  Future<void> initialize() async {
    final interrupted = await _historyRepo.getInterrupted();
    for (final row in interrupted) {
      final task = DownloadTask(
        id: row.taskId,
        url: row.url,
        title: row.title,
        thumbnailUrl: row.thumbnailUrl,
        channelName: row.channelName,
        outputDirectory: row.outputPath,
        status: DownloadStatus.failed,
        errorMessage: 'Interrupted — tap Retry to download again.',
        createdAt: row.createdAt,
        completedAt: row.completedAt,
      );
      _tasks[row.taskId] = task;
      // Mark as failed in DB
      await _historyRepo.updateStatus(
        row.taskId,
        'failed',
        errorMessage: 'Interrupted on previous session.',
      );
    }
    _emit();
  }

  // ── Queue management ────────────────────────────────────────────────────────

  void _processQueue() {
    if (_disposed) return;
    while (_activeCount < maxConcurrent && _queue.isNotEmpty) {
      final taskId = _queue.removeFirst();
      final task = _tasks[taskId];
      if (task == null ||
          task.status == DownloadStatus.cancelled ||
          task.status == DownloadStatus.completed) {
        continue;
      }
      _activeCount++;
      _startDownload(taskId);
    }
  }

  Future<void> _startDownload(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) {
      _activeCount--;
      _processQueue();
      return;
    }

    // ── Locate yt-dlp ────────────────────────────────────────────────────────
    final ytdlpPath = await _locator.resolve();
    if (ytdlpPath == null) {
      _finishTask(
        taskId,
        status: DownloadStatus.failed,
        errorMessage:
            'yt-dlp is not installed or could not be found. '
            'Install it with: pip install yt-dlp',
      );
      return;
    }

    // ── Temp directory ──────────────────────────────────────────────────────
    final tempDir = Directory(p.join(AppConfig.instance.tempDir, taskId));
    try {
      await tempDir.create(recursive: true);
    } catch (e) {
      _finishTask(
        taskId,
        status: DownloadStatus.failed,
        errorMessage: 'Could not create temporary directory.',
      );
      return;
    }

    // ── Build args ───────────────────────────────────────────────────────────
    final outputTemplate = p.join(tempDir.path, '%(title)s [%(id)s].%(ext)s');

    final formatSel = _resolveFormatSelector(task);
    final ffmpegPath = await _ffmpegService.getPath();
    final ffmpegDir = ffmpegPath != null ? p.dirname(ffmpegPath) : null;

    final isResume = _resumedTasks.remove(taskId);

    final args = <String>[
      '--format', formatSel,
      if (task.downloadType == DownloadType.videoAndAudio) ...[
        '--merge-output-format',
        'mp4',
      ],
      if (task.downloadType == DownloadType.audioOnly) ...[
        '--extract-audio',
        '--audio-format',
        'mp3',
        '--audio-quality',
        '0',
      ],
      '--output', outputTemplate,
      if (ffmpegDir != null) ...['--ffmpeg-location', ffmpegDir],
      '--no-playlist',
      '--no-mtime',
      '--newline',
      '--progress',
      '--no-part',
      // --continue resumes fragmented/partial downloads when restarting
      // after a pause. For non-resumable formats it is a no-op.
      if (isResume) '--continue',
      task.url,
    ];

    _log.info('Starting download [$taskId]: $ytdlpPath ${args.join(' ')}');
    _updateTask(taskId, status: DownloadStatus.resolving);
    await _persistTask(_tasks[taskId]!);

    // ── Launch process ───────────────────────────────────────────────────────
    Process process;
    try {
      process = await Process.start(ytdlpPath, args, runInShell: false);
    } catch (e) {
      await _cleanTaskTempDir(taskId);
      _finishTask(
        taskId,
        status: DownloadStatus.failed,
        errorMessage: 'Failed to launch yt-dlp: ${e.toString()}',
      );
      return;
    }

    _processes[taskId] = process;
    _updateTask(taskId, status: DownloadStatus.downloading);

    final errorBuffer = StringBuffer();

    void handleLine(String line) {
      if (line.isEmpty) return;

      if (DownloadProgressParser.isMerging(line)) {
        _updateTask(taskId, status: DownloadStatus.merging);
        return;
      }

      final progress = DownloadProgressParser.parseProgress(line);
      if (progress != null) {
        _updateTask(
          taskId,
          status: DownloadStatus.downloading,
          progress: progress.percent,
          speedBps: progress.speedBps,
          etaSeconds: progress.etaSeconds,
          totalBytes: progress.totalBytes,
          downloadedBytes: progress.downloadedBytes,
        );
        return;
      }

      final err = DownloadProgressParser.parseError(line);
      if (err != null) {
        errorBuffer.writeln(err);
        _log.warning('yt-dlp [$taskId]: $line');
      }
    }

    // yt-dlp sends progress to stderr
    final stderrSub = process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen(handleLine);

    // stdout may carry informational lines
    final stdoutSub = process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen(handleLine);

    final exitCode = await process.exitCode;
    await stderrSub.cancel();
    await stdoutSub.cancel();
    _processes.remove(taskId);

    final currentTask = _tasks[taskId];
    if (currentTask == null || currentTask.status == DownloadStatus.cancelled) {
      await _cleanTaskTempDir(taskId);
      _activeCount--;
      _processQueue();
      return;
    }

    // Paused: process killed by pause(); do NOT mark failed.
    if (currentTask.status == DownloadStatus.paused) {
      // Keep temp dir — will attempt resume with --continue next time.
      _activeCount--;
      _processQueue();
      return;
    }

    if (exitCode == 0) {
      final outputFile = await _findOutputFile(tempDir);
      if (outputFile != null) {
        // Verify the file is non-empty before accepting it.
        final fileStat = await outputFile.stat();
        if (fileStat.size == 0) {
          await _cleanTaskTempDir(taskId);
          _finishTask(
            taskId,
            status: DownloadStatus.failed,
            errorMessage: 'Download produced an empty file. The source may be unavailable.',
          );
          return;
        }
        final finalPath = await _moveToOutputDir(
          outputFile,
          task.outputDirectory,
        );
        await _cleanTaskTempDir(taskId);
        _finishTask(
          taskId,
          status: DownloadStatus.completed,
          outputPath: finalPath,
          progress: 1.0,
          completedAt: DateTime.now(),
        );
      } else {
        await _cleanTaskTempDir(taskId);
        _finishTask(
          taskId,
          status: DownloadStatus.failed,
          errorMessage:
              'Download completed but output file could not be located.',
        );
      }
    } else {
      await _cleanTaskTempDir(taskId);
      final rawError = errorBuffer.toString().trim();
      _finishTask(
        taskId,
        status: DownloadStatus.failed,
        errorMessage: rawError.isNotEmpty
            ? _friendlyError(rawError)
            : 'Download failed (exit code $exitCode).',
      );
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  String _resolveFormatSelector(DownloadTask task) {
    if (task.selectedFormat != null && task.selectedFormat!.isNotEmpty) {
      return task.selectedFormat!;
    }
    return switch (task.downloadType) {
      DownloadType.audioOnly =>
        'bestaudio[ext=m4a]/bestaudio[ext=mp4]/bestaudio',
      DownloadType.videoOnly => 'bestvideo[ext=mp4]/bestvideo',
      DownloadType.videoAndAudio =>
        'bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio/best',
    };
  }

  String _friendlyError(String stderr) {
    if (stderr.contains('This video is unavailable') ||
        stderr.contains('Video unavailable')) {
      return 'This video is unavailable.';
    }
    if (stderr.contains('Private video') || stderr.contains('private')) {
      return 'This content is private and cannot be accessed.';
    }
    if (stderr.contains('Sign in') ||
        stderr.contains('login required') ||
        stderr.contains('not logged in')) {
      return 'This content requires authentication.';
    }
    if (stderr.contains('DRM') || stderr.contains('Widevine')) {
      return 'This content is DRM-protected and cannot be downloaded.';
    }
    if (stderr.contains('HTTP Error 429') ||
        stderr.contains('Too Many Requests')) {
      return 'Rate limited by media source. Please wait a moment and try again.';
    }
    if (stderr.contains('No space left') || stderr.contains('ENOSPC')) {
      return 'Not enough disk space to complete the download.';
    }
    // Return the first meaningful error line
    final firstLine = stderr
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .take(2)
        .join(' ')
        .trim();
    return firstLine.length > 200
        ? '${firstLine.substring(0, 200)}…'
        : firstLine;
  }

  Future<File?> _findOutputFile(Directory dir) async {
    try {
      final entities = await dir.list().toList();
      final files = entities
          .whereType<File>()
          .where(
            (f) =>
                !f.path.endsWith('.part') &&
                !f.path.endsWith('.ytdl') &&
                !f.path.endsWith('.json'),
          )
          .toList();
      if (files.isEmpty) return null;
      // If multiple files (shouldn't happen normally), pick largest
      files.sort((a, b) => b.statSync().size.compareTo(a.statSync().size));
      return files.first;
    } catch (_) {
      return null;
    }
  }

  Future<String> _moveToOutputDir(File file, String outputDir) async {
    await Directory(outputDir).create(recursive: true);
    final filename = p.basename(file.path);
    final sanitized = Validators.sanitizeFilename(filename);
    var dest = p.join(outputDir, sanitized);

    // Avoid overwriting existing files
    if (await File(dest).exists()) {
      final ext = p.extension(dest);
      final stem = p.basenameWithoutExtension(dest);
      int i = 1;
      while (await File(dest).exists()) {
        dest = p.join(outputDir, '$stem ($i)$ext');
        i++;
      }
    }

    await file.rename(dest);
    return dest;
  }

  Future<void> _cleanTaskTempDir(String taskId) async {
    try {
      final dir = Directory(p.join(AppConfig.instance.tempDir, taskId));
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (e) {
      _log.warning('Failed to clean temp dir for task $taskId.', e);
    }
  }

  void _updateTask(
    String taskId, {
    DownloadStatus? status,
    double? progress,
    int? speedBps,
    int? etaSeconds,
    int? totalBytes,
    int? downloadedBytes,
    String? errorMessage,
    String? outputPath,
    DateTime? completedAt,
  }) {
    final task = _tasks[taskId];
    if (task == null) return;
    _tasks[taskId] = task.copyWith(
      status: status,
      progress: progress,
      speedBps: speedBps,
      etaSeconds: etaSeconds,
      totalBytes: totalBytes,
      downloadedBytes: downloadedBytes,
      errorMessage: errorMessage,
      outputPath: outputPath,
      completedAt: completedAt,
    );
    _emit();
  }

  void _finishTask(
    String taskId, {
    required DownloadStatus status,
    double? progress,
    String? outputPath,
    String? errorMessage,
    DateTime? completedAt,
  }) {
    _updateTask(
      taskId,
      status: status,
      progress: progress,
      outputPath: outputPath,
      errorMessage: errorMessage,
      completedAt: completedAt ?? DateTime.now(),
    );
    _persistTask(_tasks[taskId]!).ignore();
    _activeCount--;
    _processQueue();
  }

  Future<void> _persistTask(DownloadTask task) async {
    try {
      await _historyRepo.upsertTask(task);
    } catch (e) {
      _log.warning('Failed to persist task ${task.id}.', e);
    }
  }

  void _emit() {
    if (!_disposed && !_controller.isClosed) {
      _controller.add(currentTasks);
    }
  }
}
