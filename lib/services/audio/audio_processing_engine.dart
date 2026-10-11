import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/errors/app_exception.dart';
import '../../core/logging/app_logger.dart';
import '../../core/utils/validators.dart' show Validators;
import '../../models/audio_request.dart';
import '../../models/processing_job.dart';
import '../../repositories/processing_job_repository.dart';
import '../../services/ffmpeg/ffmpeg_service.dart';
import 'ffmpeg_args_builder.dart';
import 'ffmpeg_progress_parser.dart';

/// In-memory representation of one audio job including live progress.
class AudioJob {
  final String id;
  final String inputPath;
  final AudioRequest request;
  final ProcessingJobStatus status;
  final double progress; // [0.0, 1.0]
  final String? outputPath;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? completedAt;

  const AudioJob({
    required this.id,
    required this.inputPath,
    required this.request,
    this.status = ProcessingJobStatus.pending,
    this.progress = 0.0,
    this.outputPath,
    this.errorMessage,
    required this.createdAt,
    this.completedAt,
  });

  bool get isTerminal =>
      status == ProcessingJobStatus.completed ||
      status == ProcessingJobStatus.failed ||
      status == ProcessingJobStatus.cancelled;

  AudioJob copyWith({
    ProcessingJobStatus? status,
    double? progress,
    String? outputPath,
    String? errorMessage,
    DateTime? completedAt,
    bool clearError = false,
    bool clearOutput = false,
  }) {
    return AudioJob(
      id: id,
      inputPath: inputPath,
      request: request,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      outputPath: clearOutput ? null : (outputPath ?? this.outputPath),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

/// Manages a queue of audio processing jobs, runs up to [maxConcurrent]
/// at the same time, persists state to DB, and recovers interrupted jobs
/// on startup.
class AudioProcessingEngine {
  final ProcessingJobRepository _jobRepo;
  final FfmpegService _ffmpegService;
  final _log = AppLogger.get('AudioProcessingEngine');

  int maxConcurrent;

  final _jobs = <String, AudioJob>{};
  final _activeProcesses = <String, Process>{};
  final _cancelledIds = <String>{};

  final _jobsController = StreamController<List<AudioJob>>.broadcast();
  Stream<List<AudioJob>> get jobsStream => _jobsController.stream;

  List<AudioJob> get currentJobs =>
      _jobs.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  static const _ffmpegCandidates = [
    'ffmpeg',
    '/opt/homebrew/bin/ffmpeg',
    '/usr/local/bin/ffmpeg',
    r'C:\Program Files\CreatorForge\bin\ffmpeg.exe',
    r'C:\Program Files\ffmpeg\bin\ffmpeg.exe',
  ];

  AudioProcessingEngine({
    required this._jobRepo,
    required this._ffmpegService,
    this.maxConcurrent = 2,
  });

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    final interrupted = await _jobRepo.getInterrupted();
    for (final row in interrupted) {
      final params = _decodeParams(row.paramsJson);
      final request = AudioRequest.fromParams(params);
      final job = AudioJob(
        id: row.jobId,
        inputPath: row.inputPath,
        request: request,
        status: ProcessingJobStatus.failed,
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

  // ── Public API ──────────────────────────────────────────────────────────────

  Future<AudioJob> enqueue({
    required String inputPath,
    required AudioRequest request,
  }) async {
    final id = _generateId();
    final job = AudioJob(
      id: id,
      inputPath: inputPath,
      request: request,
      status: ProcessingJobStatus.pending,
      createdAt: DateTime.now(),
    );
    _jobs[id] = job;

    await _jobRepo.upsertJob(_toProcessingJob(job));
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
        status: ProcessingJobStatus.cancelled,
        completedAt: DateTime.now(),
      ),
    );
    await _jobRepo.updateStatus(jobId, ProcessingJobStatus.cancelled);
    _scheduleNext();
  }

  Future<void> retry(String jobId) async {
    final old = _jobs[jobId];
    if (old == null) return;
    if (old.status != ProcessingJobStatus.failed &&
        old.status != ProcessingJobStatus.cancelled) {
      return;
    }

    final fresh = AudioJob(
      id: old.id,
      inputPath: old.inputPath,
      request: old.request,
      status: ProcessingJobStatus.pending,
      progress: 0.0,
      createdAt: old.createdAt,
    );
    _jobs[jobId] = fresh;
    _cancelledIds.remove(jobId);
    await _jobRepo.upsertJob(_toProcessingJob(fresh));
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
    _jobs.removeWhere((_, j) => j.isTerminal);
    await _jobRepo.clearCompleted();
    _emit();
  }

  // ── Internal processing ─────────────────────────────────────────────────────

  void _scheduleNext() {
    final active = _activeProcesses.length;
    if (active >= maxConcurrent) return;

    final pending =
        _jobs.values
            .where((j) => j.status == ProcessingJobStatus.pending)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final toStart = pending.take(maxConcurrent - active).toList();
    for (final job in toStart) {
      _processJob(job).ignore();
    }
  }

  Future<void> _processJob(AudioJob job) async {
    final jobId = job.id;
    if (_cancelledIds.contains(jobId)) return;

    _update(jobId, job.copyWith(status: ProcessingJobStatus.processing));
    await _jobRepo.updateStatus(jobId, ProcessingJobStatus.processing);

    Directory? tempDir;
    String? tempOutput;

    try {
      // Probe the source file.
      final probe = await _ffmpegService.probeMedia(job.inputPath);
      if (!probe.hasAudio) {
        throw const MediaException('Input file contains no audio streams.');
      }

      // Resolve the FFmpeg binary.
      final ffmpegPath = await _resolveFfmpegPath();
      if (ffmpegPath == null) {
        throw const DependencyException(
          'FFmpeg is not installed or could not be found.',
          dependency: 'ffmpeg',
        );
      }

      // Build temp output path.
      tempDir = await Directory.systemTemp.createTemp('cf_audio_$jobId');
      final outputFilename = _buildOutputFilename(job);
      tempOutput = '${tempDir.path}/$outputFilename';

      // Build args.
      final args = FfmpegArgsBuilder.build(
        inputPath: job.inputPath,
        jobTempPath: tempOutput,
        request: job.request,
        probe: probe,
      );

      _log.fine('FFmpeg args: $args');

      // Start process.
      final process = await Process.start(ffmpegPath, args, runInShell: false);
      _activeProcesses[jobId] = process;

      // Parse progress from stdout (-progress pipe:1).
      final parser = FfmpegProgressParser();
      final totalSeconds = probe.durationSeconds;

      process.stdout
          .transform(const SystemEncoding().decoder)
          .transform(const LineSplitter())
          .listen((line) {
            if (_cancelledIds.contains(jobId)) return;
            final update = parser.parseLine(line);
            if (update != null && !update.isDone) {
              final frac = update.fraction(totalSeconds) ?? 0.0;
              final current = _jobs[jobId];
              if (current != null) {
                _update(jobId, current.copyWith(progress: frac));
              }
            }
          });

      // Drain stderr (log only; don't expose raw output to UI).
      process.stderr
          .transform(const SystemEncoding().decoder)
          .listen((data) => _log.fine('ffmpeg stderr: $data'));

      final exitCode = await process.exitCode;
      _activeProcesses.remove(jobId);

      if (_cancelledIds.contains(jobId)) {
        _cleanupTemp(tempDir);
        return; // cancel() already updated state
      }

      if (exitCode != 0) {
        throw ProcessingException(
          'Audio processing failed (exit $exitCode).',
          technicalDetails: 'FFmpeg exit code $exitCode',
        );
      }

      // Verify output exists and is non-empty.
      final tempFile = File(tempOutput);
      if (!tempFile.existsSync() || tempFile.statSync().size == 0) {
        throw const ProcessingException(
          'Processing appeared to succeed but no output was produced.',
        );
      }

      // Move to final destination with collision handling.
      final finalPath = await _moveToDestination(tempFile, job);

      final done = (_jobs[jobId] ?? job).copyWith(
        status: ProcessingJobStatus.completed,
        progress: 1.0,
        outputPath: finalPath,
        completedAt: DateTime.now(),
      );
      _update(jobId, done);
      await _jobRepo.updateStatus(
        jobId,
        ProcessingJobStatus.completed,
        outputPath: finalPath,
      );
    } on AppException catch (e) {
      _log.warning('Job $jobId failed: ${e.message}');
      _activeProcesses.remove(jobId);
      _cleanupTemp(tempDir);
      if (_cancelledIds.contains(jobId)) return;
      final current = _jobs[jobId] ?? job;
      _update(
        jobId,
        current.copyWith(
          status: ProcessingJobStatus.failed,
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
      _log.warning('Job $jobId unexpected error.', e);
      _activeProcesses.remove(jobId);
      _cleanupTemp(tempDir);
      if (_cancelledIds.contains(jobId)) return;
      const msg = 'An unexpected error occurred during processing.';
      final current = _jobs[jobId] ?? job;
      _update(
        jobId,
        current.copyWith(
          status: ProcessingJobStatus.failed,
          errorMessage: msg,
          completedAt: DateTime.now(),
        ),
      );
      await _jobRepo.updateStatus(
        jobId,
        ProcessingJobStatus.failed,
        errorMessage: msg,
      );
    } finally {
      _scheduleNext();
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  void _update(String jobId, AudioJob job) {
    _jobs[jobId] = job;
    _emit();
  }

  void _emit() {
    if (!_jobsController.isClosed) {
      _jobsController.add(currentJobs);
    }
  }

  String _buildOutputFilename(AudioJob job) {
    final base = Validators.sanitizeFilename(
      job.inputPath
          .split(Platform.pathSeparator)
          .last
          .replaceAll(RegExp(r'\.[^.]+$'), ''),
    );
    final ext = job.request.outputFormat.extension;
    return '$base.$ext';
  }

  Future<String> _moveToDestination(File tempFile, AudioJob job) async {
    final dir = job.request.outputDirectory;
    await Directory(dir).create(recursive: true);
    final base = _buildOutputFilename(job);
    var destPath = '$dir${Platform.pathSeparator}$base';
    var counter = 1;
    while (File(destPath).existsSync()) {
      final dotIdx = base.lastIndexOf('.');
      final name = base.substring(0, dotIdx);
      final ext = base.substring(dotIdx);
      destPath = '$dir${Platform.pathSeparator}$name ($counter)$ext';
      counter++;
    }
    await tempFile.copy(destPath);
    // Only delete the temp copy — never touch the user's source.
    await tempFile.delete();
    return destPath;
  }

  void _cleanupTemp(Directory? dir) {
    if (dir == null) return;
    try {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    } catch (e) {
      _log.fine('Could not clean up temp dir: $e');
    }
  }

  Future<String?> _resolveFfmpegPath() async {
    for (final c in _ffmpegCandidates) {
      try {
        final r = await Process.run(c, ['-version'], runInShell: false);
        if (r.exitCode == 0) return c;
      } catch (_) {}
    }
    return null;
  }

  static ProcessingJob _toProcessingJob(AudioJob job) {
    final jobType = switch (job.request.operation) {
      AudioOperation.extract => ProcessingJobType.audioExtract,
      AudioOperation.convert => ProcessingJobType.mediaConvert,
    };
    return ProcessingJob(
      id: job.id,
      jobType: jobType,
      inputPath: job.inputPath,
      outputPath: job.outputPath,
      status: job.status,
      progress: job.progress,
      errorMessage: job.errorMessage,
      params: job.request.toParams(),
      createdAt: job.createdAt,
      completedAt: job.completedAt,
    );
  }

  static Map<String, dynamic> _decodeParams(String? json) {
    if (json == null || json.isEmpty) return {};
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static String _generateId() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(36) +
      (DateTime.now().hashCode.abs() % 9999).toString().padLeft(4, '0');
}
