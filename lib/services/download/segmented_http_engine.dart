// ignore_for_file: prefer_initializing_formals
import 'dart:async';
import 'dart:collection';
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
import 'adaptive_concurrency.dart';
import 'connection_scheduler.dart';
import 'download_engine.dart';

/// Minimum file size (bytes) required to attempt range-segmented download.
/// Smaller files download as a single stream to avoid unnecessary overhead.
const _kMinSegmentSize = 512 * 1024; // 512 KB

class SegmentedHttpEngine implements DownloadEngine {
  final DownloadHistoryRepository _historyRepo;
  final _log = AppLogger.get('SegmentedHttpEngine');
  final _uuid = const Uuid();
  final _destinationResolver = DestinationResolver.instance;
  final _classifier = FileCategoryClassifier.instance;

  int maxConcurrent;
  int segmentCount;
  DownloadProfile downloadProfile;
  String defaultOutputDir;
  AppSettings? _appSettings;

  final _controller = StreamController<List<DownloadTask>>.broadcast();
  final _tasks = <String, DownloadTask>{};
  final _queue = Queue<String>();

  // HttpClient handles per active task — stored so cancel() can abort them.
  final _clients = <String, List<HttpClient>>{};
  int _activeCount = 0;
  bool _disposed = false;

  // For speed/ETA calculation
  final _progressHistory = <String, List<_ProgressSnapshot>>{};

  SegmentedHttpEngine({
    required DownloadHistoryRepository historyRepo,
    this.maxConcurrent = 3,
    this.segmentCount = 8,
    this.downloadProfile = DownloadProfile.balanced,
    String? defaultOutputDir,
  }) : _historyRepo = historyRepo,
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

  /// Segmented engine resolves nothing — it only handles direct URLs.
  @override
  Future<MediaInfo> resolveMetadata(String url) async {
    final uri = Validators.validateUrl(url);
    final filename = uri.pathSegments.lastOrNull ?? 'file';
    return MediaInfo(
      url: url,
      title: filename,
      formats: const [],
      resolvedAt: DateTime.now(),
    );
  }

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

    // Check for duplicate URL already in queue or downloading
    for (final existing in _tasks.values) {
      if (existing.url == validated.toString() &&
          existing.status != DownloadStatus.completed &&
          existing.status != DownloadStatus.cancelled &&
          existing.status != DownloadStatus.failed) {
        _log.info('Duplicate URL already enqueued: ${validated.toString()}');
        return existing;
      }
    }

    final suggestedFilename =
        cachedMetadata?.title ??
        validated.pathSegments.lastOrNull ??
        'download';

    // Classify the file based on available information
    final classification = _classifier.classify(
      mimeType:
          null, // MediaFormat doesn't expose mimeType; classify by extension
      contentDispositionFilename:
          null, // Could be extracted from headers if available
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
          tempDir:
              defaultOutputDir, // Use output dir as temp dir fallback in tests
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
    _emit();
    _processQueue();
    return task;
  }

  @override
  Future<void> pause(String taskId) async {
    final task = _tasks[taskId];
    if (task == null || task.status != DownloadStatus.downloading) return;
    _abortClients(taskId);
    GlobalConnectionScheduler.instance.releaseTaskSlots(taskId);
    _updateTask(taskId, status: DownloadStatus.paused);
    _activeCount--;
    await _persistTask(_tasks[taskId]!);
    _processQueue();
  }

  @override
  Future<void> resume(String taskId) async {
    final task = _tasks[taskId];
    if (task == null || task.status != DownloadStatus.paused) return;
    // Preserve existing progress and queue for resume
    _updateTask(taskId, status: DownloadStatus.queued);
    _queue.addFirst(taskId);
    _processQueue();
  }

