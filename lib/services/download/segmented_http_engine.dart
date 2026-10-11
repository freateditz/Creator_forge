import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/config/app_config.dart';
import '../../core/logging/app_logger.dart';
import '../../core/utils/validators.dart';
import '../../models/download_task.dart';
import '../../models/media_info.dart';
import '../../repositories/download_history_repository.dart';
import 'download_engine.dart';

/// Minimum file size (bytes) required to attempt range-segmented download.
/// Smaller files download as a single stream to avoid unnecessary overhead.
const _kMinSegmentSize = 512 * 1024; // 512 KB

class SegmentedHttpEngine implements DownloadEngine {
  final DownloadHistoryRepository _historyRepo;
  final _log = AppLogger.get('SegmentedHttpEngine');
  final _uuid = const Uuid();

  int maxConcurrent;
  int segmentCount;
  String defaultOutputDir;

  final _controller = StreamController<List<DownloadTask>>.broadcast();
  final _tasks = <String, DownloadTask>{};
  final _queue = Queue<String>();

  // HttpClient handles per active task — stored so cancel() can abort them.
  final _clients = <String, List<HttpClient>>{};
  int _activeCount = 0;
  bool _disposed = false;

  // ignore: prefer_initializing_formals
  SegmentedHttpEngine({
    required DownloadHistoryRepository historyRepo,
    this.maxConcurrent = 3,
    this.segmentCount = 8,
    String? defaultOutputDir,
  }) : _historyRepo = historyRepo,
       defaultOutputDir =
           defaultOutputDir ?? AppConfig.instance.defaultDownloadsDir;

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
    final dir = outputDirectory ?? defaultOutputDir;
    await Directory(dir).create(recursive: true);

    final filename = _safeFilename(
      cachedMetadata?.title ?? validated.pathSegments.lastOrNull ?? 'download',
      validated.path,
    );

    final task = DownloadTask(
      id: id,
      url: validated.toString(),
      title: cachedMetadata?.title ?? filename,
      outputDirectory: dir,
      outputFilename: filename,
      status: DownloadStatus.queued,
      createdAt: DateTime.now(),
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
    _updateTask(taskId, status: DownloadStatus.paused);
    _activeCount--;
    _persistTask(_tasks[taskId]!).ignore();
    _processQueue();
  }

  @override
  Future<void> resume(String taskId) async {
    final task = _tasks[taskId];
    if (task == null || task.status != DownloadStatus.paused) return;
    _updateTask(taskId, status: DownloadStatus.queued, progress: 0);
    _queue.addFirst(taskId);
    _processQueue();
  }

