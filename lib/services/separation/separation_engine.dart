import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/errors/app_exception.dart';
import '../../core/logging/app_logger.dart';
import '../../models/processing_job.dart';
import '../../models/separation_job.dart';
import '../../models/separation_request.dart';
import '../../repositories/processing_job_repository.dart';
import '../../services/ffmpeg/ffmpeg_service.dart';
import 'demucs_progress_parser.dart';
import 'runtime_manager.dart';

/// Manages a queue of vocal/instrumental separation jobs.
///
/// At most [maxConcurrent] jobs run at once (default: 1 — inference is
/// memory-intensive).  Persists state to ProcessingJobsTable so the UI
/// survives app restarts and interrupted jobs are recovered on startup.
class SeparationEngine {
  final ProcessingJobRepository _jobRepo;
  final FfmpegService _ffmpegService;
  final RuntimeManager _runtime;
  final _log = AppLogger.get('SeparationEngine');
  final _parser = DemucsProgressParser();

  int maxConcurrent;

  final _jobs = <String, SeparationJob>{};
  final _activeProcesses = <String, Process>{};
  final _cancelledIds = <String>{};
  static const _uuid = Uuid();

  final _jobsController = StreamController<List<SeparationJob>>.broadcast();

  Stream<List<SeparationJob>> get jobsStream => _jobsController.stream;

  List<SeparationJob> get currentJobs =>
      _jobs.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  SeparationEngine({
    required this._jobRepo,
    required this._ffmpegService,
    required this._runtime,
    this.maxConcurrent = 1,
  });

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    // getInterrupted() returns all interrupted jobs across types; filter here.
    final interrupted = await _jobRepo.getInterrupted();
    final mine = interrupted
        .where((r) => r.jobType == 'vocalSeparation')
        .toList();