  @override
  Future<void> cancel(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) return;
    _abortClients(taskId);
    GlobalConnectionScheduler.instance.releaseTaskSlots(taskId);
    if (task.status == DownloadStatus.queued) _queue.remove(taskId);
    _updateTask(taskId, status: DownloadStatus.cancelled);
    final updated = _tasks[taskId];
    if (updated != null) await _persistTask(updated);
    if (task.status == DownloadStatus.downloading ||
        task.status == DownloadStatus.resolving) {
      _activeCount--;
      _processQueue();
    }
    _deleteTempFiles(taskId, task.outputPath);
  }

  @override
  Future<void> retry(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) return;
    if (task.status != DownloadStatus.failed &&
        task.status != DownloadStatus.cancelled) {
      return;
    }

    // Check if we can resume from existing segments
    final tempDir =
        task.tempDirectory ??
        p.join(
          p.dirname(task.outputPath ?? task.outputDirectory),
          '.creatorforge_temp',
          taskId,
        );
    final (verifiedCount, totalCount, allValid) = await _historyRepo
        .verifySegments(taskId, tempDir);

    if (allValid && totalCount > 0) {
      // Segments are valid - preserve them and resume
      _log.info(
        'Retry $taskId: Found $verifiedCount/$totalCount valid segments. Resuming.',
      );
      _updateTask(
        taskId,
        status: DownloadStatus.queued,
        progress: 0,
        errorMessage: null,
      );
      // Keep progress history for speed calculation
    } else {
      // Segments are corrupted or missing - clean start
      _log.info(
        'Retry $taskId: Segments invalid ($verifiedCount/$totalCount). Clean restart.',
      );
      _progressHistory.remove(taskId);
      await _historyRepo.deleteSegmentsByTaskId(taskId);
      _deleteTempFiles(taskId, task.outputPath);
      _updateTask(
        taskId,
        status: DownloadStatus.queued,
        progress: 0,
        errorMessage: null,
        downloadedBytes: 0,
      );
    }
    _queue.add(taskId);
    _processQueue();
  }

  @override
  Future<void> remove(String taskId) async {
    await cancel(taskId);
    _tasks.remove(taskId);
    _progressHistory.remove(taskId);
    await _historyRepo.deleteByTaskId(taskId);
    _emit();
  }

  @override
  Future<void> clearCompleted() async {
    final toRemove = _tasks.values
        .where(
          (t) =>
              t.status == DownloadStatus.completed ||
              t.status == DownloadStatus.cancelled,
        )
        .map((t) => t.id)
        .toList();
    for (final id in toRemove) {
      _tasks.remove(id);
      _progressHistory.remove(id);
    }
    await _historyRepo.clearCompleted();
    _emit();
  }

  Future<void> initialize() async {
    final interrupted = await _historyRepo.getInterrupted();
    for (final row in interrupted) {
      final taskData = await _historyRepo.getTaskWithSegments(row.taskId);
      final segments = taskData.segments;
      final tempDir =
          row.tempDirectory ??
          p.join(p.dirname(row.outputPath), '.creatorforge_temp', row.taskId);

      // Verify segments on disk
      int verifiedCount = 0;
      final totalCount = segments.length;

      for (final seg in segments) {
        final expectedPath =
            seg.segmentPath ?? '$tempDir/seg_${seg.segmentIndex}.tmp';
        final file = File(expectedPath);
        if (await file.exists()) {
          final actualSize = await file.length();
          if (actualSize == seg.bytesDownloaded &&
              actualSize == seg.expectedBytes) {
            verifiedCount++;
          }
        }
      }

      String recoveryState;
      DownloadStatus initialStatus;
      String? errorMessage;

      if (totalCount > 0 && verifiedCount == totalCount) {
        // All segments verified - resumable
        recoveryState = 'resumable';
        initialStatus = DownloadStatus.paused; // User must explicitly resume
        errorMessage = 'Download interrupted. Tap Resume to continue.';
      } else if (verifiedCount > 0) {
        // Some segments verified - partially corrupted
        recoveryState = 'corrupted';
        initialStatus = DownloadStatus.failed;
        errorMessage =
            'Download corrupted ($verifiedCount/$totalCount segments valid). Tap Retry to restart.';
      } else if (row.status == 'merging') {
        // Was in merging phase - check for .part file
        recoveryState = 'merging';
        initialStatus = DownloadStatus.failed;
        errorMessage =
            'Download interrupted during merge. Tap Retry to restart.';
      } else {
        // No valid segments or unknown state
        recoveryState = 'unknown';
        initialStatus = DownloadStatus.failed;
        errorMessage = 'Interrupted — tap Retry to download again.';
      }

      final task = DownloadTask(
        id: row.taskId,
        url: row.url,
        title: row.title,
        outputDirectory: row.outputPath,
        outputFilename: row.outputFilename,
        outputPath: row.outputFilename.isNotEmpty
            ? p.join(row.outputPath, row.outputFilename)
            : null,
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
    if (_tasks.isNotEmpty) _emit();
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    for (final id in _clients.keys.toList()) {
      _abortClients(id);
    }
    await _controller.close();
  }

  // ── Queue processing ────────────────────────────────────────────────────────

  void _processQueue() {
    if (_disposed) return;
    while (_activeCount < maxConcurrent && _queue.isNotEmpty) {
      final id = _queue.removeFirst();
      if (!_tasks.containsKey(id)) continue;
      _activeCount++;
      _startDownload(id);
    }
  }

  Future<void> _startDownload(String taskId) async {
    if (!_isTaskActive(taskId)) {
      _activeCount--;
      _processQueue();
      return;
    }

    final task = _tasks[taskId]!;
    final uri = Uri.parse(task.url);
    final outputPath = p.join(task.outputDirectory, task.outputFilename!);

    // Resolve temp directory on the same volume as the final destination
    // for atomic rename (critical for crash-safe finalization)
    final tempDir = await _destinationResolver.resolveTempDirectory(
      taskId: taskId,
      finalDestinationPath: outputPath,
    );

    _updateTask(
      taskId,
      status: DownloadStatus.resolving,
      tempDirectory: tempDir.path,
    );

    // ── HEAD request for validation ──────────────────────────────────────────
    int? contentLength;
    bool acceptsRanges = false;
    String? eTag;
    String? lastModified;

    try {
      final headClient = HttpClient()
        ..connectionTimeout = const Duration(seconds: 20);
      _addClient(taskId, headClient);

      final headReq = await headClient.headUrl(uri);
      headReq.followRedirects = true;
      headReq.maxRedirects = 5;
      final headResp = await headReq.close();
      await headResp.drain<void>();

      contentLength = headResp.contentLength > 0
          ? headResp.contentLength
          : null;
      acceptsRanges =
          headResp.headers.value('accept-ranges')?.toLowerCase() == 'bytes';
      eTag = headResp.headers.value('etag');
      lastModified = headResp.headers.value('last-modified');

      _removeClient(taskId, headClient);
    } catch (e) {
      _log.warning('HEAD request failed for $taskId: $e');
      // Proceed without range info — fall back to single stream.
    }

    if (!_isTaskActive(taskId)) {
      _activeCount--;
      _processQueue();
      return;
    }

    // Resource validation: if ETag or Last-Modified changed, or size changed, we must restart.
    if (task.totalBytes != null &&
        contentLength != null &&
        task.totalBytes != contentLength) {
      _log.info('Resource size changed ($taskId). Restarting download.');
      await _historyRepo.deleteSegmentsByTaskId(taskId);
      _deleteTempFiles(taskId, outputPath);
    } else if (task.eTag != null && eTag != null && task.eTag != eTag) {
      _log.info('Resource ETag changed ($taskId). Restarting download.');
      await _historyRepo.deleteSegmentsByTaskId(taskId);
      _deleteTempFiles(taskId, outputPath);
    }

    _updateTask(
      taskId,
      status: DownloadStatus.downloading,
      totalBytes: contentLength,
      eTag: eTag,
      lastModified: lastModified,
    );

    // ── Decide: segmented or single-stream ──────────────────────────────────
    final knownLength = contentLength;
    final useSegments =
        acceptsRanges &&
        knownLength != null &&
        knownLength > _kMinSegmentSize &&
        segmentCount > 1;

    try {
      if (useSegments) {
        await _downloadSegmented(
          taskId,
          uri,
          outputPath,
          knownLength,
          tempDir.path,
        );
      } else {
        await _downloadSingleStream(taskId, uri, outputPath);
      }
    } catch (e) {
      if (_isTaskActive(taskId)) {
        _log.warning('Download failed for $taskId: $e');
        _finishTask(taskId, status: DownloadStatus.failed, error: e.toString());
        return;
      }
    }
  }

  // ── Segmented download ──────────────────────────────────────────────────────

  Future<void> _downloadSegmented(
    String taskId,
    Uri uri,
    String outputPath,
    int totalBytes,
    String tempDir,
  ) async {
    await Directory(tempDir).create(recursive: true);

    final segSize = (totalBytes / segmentCount).ceil();
    final segProgress = List<int>.filled(segmentCount, 0);
    var lastEmit = DateTime.now();

    Future<void> downloadSegment(int i) async {
      final start = i * segSize;
      final end = (start + segSize - 1).clamp(0, totalBytes - 1);
      final segPath = p.join(tempDir, 'seg_$i.tmp');

      // Persist segment metadata before download
      await _historyRepo.upsertSegment(
        taskId: taskId,
        index: i,
        start: start,
        end: end,
        downloaded: 0,
        status: 'downloading',
        segmentPath: segPath,
      );

      await GlobalConnectionScheduler.instance.acquireSlot(taskId, i, uri.host);
      try {
        final client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 30);
        _addClient(taskId, client);

        try {
          final req = await client.getUrl(uri);
          req.followRedirects = true;
          req.maxRedirects = 5;
          req.headers.set('Range', 'bytes=$start-$end');

          final resp = await req.close();
          if (resp.statusCode == 200) {
            throw HttpException(
              'Server returned HTTP 200 instead of 206 for Range request; falling back to single stream.',
              uri: uri,
            );
          }
          if (resp.statusCode != 206) {
            throw HttpException(
              'Unexpected status ${resp.statusCode} for segment $i',
              uri: uri,
            );
          }

          final sink = File(segPath).openWrite();
          try {
            int segmentDownloaded = 0;
            await for (final chunk in resp) {
              if (!_isTaskActive(taskId)) {
                await sink.flush();
                await sink.close();
                // Update segment as partial
                await _historyRepo.upsertSegment(
                  taskId: taskId,
                  index: i,
                  start: start,
                  end: end,
                  downloaded: segmentDownloaded,
                  status: 'pending',
                  segmentPath: segPath,
                );
                return;
              }
              sink.add(chunk);
              segmentDownloaded += chunk.length;
              segProgress[i] += chunk.length;

              // Throttle progress updates to ~10 Hz.
              final now = DateTime.now();
              if (now.difference(lastEmit).inMilliseconds >= 100) {
                lastEmit = now;
                final done = segProgress.fold(0, (a, b) => a + b);
                _updateTaskWithSpeed(
                  taskId,
                  downloadedBytes: done,
                  progress: done / totalBytes,
                  totalBytes: totalBytes,
                );
              }
            }
            await sink.flush();

            // Mark segment as completed with correct bytes
            await _historyRepo.upsertSegment(
              taskId: taskId,
              index: i,
              start: start,
              end: end,
              downloaded: segmentDownloaded,
              status: 'completed',
              segmentPath: segPath,
            );
          } finally {
            await sink.close();
          }
        } finally {
          _removeClient(taskId, client);
        }
      } finally {
        GlobalConnectionScheduler.instance.releaseSlot(taskId, i);
      }
    }

    try {
      await Future.wait(
        List.generate(segmentCount, downloadSegment),
        eagerError: true,
      );
    } catch (e) {
      if (e.toString().contains('HTTP 200')) {
        _log.info(
          'Server does not support partial ranges correctly; falling back to single stream for $taskId',
        );
        _abortClients(taskId);
        _deleteTempFiles(taskId, outputPath);
        // Single-stream download will persist its own success/failure
        await _downloadSingleStream(taskId, uri, outputPath);
        return;
      }
      _finishTask(taskId, status: DownloadStatus.failed, error: e.toString());
      return; // Don't rethrow - we handle failure gracefully
    }

    if (!_isTaskActive(taskId)) {
      _deleteTempFiles(taskId, outputPath);
      _activeCount--;
      _processQueue();
      return;
    }

    // ── Crash-safe merge segments ─────────────────────────────────────────────
    // Set merging state in DB for recovery
    await _historyRepo.setMergingStarted(taskId);
    _updateTask(taskId, status: DownloadStatus.merging, progress: 1.0);

    final partPath = '$outputPath.part';
    final out = File(partPath).openWrite();
    try {
      for (int i = 0; i < segmentCount; i++) {
        final seg = File(p.join(tempDir, 'seg_$i.tmp'));
        if (seg.existsSync()) {
          await out.addStream(seg.openRead());
        } else {
          throw StateError('Missing segment $i during merge');
        }
      }
      await out.flush();
    } finally {
      await out.close();
    }

    // Verify merged file size matches expected
    final partFile = File(partPath);
    if (!partFile.existsSync()) {
      throw StateError('Merge failed: .part file not created');
    }

    final mergedSize = await partFile.length();
    if (mergedSize != totalBytes) {
      _log.warning(
        'Merge size mismatch: expected $totalBytes, got $mergedSize',
      );
      await _historyRepo.updateRecoveryState(taskId, 'merging_failed');
      throw StateError(
        'Merge size mismatch: expected $totalBytes, got $mergedSize',
      );
    }

    // Atomic rename to final output path
    if (File(outputPath).existsSync()) {
      try {
        File(outputPath).deleteSync();
      } catch (_) {}
    }
    await partFile.rename(outputPath);

    // Clean up temp files AFTER successful rename
    _deleteTempFiles(taskId, outputPath);

    // Clear recovery state on success
    await _historyRepo.updateRecoveryState(taskId, 'completed');

    _finishTask(
      taskId,
      status: DownloadStatus.completed,
      outputPath: outputPath,
      totalBytes: totalBytes,
      downloadedBytes: totalBytes,
    );
  }

  // ── Single-stream fallback ──────────────────────────────────────────────────

  Future<void> _downloadSingleStream(
    String taskId,
    Uri uri,
    String outputPath,
  ) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    _addClient(taskId, client);

    final partPath = '$outputPath.part';

    // Check for existing .part file to resume
    int startByte = 0;
    final partFile = File(partPath);
    if (await partFile.exists()) {
      final stat = await partFile.stat();
      startByte = stat.size;
      _log.info(
        'Resuming single-stream download for $taskId from byte $startByte',
      );
    }

    try {
      final req = await client.getUrl(uri);
      req.followRedirects = true;
      req.maxRedirects = 10;

      // Add Range header for resume
      if (startByte > 0) {
        req.headers.set('Range', 'bytes=$startByte-');
      }

      final resp = await req.close();
      // Handle 206 Partial Content for resume, 200 for fresh
      if (resp.statusCode == 200 && startByte > 0) {
        // Server doesn't support range - restart from beginning
        _log.warning(
          'Server returned 200 instead of 206 for resume. Restarting.',
        );
        startByte = 0;
        if (await partFile.exists()) {
          await partFile.delete();
        }
      } else if (resp.statusCode != 200 && resp.statusCode != 206) {
        throw HttpException('HTTP ${resp.statusCode}', uri: uri);
      }

      final total = resp.contentLength > 0 ? resp.contentLength : null;
      if (total != null && startByte > 0) {
        // Total from server includes already downloaded bytes
        _updateTask(taskId, totalBytes: total);
      } else if (total != null) {
        _updateTask(taskId, totalBytes: total);
      }

      int received = startByte;
      var lastEmit = DateTime.now();
      final mode = startByte > 0 ? FileMode.append : FileMode.write;
      final sink = partFile.openWrite(mode: mode);
      try {
        await for (final chunk in resp) {
          if (!_isTaskActive(taskId)) {
            await sink.flush();
            await sink.close();
            return;
          }
          sink.add(chunk);
          received += chunk.length;

          final now = DateTime.now();
          if (now.difference(lastEmit).inMilliseconds >= 100) {
            lastEmit = now;
            _updateTaskWithSpeed(
              taskId,
              downloadedBytes: received,
              progress: total != null ? received / total : null,
              totalBytes: total,
            );
          }
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
    } finally {
      _removeClient(taskId, client);
    }

    if (!_isTaskActive(taskId)) return;

    // Verify file size if we know expected total
    final finalPartFile = File(partPath);
    if (await finalPartFile.exists()) {
      final actualSize = await finalPartFile.length();
      final task = _tasks[taskId];
      if (task != null &&
          task.totalBytes != null &&
          actualSize != task.totalBytes!) {
        _log.warning(
          'Single-stream size mismatch: expected ${task.totalBytes}, got $actualSize',
        );
        await _historyRepo.updateRecoveryState(taskId, 'merging_failed');
        _finishTask(
          taskId,
          status: DownloadStatus.failed,
          error: 'Download size mismatch after completion',
          outputPath: outputPath,
        );
        return;
      }
    }

    // Atomic rename to final output path
    if (finalPartFile.existsSync()) {
      if (File(outputPath).existsSync()) {
        try {
          File(outputPath).deleteSync();
        } catch (_) {}
      }
      await finalPartFile.rename(outputPath);
    }

    // Clear recovery state on success
    await _historyRepo.updateRecoveryState(taskId, 'completed');

    _finishTask(
      taskId,
      status: DownloadStatus.completed,
      outputPath: outputPath,
      downloadedBytes: _tasks[taskId]?.downloadedBytes,
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  bool _isTaskActive(String taskId) {
    if (_disposed) return false;
    final task = _tasks[taskId];
    return task != null &&
        task.status != DownloadStatus.cancelled &&
        task.status != DownloadStatus.completed;
  }

  Future<void> _finishTask(
    String taskId, {
    required DownloadStatus status,
    String? outputPath,
    String? error,
    int? totalBytes,
    int? downloadedBytes,
  }) async {
    if (_disposed) {
      _activeCount--;
      return;
    }
    GlobalConnectionScheduler.instance.releaseTaskSlots(taskId);
    _updateTask(
      taskId,
      status: status,
      outputPath: outputPath,
      errorMessage: error,
      totalBytes: totalBytes,
      downloadedBytes: downloadedBytes,
      completedAt: status == DownloadStatus.completed ? DateTime.now() : null,
    );
    final task = _tasks[taskId];
    if (task != null) await _persistTask(task);
    _progressHistory.remove(taskId);
    _activeCount--;
    _processQueue();
  }

  void _updateTask(
    String taskId, {
    DownloadStatus? status,
    double? progress,
    int? speedBps,
    int? etaSeconds,
    int? totalBytes,
    int? downloadedBytes,
    String? outputPath,
    String? errorMessage,
    DateTime? completedAt,
    bool clearError = false,
    String? eTag,
    String? lastModified,
    String? tempDirectory,
  }) {
    final task = _tasks[taskId];
    if (task == null) return;
    _tasks[taskId] = task.copyWith(
      status: status,
      progress: progress,
      speedBps: speedBps,
      etaSeconds: etaSeconds,
      totalBytes: totalBytes ?? task.totalBytes,
      downloadedBytes: downloadedBytes ?? task.downloadedBytes,
      outputPath: outputPath,
      errorMessage: clearError ? null : (errorMessage ?? task.errorMessage),
      completedAt: completedAt,
      eTag: eTag,
      lastModified: lastModified,
      tempDirectory: tempDirectory ?? task.tempDirectory,
    );
    _emit();
  }

  void _updateTaskWithSpeed(
    String taskId, {
    double? progress,
    int? downloadedBytes,
    int? totalBytes,
  }) {
    final task = _tasks[taskId];
    if (task == null) return;

    final now = DateTime.now();
    final history = _progressHistory.putIfAbsent(taskId, () => []);

    // Add current snapshot
    final currentDownloaded = downloadedBytes ?? task.downloadedBytes ?? 0;
    history.add(
      _ProgressSnapshot(timestamp: now, downloadedBytes: currentDownloaded),
    );

    // Keep only last 10 seconds of history
    history.removeWhere((s) => now.difference(s.timestamp).inSeconds > 10);

    // Calculate speed from history (bytes per second)
    int? speedBps;
    int? etaSeconds;

    if (history.length >= 2) {
      final oldest = history.first;
      final newest = history.last;
      final timeDiff = newest.timestamp
          .difference(oldest.timestamp)
          .inMilliseconds;
      if (timeDiff > 0) {
        final byteDiff = newest.downloadedBytes - oldest.downloadedBytes;
        speedBps = ((byteDiff / timeDiff) * 1000).round();
      }
    }

    // Calculate ETA
    if (speedBps != null &&
        speedBps > 0 &&
        totalBytes != null &&
        currentDownloaded < totalBytes) {
      final remaining = totalBytes - currentDownloaded;
      etaSeconds = (remaining / speedBps).ceil();
    }

    _updateTask(
      taskId,
      progress: progress,
      downloadedBytes: currentDownloaded,
      speedBps: speedBps,
      etaSeconds: etaSeconds,
    );
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(currentTasks);
    }
  }

  Future<void> _persistTask(DownloadTask task) async {
    try {
      await _historyRepo.upsertTask(task);
    } catch (e) {
      _log.warning('Failed to persist task ${task.id}.', e);
    }
  }

  void _addClient(String taskId, HttpClient client) {
    _clients.putIfAbsent(taskId, () => []).add(client);
  }

  void _removeClient(String taskId, HttpClient client) {
    _clients[taskId]?.remove(client);
    if (_clients[taskId]?.isEmpty ?? false) _clients.remove(taskId);
    client.close();
  }

  void _abortClients(String taskId) {
    final list = _clients.remove(taskId) ?? [];
    for (final c in list) {
      c.close(force: true);
    }
  }

  void _deleteTempFiles(String taskId, String? outputPath) {
    try {
      // Clean up new location pattern (same-volume temp dir)
      if (outputPath != null) {
        final parentDir = p.dirname(outputPath);
        final tempDir = Directory(
          p.join(parentDir, '.creatorforge_temp', taskId),
        );
        if (tempDir.existsSync()) {
          tempDir.delete(recursive: true).ignore();
        }
      }
      // Also clean up old location
      String baseTempDir;
      try {
        baseTempDir = AppConfig.instance.tempDir;
      } catch (_) {
        baseTempDir = Directory.systemTemp.path;
      }
      final oldDir = Directory(p.join(baseTempDir, taskId));
      if (oldDir.existsSync()) {
        oldDir.delete(recursive: true).ignore();
      }
    } catch (_) {}
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

class _ProgressSnapshot {
  final DateTime timestamp;
  final int downloadedBytes;

  _ProgressSnapshot({required this.timestamp, required this.downloadedBytes});
}