  @override
  Future<void> cancel(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) return;
    _abortClients(taskId);
    if (task.status == DownloadStatus.queued) _queue.remove(taskId);
    _updateTask(taskId, status: DownloadStatus.cancelled);
    final updated = _tasks[taskId];
    if (updated != null) _persistTask(updated).ignore();
    if (task.status == DownloadStatus.downloading ||
        task.status == DownloadStatus.resolving) {
      _activeCount--;
      _processQueue();
    }
    _deleteTempFiles(taskId);
  }

  @override
  Future<void> retry(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) return;
    if (task.status != DownloadStatus.failed &&
        task.status != DownloadStatus.cancelled) {
      return;
    }
    _updateTask(
      taskId,
      status: DownloadStatus.queued,
      progress: 0,
      errorMessage: null,
    );
    _queue.add(taskId);
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
    }
    await _historyRepo.clearCompleted();
    _emit();
  }

  Future<void> initialize() async {
    final interrupted = await _historyRepo.getInterrupted();
    for (final row in interrupted) {
      final task = DownloadTask(
        id: row.taskId,
        url: row.url,
        title: row.title,
        outputDirectory: row.outputPath,
        status: DownloadStatus.failed,
        errorMessage: 'Interrupted — tap Retry to download again.',
        createdAt: row.createdAt,
        completedAt: row.completedAt,
      );
      _tasks[row.taskId] = task;
      await _historyRepo.updateStatus(
        row.taskId,
        'failed',
        errorMessage: 'Interrupted on previous session.',
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
    final tempDir = p.join(AppConfig.instance.tempDir, taskId);

    _updateTask(taskId, status: DownloadStatus.resolving);

    // ── HEAD request ────────────────────────────────────────────────────────
    int? contentLength;
    bool acceptsRanges = false;

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

    _updateTask(
      taskId,
      status: DownloadStatus.downloading,
      totalBytes: contentLength,
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
        await _downloadSegmented(taskId, uri, outputPath, knownLength, tempDir);
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

      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 30);
      _addClient(taskId, client);

      try {
        final req = await client.getUrl(uri);
        req.followRedirects = true;
        req.maxRedirects = 5;
        req.headers.set('Range', 'bytes=$start-$end');

        final resp = await req.close();
        if (resp.statusCode != 206 && resp.statusCode != 200) {
          throw HttpException(
            'Unexpected status ${resp.statusCode} for segment $i',
            uri: uri,
          );
        }

        final sink = File(segPath).openWrite();
        try {
          await for (final chunk in resp) {
            if (!_isTaskActive(taskId)) {
              await sink.flush();
              await sink.close();
              return;
            }
            sink.add(chunk);
            segProgress[i] += chunk.length;

            // Throttle progress updates to ~10 Hz.
            final now = DateTime.now();
            if (now.difference(lastEmit).inMilliseconds >= 100) {
              lastEmit = now;
              final done = segProgress.fold(0, (a, b) => a + b);
              _updateTask(
                taskId,
                downloadedBytes: done,
                progress: done / totalBytes,
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
    }

    await Future.wait(
      List.generate(segmentCount, downloadSegment),
      eagerError: true,
    );

    if (!_isTaskActive(taskId)) {
      _deleteTempFiles(taskId);
      _activeCount--;
      _processQueue();
      return;
    }

    // ── Merge segments ──────────────────────────────────────────────────────
    _updateTask(taskId, status: DownloadStatus.merging, progress: 1.0);
    final out = File(outputPath).openWrite();
    try {
      for (int i = 0; i < segmentCount; i++) {
        final seg = File(p.join(tempDir, 'seg_$i.tmp'));
        if (seg.existsSync()) {
          await out.addStream(seg.openRead());
        }
      }
      await out.flush();
    } finally {
      await out.close();
    }

    _deleteTempFiles(taskId);
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

    try {
      final req = await client.getUrl(uri);
      req.followRedirects = true;
      req.maxRedirects = 10;

      final resp = await req.close();
      if (resp.statusCode != 200) {
        throw HttpException('HTTP ${resp.statusCode}', uri: uri);
      }

      final total = resp.contentLength > 0 ? resp.contentLength : null;
      _updateTask(taskId, totalBytes: total);

      int received = 0;
      var lastEmit = DateTime.now();
      final sink = File(outputPath).openWrite();
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
            _updateTask(
              taskId,
              downloadedBytes: received,
              progress: total != null ? received / total : null,
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

  void _finishTask(
    String taskId, {
    required DownloadStatus status,
    String? outputPath,
    String? error,
    int? totalBytes,
    int? downloadedBytes,
  }) {
    if (_disposed) {
      _activeCount--;
      return;
    }
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
    if (task != null) _persistTask(task).ignore();
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
    );
    _emit();
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

  void _deleteTempFiles(String taskId) {
    final dir = Directory(p.join(AppConfig.instance.tempDir, taskId));
    if (dir.existsSync()) {
      dir.delete(recursive: true).ignore();
    }
  }

  static String _safeFilename(String title, String urlPath) {
    final ext = _extFromPath(urlPath);
    final safe = Validators.sanitizeFilename(title);
    if (safe.contains('.')) return safe;
    return ext.isEmpty ? safe : '$safe.$ext';
  }

  static String _extFromPath(String path) {
    final last = path.split('/').last;
    final dot = last.lastIndexOf('.');
    if (dot < 0 || dot >= last.length - 1) return '';
    final ext = last.substring(dot + 1).toLowerCase();
    return ext.length <= 5 ? ext : '';
  }
}
