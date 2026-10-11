import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:creator_forge/database/app_database.dart';
import 'package:creator_forge/models/processing_job.dart';
import 'package:creator_forge/models/separation_job.dart';
import 'package:creator_forge/models/separation_request.dart';
import 'package:creator_forge/repositories/processing_job_repository.dart';
import 'package:creator_forge/services/ffmpeg/ffmpeg_service.dart';
import 'package:creator_forge/services/separation/runtime_manager.dart';
import 'package:creator_forge/services/separation/separation_engine.dart';

// ── Mocks ────────────────────────────────────────────────────────────────────

class MockProcessingJobRepository extends Mock
    implements ProcessingJobRepository {}

class MockFfmpegService extends Mock implements FfmpegService {}

class MockRuntimeManager extends Mock implements RuntimeManager {}

class MockProcessingJobsTableData extends Mock
    implements ProcessingJobsTableData {}

class FakeProcessingJob extends Fake implements ProcessingJob {}

// ── Helpers ──────────────────────────────────────────────────────────────────

SeparationRequest _req() =>
    const SeparationRequest(outputDirectory: '/tmp/out');

MockProcessingJobsTableData _makeSepRow({
  required String jobId,
  String inputPath = '/tmp/input.wav',
  String status = 'processing',
}) {
  final row = MockProcessingJobsTableData();
  when(() => row.jobId).thenReturn(jobId);
  when(() => row.inputPath).thenReturn(inputPath);
  when(() => row.outputPath).thenReturn(null);
  when(() => row.status).thenReturn(status);
  when(() => row.jobType).thenReturn('vocalSeparation');
  when(() => row.paramsJson).thenReturn(
    '{"request":{"modelName":"htdemucs","mode":"voicePlusInstrumental",'
    '"device":"auto","outputDirectory":"/tmp/out"}}',
  );
  when(() => row.errorMessage).thenReturn(null);
  when(() => row.createdAt).thenReturn(DateTime(2026, 1, 1));
  when(() => row.completedAt).thenReturn(null);
  return row;
}

