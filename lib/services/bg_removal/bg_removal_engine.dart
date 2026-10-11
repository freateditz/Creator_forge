import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/errors/app_exception.dart';
import '../../core/logging/app_logger.dart';
import '../../models/bg_removal_job.dart';
import '../../models/bg_removal_request.dart';
import '../../models/processing_job.dart';
import '../../repositories/processing_job_repository.dart';
import 'bg_removal_progress_parser.dart';
import 'image_runtime_manager.dart';

/// Manages a queue of background removal jobs.
///
/// At most [maxConcurrent] jobs run at once (default: 1 — neural inference
/// is memory-intensive).  Persists state so the UI survives app restarts and
/// interrupted jobs are recovered on startup.
class BgRemovalEngine {
  final ProcessingJobRepository _jobRepo;
  final ImageRuntimeManager _runtime;
  final _log = AppLogger.get('BgRemovalEngine');
  final _parser = BgRemovalProgressParser();

  int maxConcurrent;

  final _jobs = <String, BgRemovalJob>{};
  final _activeProcesses = <String, Process>{};
  final _cancelledIds = <String>{};
  static const _uuid = Uuid();

  final _jobsController = StreamController<List<BgRemovalJob>>.broadcast();

  Stream<List<BgRemovalJob>> get jobsStream => _jobsController.stream;

  List<BgRemovalJob> get currentJobs =>
      _jobs.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  BgRemovalEngine({
    required this._jobRepo,
    required this._runtime,
    this.maxConcurrent = 1,
  });

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    final interrupted = await _jobRepo.getInterrupted();
    final mine = interrupted
        .where((r) => r.jobType == 'backgroundRemoval')
        .toList();