    for (final row in mine) {
      final params = _decodeJson(row.paramsJson);
      final requestMap = params['request'];
      final request = requestMap is Map<String, dynamic>
          ? SeparationRequest.fromJson(requestMap)
          : SeparationRequest(outputDirectory: row.outputPath ?? '');

      final job = SeparationJob(
        id: row.jobId,
        inputPath: row.inputPath,
        request: request,
        stage: SeparationStage.failed,
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

  Future<SeparationJob> enqueue({
    required String inputPath,
    required SeparationRequest request,
  }) async {
    final id = _uuid.v4();
    final job = SeparationJob(
      id: id,
      inputPath: inputPath,
      request: request,
      stage: SeparationStage.pending,
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
        stage: SeparationStage.cancelled,
        completedAt: DateTime.now(),
      ),
    );
    await _jobRepo.updateStatus(jobId, ProcessingJobStatus.cancelled);
    _scheduleNext();
  }

  Future<void> retry(String jobId) async {
    final old = _jobs[jobId];
    if (old == null) return;
    if (old.stage != SeparationStage.failed &&
        old.stage != SeparationStage.cancelled) {
      return;
    }

    final fresh = SeparationJob(
      id: old.id,
      inputPath: old.inputPath,
      request: old.request,
      stage: SeparationStage.pending,
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

  /// Removes all terminal jobs (completed / failed / cancelled) from the in-memory
  /// list and the DB — for vocalSeparation jobs only.
  Future<void> clearCompleted() async {
    final terminalIds = _jobs.entries
        .where((e) => e.value.isTerminal)
        .map((e) => e.key)
        .toList();
    for (final id in terminalIds) {
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
        _jobs.values.where((j) => j.stage == SeparationStage.pending).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    for (final job in pending.take(maxConcurrent - active)) {
      _processJob(job).ignore();
    }
  }

  Future<void> _processJob(SeparationJob job) async {
    final jobId = job.id;
    if (_cancelledIds.contains(jobId)) return;

    Directory? tempDir;

    try {
      // 1. Mark as active and probe input.
      _updateStage(jobId, SeparationStage.preparingAudio);
      await _jobRepo.updateStatus(jobId, ProcessingJobStatus.processing);

      final probe = await _ffmpegService.probeMedia(job.inputPath);
      if (!probe.hasAudio) {
        throw const MediaException('Input file contains no audio stream.');
      }

      // 2. Extract audio if source is a video container.
      String audioPath = job.inputPath;
      if (probe.hasVideo) {
        tempDir = await Directory.systemTemp.createTemp('cf_sep_$jobId');
        final tmpWav = p.join(tempDir.path, 'audio.wav');

        final ffmpegPath = await _resolveFfmpeg();
        if (ffmpegPath == null) {
          throw const DependencyException(
            'FFmpeg is required to extract audio from video files.',
            dependency: 'ffmpeg',
          );
        }

        _log.fine('Extracting audio for $jobId → $tmpWav');
        final extractResult = await Process.run(ffmpegPath, [
          '-i',
          job.inputPath,
          '-vn',
          '-acodec',
          'pcm_s16le',
          '-y',
          tmpWav,
        ], runInShell: false);
        if (extractResult.exitCode != 0) {
          throw ProcessingException(
            'Audio extraction failed.',
            technicalDetails: extractResult.stderr as String,
          );
        }
        audioPath = tmpWav;
      }

      if (_cancelledIds.contains(jobId)) return;

      // 3. Ensure output directory exists.
      await Directory(job.request.outputDirectory).create(recursive: true);

      // 4. Build and send command to worker.
      _updateStage(jobId, SeparationStage.loadingModel);

      final trackName = p.basenameWithoutExtension(job.inputPath);
      final command = <String, dynamic>{
        'action': 'separate',
        'input_path': audioPath,
        'output_dir': job.request.outputDirectory,
        'model_name': job.request.modelName,
        'device': job.request.device.name,
        'two_stems': job.request.mode == SeparationMode.voicePlusInstrumental,
        'track_name': trackName,
      };

      final process = await _runtime.startWorker(command: command);
      _activeProcesses[jobId] = process;

      // 5. Stream and parse worker stdout.
      Map<String, String>? outputStems;
      String? workerError;
      String? resolvedDevice;

      await for (final line
          in process.stdout
              .transform(const SystemEncoding().decoder)
              .transform(const LineSplitter())) {
        if (_cancelledIds.contains(jobId)) break;
        final event = _parser.parseLine(line);
        switch (event) {
          case StageEvent(:final stage, :final device):
            resolvedDevice = device ?? resolvedDevice;
            final mapped = _mapWorkerStage(stage);
            if (mapped != null) {
              _update(
                jobId,
                (_jobs[jobId] ?? job).copyWith(
                  stage: mapped,
                  resolvedDevice: resolvedDevice,
                ),
              );
            }
          case ProgressEvent(:final percent):
            final frac = (percent / 100.0).clamp(0.0, 1.0);
            final cur = _jobs[jobId];
            if (cur != null) {
              _update(
                jobId,
                cur.copyWith(stage: SeparationStage.separating, progress: frac),
              );
            }
          case CompleteEvent(:final stems):
            outputStems = stems;
          case ErrorEvent(:final message):
            workerError = message;
          default:
            break;
        }
      }

      // Drain stderr to log only.
      process.stderr
          .transform(const SystemEncoding().decoder)
          .listen((d) => _log.fine('worker stderr: $d'));

      final exitCode = await process.exitCode;
      _activeProcesses.remove(jobId);
      _cleanupTemp(tempDir);

      if (_cancelledIds.contains(jobId)) return;

      if (exitCode != 0) {
        throw ProcessingException(
          workerError ?? 'Separation failed (worker exit $exitCode).',
          technicalDetails: 'Worker exit code: $exitCode',
        );
      }

      if (outputStems == null || outputStems.isEmpty) {
        throw const ProcessingException(
          'Separation completed but no output stems were reported.',
        );
      }

      // 6. Verify output files.
      _updateStage(jobId, SeparationStage.verifyingOutput);
      for (final MapEntry(:key, :value) in outputStems.entries) {
        final f = File(value);
        if (!f.existsSync() || f.statSync().size == 0) {
          throw ProcessingException(
            "Output for stem '$key' is missing or empty.",
          );
        }
      }

      // 7. Persist completion.
      final done = (_jobs[jobId] ?? job).copyWith(
        stage: SeparationStage.completed,
        outputStems: outputStems,
        resolvedDevice: resolvedDevice,
        progress: 1.0,
        completedAt: DateTime.now(),
      );
      _update(jobId, done);
      await _jobRepo.upsertJob(_toRow(done));
    } on AppException catch (e) {
      _log.warning('Separation $jobId failed: ${e.message}');
      _activeProcesses.remove(jobId);
      _cleanupTemp(tempDir);
      if (_cancelledIds.contains(jobId)) return;
      final cur = _jobs[jobId] ?? job;
      _update(
        jobId,
        cur.copyWith(
          stage: SeparationStage.failed,
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
      _log.warning('Separation $jobId unexpected: $e');
      _activeProcesses.remove(jobId);
      _cleanupTemp(tempDir);
      if (_cancelledIds.contains(jobId)) return;
      final cur = _jobs[jobId] ?? job;
      final msg = 'Unexpected error: $e';
      _update(
        jobId,
        cur.copyWith(
          stage: SeparationStage.failed,
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

  SeparationStage? _mapWorkerStage(String stage) => switch (stage) {
    'preparing_audio' => SeparationStage.preparingAudio,
    'loading_model' => SeparationStage.loadingModel,
    'separating' => SeparationStage.separating,
    'exporting_stems' => SeparationStage.exportingStems,
    'verifying' => SeparationStage.verifyingOutput,
    _ => null,
  };

  void _updateStage(String jobId, SeparationStage stage) {
    final cur = _jobs[jobId];
    if (cur != null) _update(jobId, cur.copyWith(stage: stage));
  }

  void _update(String jobId, SeparationJob job) {
    _jobs[jobId] = job;
    _emit();
  }

  void _emit() {
    if (!_jobsController.isClosed) _jobsController.add(currentJobs);
  }

  void _cleanupTemp(Directory? dir) {
    if (dir == null) return;
    try {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    } catch (_) {}
  }

  ProcessingJob _toRow(SeparationJob job) {
    return ProcessingJob(
      id: job.id,
      jobType: ProcessingJobType.vocalSeparation,
      inputPath: job.inputPath,
      outputPath: job.outputStems?.values.firstOrNull,
      status: job.stage.dbStatus,
      params: {
        'request': job.request.toJson(),
        if (job.outputStems != null) 'stems': job.outputStems,
      },
      errorMessage: job.errorMessage,
      createdAt: job.createdAt,
      completedAt: job.completedAt,
    );
  }

  static Map<String, dynamic> _decodeJson(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static const _ffmpegCandidates = [
    'ffmpeg',
    '/opt/homebrew/bin/ffmpeg',
    '/usr/local/bin/ffmpeg',
    r'C:\Program Files\CreatorForge\bin\ffmpeg.exe',
  ];

  Future<String?> _resolveFfmpeg() async {
    for (final c in _ffmpegCandidates) {
      try {
        final r = await Process.run(c, ['-version'], runInShell: false);
        if (r.exitCode == 0) return c;
      } catch (_) {}
    }
    return null;
  }
}
