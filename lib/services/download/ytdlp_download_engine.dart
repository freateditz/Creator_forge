import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/config/app_config.dart';
import '../../core/logging/app_logger.dart';
import '../../core/utils/validators.dart';
import '../../models/app_settings.dart';
import '../../models/download_task.dart';
import '../../models/media_info.dart';
import '../../repositories/download_history_repository.dart';
import '../../services/download/destination_resolver.dart';
import '../../services/download/file_category_classifier.dart';
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
  final _destinationResolver = DestinationResolver.instance;
  final _classifier = FileCategoryClassifier.instance;

  int maxConcurrent;
  String defaultOutputDir;
  AppSettings? _appSettings;

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
           defaultOutputDir ??
           (() {
             try {
               return AppConfig.instance.defaultDownloadsDir;
             } catch (_) {
               return Directory.systemTemp.path;
             }
           })();

  void updateSettings(AppSettings settings) {
    _appSettings = settings;
  }

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

    final suggestedFilename =
        cachedMetadata?.title ??
        validated.pathSegments.lastOrNull ??
        'download';

    // Classify the file based on available information
    final classification = _classifier.classify(
      mimeType: null, // yt-dlp handles media files, classification by extension
      contentDispositionFilename: null,
      finalFilename: suggestedFilename,
      browserFilename: cachedMetadata?.title,
      url: validated.toString(),
    );

    final category = classification.category;

    // Resolve destination using the centralized resolver
    // If outputDirectory was explicitly provided (not default), use it directly
    // Otherwise use auto-organization
    final settings =
        _appSettings ??
        AppSettings(
          defaultDownloadsDir: defaultOutputDir,
          tempDir: defaultOutputDir,
        );

    final (outputDir, outputFilename, finalPath) = await _destinationResolver
        .resolve(
          suggestedFilename: suggestedFilename,
          category: category,
          settings: settings,
          customCategoryFolder: outputDirectory != defaultOutputDir
              ? outputDirectory
              : null,
        );

    final task = DownloadTask(
      id: id,
      url: validated.toString(),
      title: cachedMetadata?.title ?? outputFilename,
      thumbnailUrl: cachedMetadata?.thumbnailUrl,
      channelName: cachedMetadata?.uploaderName,
      durationSeconds: cachedMetadata?.durationSeconds,
      downloadType: downloadType,
      selectedFormat: formatSelector,
      outputDirectory: outputDir.path,
      outputFilename: outputFilename,
      category: category,
      destinationFolder: outputDir.path,
      status: DownloadStatus.queued,
      createdAt: DateTime.now(),
      tempDirectory: '', // Will be set during download
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
    await _cleanTaskTempDir(taskId, task.outputPath);
    final cancelledTask = _tasks[taskId];
    if (cancelledTask != null) await _persistTask(cancelledTask);
  }

  @override
  Future<void> retry(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) return;
    if (task.status != DownloadStatus.failed &&
        task.status != DownloadStatus.cancelled) {
      return;
    }

    // Check if we can resume from existing temp files
    final tempDir =
        task.tempDirectory ??
        p.join(
          p.dirname(task.outputPath ?? task.outputDirectory),
          '.creatorforge_temp',
          taskId,
        );

    // For yt-dlp, we use --continue flag which handles partial downloads
    // Check if there are any partial files in temp dir
    bool hasPartialFiles = false;
    if (await Directory(tempDir).exists()) {
      final entities = await Directory(tempDir).list().toList();
      hasPartialFiles = entities.any(
        (e) =>
            e is File &&
            (e.path.endsWith('.part') ||
                e.path.endsWith('.ytdl') ||
                e.path.endsWith('.tmp')),
      );
    }

    if (hasPartialFiles) {
      _log.info(
        'Retry $taskId: Found partial files. Will resume with --continue.',
      );
      _tasks[taskId] = task.copyWith(
        status: DownloadStatus.queued,
        progress: 0,
        speedBps: null,
        etaSeconds: null,
        errorMessage: null,
      );
      _resumedTasks.add(taskId);
    } else {
      // No partial files - clean start
      _log.info('Retry $taskId: No partial files found. Clean restart.');
      _tasks[taskId] = task.copyWith(
        status: DownloadStatus.queued,
        progress: 0,
        speedBps: null,
        etaSeconds: null,
        downloadedBytes: 0,
        errorMessage: null,
        outputPath: null,
        completedAt: null,
      );
      await _cleanTaskTempDir(taskId, task.outputPath);
      await _historyRepo.deleteSegmentsByTaskId(taskId);
    }
    _queue.add(taskId);
    await _persistTask(_tasks[taskId]!);
    _emit();
    _processQueue();
  }

  @override
  Future<void> remove(String taskId) async {
    await cancel(taskId);
    _tasks.remove(taskId);
    await _historyRepo.deleteByTaskId(taskId);
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

  /// Load interrupted tasks from DB on startup and determine recovery state.
  Future<void> initialize() async {
    final interrupted = await _historyRepo.getInterrupted();
    for (final row in interrupted) {
      final taskData = await _historyRepo.getTaskWithSegments(row.taskId);
      final segments = taskData.segments;
      final tempDir =
          row.tempDirectory ??
          p.join(p.dirname(row.outputPath), '.creatorforge_temp', row.taskId);

      // Check for partial files in temp directory
      bool hasPartialFiles = false;
      if (await Directory(tempDir).exists()) {
        final entities = await Directory(tempDir).list().toList();
        hasPartialFiles = entities.any(
          (e) =>
              e is File &&
              (e.path.endsWith('.part') ||
                  e.path.endsWith('.ytdl') ||
                  e.path.endsWith('.tmp')),
        );
      }

      // Also check for .part file at final destination
      final partFile = File('${row.outputPath}.part');
      final hasFinalPartFile = await partFile.exists();

      String recoveryState;
      DownloadStatus initialStatus;
      String? errorMessage;

      if (row.status == 'merging' || hasFinalPartFile) {
        // Was in merging phase or has .part file - check if merge was completed
        recoveryState = 'merging';
        initialStatus = DownloadStatus.failed;
        errorMessage =
            'Download interrupted during finalization. Tap Retry to restart.';
      } else if (hasPartialFiles) {
        // Has partial files - can resume with --continue
        recoveryState = 'resumable';
        initialStatus = DownloadStatus.paused;
        errorMessage = 'Download interrupted. Tap Resume to continue.';
      } else if (segments.isNotEmpty) {
        // Has segments in DB but no files - corrupted
        recoveryState = 'corrupted';
        initialStatus = DownloadStatus.failed;
        errorMessage = 'Download data corrupted. Tap Retry to restart.';
      } else {
        // No recoverable state
        recoveryState = 'unknown';
        initialStatus = DownloadStatus.failed;
        errorMessage = 'Interrupted — tap Retry to download again.';
      }

      final task = DownloadTask(
        id: row.taskId,
        url: row.url,
        title: row.title,
        thumbnailUrl: row.thumbnailUrl,
        channelName: row.channelName,
        outputDirectory: row.outputPath,
        status: initialStatus,
        errorMessage: errorMessage,
        createdAt: row.createdAt,
        completedAt: row.completedAt,
        totalBytes: row.fileSizeBytes,
        downloadedBytes: row.actualBytes,
        eTag: row.eTag,
        lastModified: row.lastModified,
        profile: row.profile,
        tempDirectory: row.tempDirectory,
        recoveryState: recoveryState,
        originalFileSize: row.fileSizeBytes,
        originalETag: row.eTag,
      );
      _tasks[row.taskId] = task;

      // Update DB with recovery state
      await _historyRepo.updateRecoveryState(row.taskId, recoveryState);
      await _historyRepo.updateStatus(
        row.taskId,
        _statusToString(initialStatus),
        errorMessage: errorMessage,
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

    // The task may have been removed or cancelled while the locator was running.
    if (!_isTaskActive(taskId)) {
      await _cleanTaskTempDir(taskId, task.outputPath);
      _activeCount--;
      _processQueue();
      return;
    }
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

    // ── Determine final output path and temp directory ──────────────────────
    // The final path is needed to ensure temp files are on the same volume
    final outputFilename = task.outputFilename ?? task.title ?? 'download';
    final finalPath = p.join(task.outputDirectory, outputFilename);

    // Resolve temp directory on the same volume as the final destination
    // for atomic rename (critical for crash-safe finalization)
    final tempDir = await _destinationResolver.resolveTempDirectory(
      taskId: taskId,
      finalDestinationPath: finalPath,
    );
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

    // Update task with temp directory for recovery
    _updateTask(taskId, tempDirectory: tempDir.path);

    // ── Build args ───────────────────────────────────────────────────────────
    final outputTemplate = p.join(tempDir.path, '%(title)s [%(id)s].%(ext)s');

    final formatSel = _resolveFormatSelector(task);
    final ffmpegPath = await _ffmpegService.getPath();
    final ffmpegDir = ffmpegPath != null ? p.dirname(ffmpegPath) : null;

    // Task may have been cancelled while waiting for FFmpeg path.
    if (!_isTaskActive(taskId)) {
      await _cleanTaskTempDir(taskId, task.outputPath);
      _activeCount--;
      _processQueue();
      return;
    }

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
      '--concurrent-fragments',
      '4',
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
    final resolvingTask = _tasks[taskId];
    if (resolvingTask != null) await _persistTask(resolvingTask);

    // ── Launch process ───────────────────────────────────────────────────────
    Process process;
    try {
      process = await Process.start(ytdlpPath, args, runInShell: false);
    } catch (e) {
      await _cleanTaskTempDir(taskId, task.outputPath);
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
      await _cleanTaskTempDir(taskId, currentTask?.outputPath);
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
      final outputFile = await _findOutputFile(tempDir, task);
      if (outputFile != null) {
        // Verify the file is non-empty before accepting it.
        final fileStat = await outputFile.stat();
        if (fileStat.size == 0) {
          await _cleanTaskTempDir(taskId, task.outputPath);
          _finishTask(
            taskId,
            status: DownloadStatus.failed,
            errorMessage:
                'Download produced an empty file. '
                'The source may be unavailable.',
          );
          return;
        }
        final finalPath = await _moveToOutputDir(
          outputFile,
          task.outputDirectory,
          task.category,
        );
        await _cleanTaskTempDir(taskId, task.outputPath);

        // Clear recovery state on success
        await _historyRepo.updateRecoveryState(taskId, 'completed');

        _finishTask(
          taskId,
          status: DownloadStatus.completed,
          outputPath: finalPath,
          progress: 1.0,
          completedAt: DateTime.now(),
        );
      } else {
        await _cleanTaskTempDir(taskId, task.outputPath);
        _finishTask(
          taskId,
          status: DownloadStatus.failed,
          errorMessage:
              'Download completed but output file could not be located.',
        );
      }
    } else {
      // Check if there's a .part file at final destination (merge was in progress)
      final outputFilename = task.outputFilename ?? task.title ?? 'download';
      final finalPath = p.join(task.outputDirectory, outputFilename);
      final partFile = File('$finalPath.part');
      if (await partFile.exists()) {
        await _historyRepo.updateRecoveryState(taskId, 'merging_failed');
      }

      await _cleanTaskTempDir(taskId, task.outputPath);
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
      if (task.downloadType == DownloadType.videoOnly) {
        // Strip audio stream specification if user selected video-only
        if (task.selectedFormat!.contains('+')) {
          final parts = task.selectedFormat!.split('/');
          final videoOnlyParts = parts.map((part) {
            if (part.contains('+')) return part.split('+').first;
            return part;
          });
          return videoOnlyParts.join('/');
        }
      }
      return task.selectedFormat!;
    }
    return switch (task.downloadType) {
      DownloadType.audioOnly =>
        'bestaudio[ext=m4a]/bestaudio[ext=mp4]/bestaudio/best',
      DownloadType.videoOnly => 'bestvideo[ext=mp4]/bestvideo/best',
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

  Future<File?> _findOutputFile(Directory dir, [DownloadTask? task]) async {
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

      // If video+audio was requested and yt-dlp left separate streams:
      if (task?.downloadType == DownloadType.videoAndAudio &&
          files.length >= 2) {
        File? videoFile;
        File? audioFile;

        for (final file in files) {
          final ext = p.extension(file.path).toLowerCase();
          final name = p.basename(file.path).toLowerCase();
          if (name.contains('.f') ||
              name.contains('video') ||
              name.contains('audio')) {
            if (ext == '.mp4' || ext == '.webm' || ext == '.mkv') {
              if (videoFile == null ||
                  file.lengthSync() > videoFile.lengthSync()) {
                videoFile = file;
              }
            }
            if (ext == '.m4a' ||
                ext == '.opus' ||
                ext == '.mp3' ||
                (ext == '.webm' && file != videoFile)) {
              if (audioFile == null ||
                  file.lengthSync() < (videoFile?.lengthSync() ?? 0)) {
                audioFile = file;
              }
            }
          }
        }

        // If we found both and they are distinct files:
        if (videoFile != null &&
            audioFile != null &&
            videoFile.path != audioFile.path) {
          try {
            _updateTask(task!.id, status: DownloadStatus.merging);
            final baseName = p
                .basenameWithoutExtension(videoFile.path)
                .replaceAll(RegExp(r'\.f[0-9]+$'), '');
            final mergedPath = p.join(dir.path, '$baseName.mp4');
            _log.info(
              'Merging separate downloaded video and audio files: '
              '${videoFile.path} + ${audioFile.path} -> $mergedPath',
            );
            await _ffmpegService.mergeVideoAudio(
              videoPath: videoFile.path,
              audioPath: audioFile.path,
              outputPath: mergedPath,
            );
            final mergedFile = File(mergedPath);
            if (await mergedFile.exists() && (await mergedFile.length()) > 0) {
              return mergedFile;
            }
          } catch (e) {
            _log.warning('Fallback FFmpeg merge failed: $e');
          }
        }
      }

      // If single file or fallback: pick largest
      files.sort((a, b) => b.statSync().size.compareTo(a.statSync().size));
      return files.first;
    } catch (_) {
      return null;
    }
  }

  Future<String> _moveToOutputDir(
    File file,
    String outputDir,
    FileCategory? category,
  ) async {
    await Directory(outputDir).create(recursive: true);
    final filename = p.basename(file.path);
    final sanitized = Validators.sanitizeFilename(filename);

    // Use destination resolver to ensure unique path
    final uniquePath = await _destinationResolver.ensureUniquePath(
      basePath: p.join(outputDir, sanitized),
      category: category ?? FileCategory.other,
      settings:
          _appSettings ??
          AppSettings(
            defaultDownloadsDir: outputDir,
            tempDir: AppConfig.instance.tempDir,
          ),
    );

    await file.rename(uniquePath);
    return uniquePath;
  }

  Future<void> _cleanTaskTempDir(String taskId, String? outputPath) async {
    try {
      final dir = Directory(p.join(AppConfig.instance.tempDir, taskId));
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (e) {
      _log.warning('Failed to clean temp dir for task $taskId.', e);
    }
    // Also clean up new location pattern (under destination parent)
    if (outputPath != null) {
      try {
        final parentDir = p.dirname(outputPath);
        final tempDir = Directory(
          p.join(parentDir, '.creatorforge_temp', taskId),
        );
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (e) {
        _log.warning(
          'Failed to clean new-location temp dir for task $taskId.',
          e,
        );
      }
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
    String? tempDirectory,
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
      tempDirectory: tempDirectory ?? task.tempDirectory,
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
    if (_disposed) {
      _activeCount--;
      return;
    }
    _updateTask(
      taskId,
      status: status,
      progress: progress,
      outputPath: outputPath,
      errorMessage: errorMessage,
      completedAt: completedAt ?? DateTime.now(),
    );
    // The task may have been removed by remove() or clearCompleted() before
    // this callback ran — that is a valid lifecycle transition, not a bug.
    final task = _tasks[taskId];
    if (task != null) _persistTask(task).ignore();
    _activeCount--;
    _processQueue();
  }

  /// Returns true when [taskId] is present in [_tasks] and not in a terminal
  /// state that should abort an in-flight download startup.
  bool _isTaskActive(String taskId) {
    if (_disposed) return false;
    final task = _tasks[taskId];
    return task != null &&
        task.status != DownloadStatus.cancelled &&
        task.status != DownloadStatus.completed;
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

  String _statusToString(DownloadStatus status) => switch (status) {
    DownloadStatus.queued => 'queued',
    DownloadStatus.resolving => 'resolving',
    DownloadStatus.downloading => 'downloading',
    DownloadStatus.paused => 'paused',
    DownloadStatus.merging => 'merging',
    DownloadStatus.completed => 'completed',
    DownloadStatus.failed => 'failed',
    DownloadStatus.cancelled => 'cancelled',
  };
}