/// maxConcurrent:0 prevents _scheduleNext from attempting real inference.
SeparationEngine _makeEngine(
  MockProcessingJobRepository repo,
  MockFfmpegService ffmpeg,
  MockRuntimeManager runtime, {
  int maxConcurrent = 0,
}) {
  return SeparationEngine(
    jobRepo: repo,
    ffmpegService: ffmpeg,
    runtime: runtime,
    maxConcurrent: maxConcurrent,
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late MockProcessingJobRepository repo;
  late MockFfmpegService ffmpeg;
  late MockRuntimeManager runtime;

  setUpAll(() {
    registerFallbackValue(FakeProcessingJob());
    registerFallbackValue(ProcessingJobStatus.pending);
  });

  setUp(() {
    repo = MockProcessingJobRepository();
    ffmpeg = MockFfmpegService();
    runtime = MockRuntimeManager();

    when(() => repo.upsertJob(any())).thenAnswer((_) async {});
    when(
      () => repo.updateStatus(
        any(),
        any(),
        errorMessage: any(named: 'errorMessage'),
        outputPath: any(named: 'outputPath'),
      ),
    ).thenAnswer((_) async {});
    when(() => repo.deleteByJobId(any())).thenAnswer((_) async {});
    when(() => repo.getInterrupted()).thenAnswer((_) async => []);
  });

  group('SeparationEngine — enqueue', () {
    test('creates job with pending stage', () async {
      final engine = _makeEngine(repo, ffmpeg, runtime);
      final job = await engine.enqueue(
        inputPath: '/src/a.wav',
        request: _req(),
      );
      expect(job.stage, SeparationStage.pending);
      expect(job.inputPath, '/src/a.wav');
      engine.dispose().ignore();
    });

    test('enqueued job appears in currentJobs', () async {
      final engine = _makeEngine(repo, ffmpeg, runtime);
      await engine.enqueue(inputPath: '/src/a.wav', request: _req());
      expect(engine.currentJobs.length, 1);
      engine.dispose().ignore();
    });

    test('persists job to repository', () async {
      final engine = _makeEngine(repo, ffmpeg, runtime);
      await engine.enqueue(inputPath: '/src/a.wav', request: _req());
      verify(() => repo.upsertJob(any())).called(greaterThanOrEqualTo(1));
      engine.dispose().ignore();
    });

    test('emits stream update on enqueue', () async {
      final engine = _makeEngine(repo, ffmpeg, runtime);
      final future = engine.jobsStream.first;
      await engine.enqueue(inputPath: '/src/a.wav', request: _req());
      final jobs = await future;
      expect(jobs.length, 1);
      engine.dispose().ignore();
    });
  });

  group('SeparationEngine — cancel', () {
    test('cancels pending job → stage cancelled', () async {
      final engine = _makeEngine(repo, ffmpeg, runtime);
      final job = await engine.enqueue(
        inputPath: '/src/a.wav',
        request: _req(),
      );
      await engine.cancel(job.id);
      expect(
        engine.currentJobs.firstWhere((j) => j.id == job.id).stage,
        SeparationStage.cancelled,
      );
      engine.dispose().ignore();
    });

    test('cancel on nonexistent id is a no-op', () async {
      final engine = _makeEngine(repo, ffmpeg, runtime);
      await expectLater(engine.cancel('ghost-id'), completes);
      engine.dispose().ignore();
    });

    test('cancel persists cancelled status to repo', () async {
      final engine = _makeEngine(repo, ffmpeg, runtime);
      final job = await engine.enqueue(
        inputPath: '/src/a.wav',
        request: _req(),
      );
      await engine.cancel(job.id);
      verify(
        () => repo.updateStatus(
          job.id,
          ProcessingJobStatus.cancelled,
          errorMessage: any(named: 'errorMessage'),
          outputPath: any(named: 'outputPath'),
        ),
      ).called(1);
      engine.dispose().ignore();
    });
  });

  group('SeparationEngine — retry', () {
    test('retry of cancelled job resets to pending', () async {
      final engine = _makeEngine(repo, ffmpeg, runtime);
      final job = await engine.enqueue(
        inputPath: '/src/a.wav',
        request: _req(),
      );
      await engine.cancel(job.id);
      await engine.retry(job.id);
      final updated = engine.currentJobs.firstWhere((j) => j.id == job.id);
      expect(updated.stage, SeparationStage.pending);
      expect(updated.errorMessage, isNull);
      expect(updated.progress, isNull);
      engine.dispose().ignore();
    });

    test('retry preserves inputPath and request', () async {
      final engine = _makeEngine(repo, ffmpeg, runtime);
      final req = const SeparationRequest(
        outputDirectory: '/custom/out',
        device: SeparationDevice.cpu,
      );
      final job = await engine.enqueue(inputPath: '/src/a.wav', request: req);
      await engine.cancel(job.id);
      await engine.retry(job.id);
      final updated = engine.currentJobs.firstWhere((j) => j.id == job.id);
      expect(updated.inputPath, '/src/a.wav');
      expect(updated.request.device, SeparationDevice.cpu);
      engine.dispose().ignore();
    });

    test('retry of pending job is a no-op', () async {
      final engine = _makeEngine(repo, ffmpeg, runtime);
      final job = await engine.enqueue(
        inputPath: '/src/a.wav',
        request: _req(),
      );
      await engine.retry(
        job.id,
      ); // still pending — retry only works on failed/cancelled
      expect(
        engine.currentJobs.firstWhere((j) => j.id == job.id).stage,
        SeparationStage.pending,
      );
      engine.dispose().ignore();
    });
  });

  group('SeparationEngine — remove', () {
    test('removes job from currentJobs', () async {
      final engine = _makeEngine(repo, ffmpeg, runtime);
      final job = await engine.enqueue(
        inputPath: '/src/a.wav',
        request: _req(),
      );
      await engine.cancel(job.id);
      await engine.remove(job.id);
      expect(engine.currentJobs.where((j) => j.id == job.id), isEmpty);
      engine.dispose().ignore();
    });

    test('calls repository.deleteByJobId', () async {
      final engine = _makeEngine(repo, ffmpeg, runtime);
      final job = await engine.enqueue(
        inputPath: '/src/a.wav',
        request: _req(),
      );
      await engine.cancel(job.id);
      await engine.remove(job.id);
      verify(() => repo.deleteByJobId(job.id)).called(greaterThanOrEqualTo(1));
      engine.dispose().ignore();
    });
  });

  group('SeparationEngine — clearCompleted', () {
    test('removes all terminal jobs', () async {
      final engine = _makeEngine(repo, ffmpeg, runtime);
      final j1 = await engine.enqueue(inputPath: '/src/a.wav', request: _req());
      final j2 = await engine.enqueue(inputPath: '/src/b.wav', request: _req());
      await engine.cancel(j1.id);
      await engine.cancel(j2.id);
      await engine.clearCompleted();
      expect(engine.currentJobs, isEmpty);
      engine.dispose().ignore();
    });

    test('does not remove active jobs', () async {
      // maxConcurrent:0 keeps all jobs pending (not processing), but
      // only cancelled/failed/completed jobs are "terminal".
      final engine = _makeEngine(repo, ffmpeg, runtime);
      final j1 = await engine.enqueue(inputPath: '/src/a.wav', request: _req());
      await engine.cancel(j1.id);
      await engine.enqueue(
        inputPath: '/src/b.wav',
        request: _req(),
      ); // pending, not terminal
      await engine.clearCompleted();
      expect(engine.currentJobs.length, 1); // b.wav still pending
      engine.dispose().ignore();
    });
  });

  group('SeparationEngine — initialize', () {
    test('marks interrupted vocalSeparation jobs as failed', () async {
      final row = _makeSepRow(jobId: 'sep-interrupted-1');
      when(() => repo.getInterrupted()).thenAnswer((_) async => [row]);

      final engine = _makeEngine(repo, ffmpeg, runtime);
      await engine.initialize();

      expect(engine.currentJobs.length, 1);
      expect(engine.currentJobs.first.stage, SeparationStage.failed);
      expect(engine.currentJobs.first.id, 'sep-interrupted-1');
      engine.dispose().ignore();
    });

    test('ignores interrupted rows of other job types', () async {
      final audioRow = MockProcessingJobsTableData();
      when(() => audioRow.jobId).thenReturn('audio-1');
      when(() => audioRow.jobType).thenReturn('audioExtract');
      when(() => audioRow.inputPath).thenReturn('/tmp/a.mp3');
      when(() => audioRow.outputPath).thenReturn(null);
      when(() => audioRow.status).thenReturn('processing');
      when(() => audioRow.paramsJson).thenReturn('{}');
      when(() => audioRow.errorMessage).thenReturn(null);
      when(() => audioRow.createdAt).thenReturn(DateTime(2026, 1, 1));
      when(() => audioRow.completedAt).thenReturn(null);

      when(() => repo.getInterrupted()).thenAnswer((_) async => [audioRow]);

      final engine = _makeEngine(repo, ffmpeg, runtime);
      await engine.initialize();
      expect(engine.currentJobs, isEmpty);
      engine.dispose().ignore();
    });

    test('does nothing when no interrupted jobs exist', () async {
      when(() => repo.getInterrupted()).thenAnswer((_) async => []);
      final engine = _makeEngine(repo, ffmpeg, runtime);
      await engine.initialize();
      expect(engine.currentJobs, isEmpty);
      engine.dispose().ignore();
    });
  });

  group('SeparationEngine — ordering', () {
    test('currentJobs sorted newest-first', () async {
      final engine = _makeEngine(repo, ffmpeg, runtime);
      await engine.enqueue(inputPath: '/src/first.wav', request: _req());
      await Future.delayed(const Duration(milliseconds: 5));
      await engine.enqueue(inputPath: '/src/second.wav', request: _req());
      expect(engine.currentJobs.first.inputPath, '/src/second.wav');
      expect(engine.currentJobs.last.inputPath, '/src/first.wav');
      engine.dispose().ignore();
    });
  });
}