    for (final row in mine) {
      final params = _decodeJson(row.paramsJson);
      final requestMap = params['request'];
      final request = requestMap is Map<String, dynamic>
          ? BgRemovalRequest.fromJson(requestMap)
          : const BgRemovalRequest(outputDirectory: '');

      final job = BgRemovalJob(
        id: row.jobId,
        inputPath: row.inputPath,
        request: request,
        stage: BgRemovalStage.failed,
        errorMessage: 'Job was interrupted. Tap retry to reprocess.',
        createdAt: row.createdAt,
      );
      _jobs[job.id] = job;
      await _jobRepo.updateStatus(
        row.jobId,
        ProcessingJobStatus.failed,
        errorMessage: job.errorMessage,
      );
    }
    _emit();
  }

  Future<void> dispose() async {
    for (final proc in _activeProcesses.values) {
      try {
        proc.kill();
      } catch (_) {}
    }
    _activeProcesses.clear();
    await _jobsController.close();
  }

  // ── Public API ────────────────────────────────────────────────────────────

  Future<BgRemovalJob> enqueue({
    required String inputPath,
    required BgRemovalRequest request,
  }) async {
    final id = _uuid.v4();

    // Ensure output filename doesn't collide.
    final outputPath = _resolveOutputPath(inputPath, request.outputDirectory);

    final job = BgRemovalJob(
      id: id,
      inputPath: inputPath,
      request: request.copyWith(outputDirectory: request.outputDirectory),
      stage: BgRemovalStage.pending,
      outputPath: outputPath,
      createdAt: DateTime.now(),
    );
    _jobs[id] = job;
    await _jobRepo.upsertJob(_toRow(job));
    _emit();
    _scheduleNext();
    return job;
  }

  Future<void> cancel(String jobId) async {
    final job = _jobs[jobId];
    if (job == null || job.isTerminal) return;
    _cancelledIds.add(jobId);
    final proc = _activeProcesses[jobId];
    if (proc != null) {
      try {
        proc.kill();
      } catch (_) {}
    }
    _update(
      jobId,
      job.copyWith(
        stage: BgRemovalStage.cancelled,
        completedAt: DateTime.now(),
      ),
    );
    await _jobRepo.updateStatus(jobId, ProcessingJobStatus.cancelled);
    _scheduleNext();
  }

  Future<void> retry(String jobId) async {
    final old = _jobs[jobId];
    if (old == null) return;
    if (old.stage != BgRemovalStage.failed &&
        old.stage != BgRemovalStage.cancelled) {
      return;
    }

    final fresh = BgRemovalJob(
      id: old.id,
      inputPath: old.inputPath,
      request: old.request,
      stage: BgRemovalStage.pending,
      outputPath: old.outputPath,
      createdAt: old.createdAt,
    );
    _jobs[jobId] = fresh;
    _cancelledIds.remove(jobId);
    await _jobRepo.upsertJob(_toRow(fresh));
    _emit();
    _scheduleNext();
  }

  Future<void> remove(String jobId) async {
    final job = _jobs[jobId];
    if (job == null) return;
    if (!job.isTerminal) await cancel(jobId);
    _jobs.remove(jobId);
    await _jobRepo.deleteByJobId(jobId);
    _emit();
  }

  Future<void> clearCompleted() async {
    final ids = _jobs.entries
        .where((e) => e.value.isTerminal)
        .map((e) => e.key)
        .toList();
    for (final id in ids) {
      _jobs.remove(id);
      await _jobRepo.deleteByJobId(id);
    }
    _emit();
  }

  // ── Internal scheduling ───────────────────────────────────────────────────

  void _scheduleNext() {
    final active = _activeProcesses.length;
    if (active >= maxConcurrent) return;

    final pending =
        _jobs.values.where((j) => j.stage == BgRemovalStage.pending).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    for (final job in pending.take(maxConcurrent - active)) {
      _processJob(job).ignore();
    }
  }

  Future<void> _processJob(BgRemovalJob job) async {
    final jobId = job.id;
    if (_cancelledIds.contains(jobId)) return;

    try {
      _updateStage(jobId, BgRemovalStage.analyzingImage);
      await _jobRepo.updateStatus(jobId, ProcessingJobStatus.processing);

      // Validate input exists.
      if (!File(job.inputPath).existsSync()) {
        throw ProcessingException(
          'Input file not found: ${p.basename(job.inputPath)}',
        );
      }

      await Directory(job.request.outputDirectory).create(recursive: true);

      if (_cancelledIds.contains(jobId)) return;

      final outputPath =
          job.outputPath ??
          _resolveOutputPath(job.inputPath, job.request.outputDirectory);

      final command = <String, dynamic>{
        'action': 'remove_background',
        'input_path': job.inputPath,
        'output_path': outputPath,
        'model_name': job.request.model.id,
        'alpha_matting': job.request.alphaMatting,
        'alpha_matting_fg_threshold': job.request.alphaMattingFgThreshold,
        'alpha_matting_bg_threshold': job.request.alphaMattingBgThreshold,
        'alpha_matting_erode_size': job.request.alphaMattingErodeSize,
        'post_process_mask': job.request.postProcessMask,
      };

      final process = await _runtime.startWorker(command: command);
      _activeProcesses[jobId] = process;

      BgCompleteEvent? completeEvent;
      String? workerError;

      await for (final line
          in process.stdout
              .transform(const SystemEncoding().decoder)
              .transform(const LineSplitter())) {
        if (_cancelledIds.contains(jobId)) break;
        final event = _parser.parseLine(line);
        switch (event) {
          case BgStageEvent(:final stage):
            final mapped = _mapWorkerStage(stage);
            if (mapped != null) {
              _updateStage(jobId, mapped);
            }
          case BgCompleteEvent():
            completeEvent = event;
          case BgErrorEvent(:final message):
            workerError = message;
          default:
            break;
        }
      }

      process.stderr
          .transform(const SystemEncoding().decoder)
          .listen((d) => _log.fine('worker stderr: $d'));

      final exitCode = await process.exitCode;
      _activeProcesses.remove(jobId);

      if (_cancelledIds.contains(jobId)) return;

      if (exitCode != 0) {
        throw ProcessingException(
          workerError ?? 'Background removal failed (worker exit $exitCode).',
          technicalDetails: 'Worker exit code: $exitCode',
        );
      }

      if (completeEvent == null || completeEvent.outputPath == null) {
        throw const ProcessingException(
          'Removal completed but no output path was reported.',
        );
      }

      if (!completeEvent.hasAlpha) {
        throw const ProcessingException(
          'Output PNG does not contain an alpha channel.',
        );
      }

      // Verify output file exists and is non-empty.
      _updateStage(jobId, BgRemovalStage.verifyingOutput);
      final outFile = File(completeEvent.outputPath!);
      if (!outFile.existsSync() || outFile.statSync().size == 0) {
        throw const ProcessingException('Output PNG is missing or empty.');
      }

      final done = (_jobs[jobId] ?? job).copyWith(
        stage: BgRemovalStage.completed,
        outputPath: completeEvent.outputPath,
        outputWidth: completeEvent.width,
        outputHeight: completeEvent.height,
        outputFileSize: completeEvent.fileSize,
        completedAt: DateTime.now(),
      );
      _update(jobId, done);
      await _jobRepo.upsertJob(_toRow(done));
    } on AppException catch (e) {
      _log.warning('BG removal $jobId failed: ${e.message}');
      _activeProcesses.remove(jobId);
      if (_cancelledIds.contains(jobId)) return;
      final cur = _jobs[jobId] ?? job;
      _update(
        jobId,
        cur.copyWith(
          stage: BgRemovalStage.failed,
          errorMessage: e.message,
          completedAt: DateTime.now(),
        ),
      );
      await _jobRepo.updateStatus(
        jobId,
        ProcessingJobStatus.failed,
        errorMessage: e.message,
      );
    } catch (e) {
      _log.warning('BG removal $jobId unexpected: $e');
      _activeProcesses.remove(jobId);
      if (_cancelledIds.contains(jobId)) return;
      final cur = _jobs[jobId] ?? job;
      final msg = 'Unexpected error: $e';
      _update(
        jobId,
        cur.copyWith(
          stage: BgRemovalStage.failed,
          errorMessage: msg,
          completedAt: DateTime.now(),
        ),
      );
      await _jobRepo.updateStatus(
        jobId,
        ProcessingJobStatus.failed,
        errorMessage: msg,
      );
    }
    _scheduleNext();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  BgRemovalStage? _mapWorkerStage(String stage) => switch (stage) {
    'analyzing_image' => BgRemovalStage.analyzingImage,
    'loading_model' => BgRemovalStage.loadingModel,
    'generating_mask' => BgRemovalStage.generatingMask,
    'refining_edges' => BgRemovalStage.refiningEdges,
    'exporting' => BgRemovalStage.exporting,
    'verifying' => BgRemovalStage.verifyingOutput,
    _ => null,
  };

  void _updateStage(String jobId, BgRemovalStage stage) {
    final cur = _jobs[jobId];
    if (cur != null) _update(jobId, cur.copyWith(stage: stage));
  }

  void _update(String jobId, BgRemovalJob job) {
    _jobs[jobId] = job;
    _emit();
  }

  void _emit() {
    if (!_jobsController.isClosed) _jobsController.add(currentJobs);
  }

  ProcessingJob _toRow(BgRemovalJob job) => ProcessingJob(
    id: job.id,
    jobType: ProcessingJobType.backgroundRemoval,
    inputPath: job.inputPath,
    outputPath: job.outputPath,
    status: job.stage.dbStatus,
    params: {
      'request': job.request.toJson(),
      if (job.outputWidth != null) 'outputWidth': job.outputWidth,
      if (job.outputHeight != null) 'outputHeight': job.outputHeight,
    },
    errorMessage: job.errorMessage,
    createdAt: job.createdAt,
    completedAt: job.completedAt,
  );

  // Exposed for testing only.
  // ignore: library_private_types_in_public_api
  static String resolveOutputPathForTest(String inputPath, String outputDir) =>
      _resolveOutputPath(inputPath, outputDir);

  /// Computes a non-colliding output path for the given input image.
  static String _resolveOutputPath(String inputPath, String outputDir) {
    final stem = p.basenameWithoutExtension(inputPath);
    final baseName = '${stem}_nobg.png';
    var candidate = p.join(outputDir, baseName);
    var counter = 1;
    while (File(candidate).existsSync()) {
      candidate = p.join(outputDir, '${stem}_nobg_$counter.png');
      counter++;
    }
    return candidate;
  }

  static Map<String, dynamic> _decodeJson(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}
