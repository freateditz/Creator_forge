import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:creator_forge/database/app_database.dart';
import 'package:creator_forge/models/audio_format.dart';
import 'package:creator_forge/models/audio_request.dart';
import 'package:creator_forge/models/processing_job.dart';
import 'package:creator_forge/repositories/processing_job_repository.dart';
import 'package:creator_forge/services/audio/audio_processing_engine.dart';
import 'package:creator_forge/services/ffmpeg/ffmpeg_service.dart';

// ── Mocks ────────────────────────────────────────────────────────────────────

class MockProcessingJobRepository extends Mock
    implements ProcessingJobRepository {}

class MockFfmpegService extends Mock implements FfmpegService {}

class MockProcessingJobsTableData extends Mock
    implements ProcessingJobsTableData {}

class FakeAudioJob extends Fake implements AudioJob {}

class FakeProcessingJob extends Fake implements ProcessingJob {}

// ── Helpers ──────────────────────────────────────────────────────────────────

AudioRequest _request({
  AudioOperation operation = AudioOperation.extract,
  AudioOutputFormat format = AudioOutputFormat.mp3,
}) {
  return AudioRequest(
    operation: operation,
    outputFormat: format,
    outputDirectory: '/tmp/out',
  );
}

MockProcessingJobsTableData _makeInterruptedRow({
  required String jobId,
  String inputPath = '/tmp/input.mp4',
  String status = 'processing',
}) {
  final row = MockProcessingJobsTableData();
  when(() => row.jobId).thenReturn(jobId);
  when(() => row.inputPath).thenReturn(inputPath);
  when(() => row.outputPath).thenReturn(null);
  when(() => row.status).thenReturn(status);
  when(() => row.paramsJson).thenReturn(
    '{"operation":"extract","outputFormat":"mp3","outputDirectory":"/tmp/out"}',
  );
  when(() => row.errorMessage).thenReturn(null);
  when(() => row.createdAt).thenReturn(DateTime(2026, 1, 1));
  when(() => row.completedAt).thenReturn(null);
  return row;
}

/// maxConcurrent: 0 prevents _scheduleNext() from starting any processing,
/// allowing tests to verify pending/cancelled state without a live FFmpeg.
AudioProcessingEngine _makeEngine(
  MockProcessingJobRepository repo,
  MockFfmpegService ffmpeg, {
  int maxConcurrent = 0,
}) {
  return AudioProcessingEngine(
    jobRepo: repo,
    ffmpegService: ffmpeg,
    maxConcurrent: maxConcurrent,
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late MockProcessingJobRepository repo;
  late MockFfmpegService ffmpeg;

  setUpAll(() {
    registerFallbackValue(FakeAudioJob());
    registerFallbackValue(FakeProcessingJob());
    registerFallbackValue(ProcessingJobStatus.pending);
  });

  setUp(() {
    repo = MockProcessingJobRepository();
    ffmpeg = MockFfmpegService();
    when(() => repo.upsertJob(any())).thenAnswer((_) async {});
    when(
      () => repo.updateStatus(
        any(),
        any(),
        errorMessage: any(named: 'errorMessage'),
        outputPath: any(named: 'outputPath'),
      ),
    ).thenAnswer((_) async {});
    when(() => repo.clearCompleted()).thenAnswer((_) async {});
    when(() => repo.deleteByJobId(any())).thenAnswer((_) async {});
    when(() => repo.getInterrupted()).thenAnswer((_) async => []);
  });

  group('AudioProcessingEngine — enqueue', () {
    test('creates job with pending status and correct inputPath', () async {
      final engine = _makeEngine(repo, ffmpeg);
      final job = await engine.enqueue(
        inputPath: '/src/video.mp4',
        request: _request(),
      );
      expect(job.status, ProcessingJobStatus.pending);
      expect(job.inputPath, '/src/video.mp4');
      engine.dispose().ignore();
    });

    test('enqueued job appears in currentJobs', () async {
      final engine = _makeEngine(repo, ffmpeg);
      await engine.enqueue(inputPath: '/src/v.mp4', request: _request());
      expect(engine.currentJobs.length, 1);
      engine.dispose().ignore();
    });

    test('persists job to repository on enqueue', () async {
      final engine = _makeEngine(repo, ffmpeg);
      await engine.enqueue(inputPath: '/src/v.mp4', request: _request());
      verify(() => repo.upsertJob(any())).called(greaterThanOrEqualTo(1));
      engine.dispose().ignore();
    });

    test('emits updated list on enqueue', () async {
      final engine = _makeEngine(repo, ffmpeg);
      final future = engine.jobsStream.first;
      await engine.enqueue(inputPath: '/src/v.mp4', request: _request());
      final jobs = await future;
      expect(jobs.length, 1);
      engine.dispose().ignore();
    });
  });

  group('AudioProcessingEngine — cancel', () {
    test('cancelling a pending job marks it cancelled', () async {
      final engine = _makeEngine(repo, ffmpeg);
      final job = await engine.enqueue(
        inputPath: '/src/v.mp4',
        request: _request(),
      );
      await engine.cancel(job.id);
      expect(
        engine.currentJobs.firstWhere((j) => j.id == job.id).status,
        ProcessingJobStatus.cancelled,
      );
      engine.dispose().ignore();
    });

    test('cancel on nonexistent id is a no-op', () async {
      final engine = _makeEngine(repo, ffmpeg);
      await expectLater(engine.cancel('nonexistent-id'), completes);
      engine.dispose().ignore();
    });

    test('cancel calls repository.updateStatus with cancelled', () async {
      final engine = _makeEngine(repo, ffmpeg);
      final job = await engine.enqueue(
        inputPath: '/src/v.mp4',
        request: _request(),
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

  group('AudioProcessingEngine — retry', () {
    test('retry of cancelled job resets to pending with no error', () async {
      final engine = _makeEngine(repo, ffmpeg);
      final job = await engine.enqueue(
        inputPath: '/src/v.mp4',
        request: _request(),
      );
      await engine.cancel(job.id);
      await engine.retry(job.id);
      final updated = engine.currentJobs.firstWhere((j) => j.id == job.id);
      expect(updated.status, ProcessingJobStatus.pending);
      expect(updated.errorMessage, isNull);
      expect(updated.progress, 0.0);
      engine.dispose().ignore();
    });

    test('retry preserves inputPath and request', () async {
      final engine = _makeEngine(repo, ffmpeg);
      final req = _request(format: AudioOutputFormat.flac);
      final job = await engine.enqueue(inputPath: '/src/v.mp4', request: req);
      await engine.cancel(job.id);
      await engine.retry(job.id);
      final updated = engine.currentJobs.firstWhere((j) => j.id == job.id);
      expect(updated.inputPath, '/src/v.mp4');
      expect(updated.request.outputFormat, AudioOutputFormat.flac);
      engine.dispose().ignore();
    });

    test('retry of pending job is a no-op', () async {
      final engine = _makeEngine(repo, ffmpeg);
      final job = await engine.enqueue(
        inputPath: '/src/v.mp4',
        request: _request(),
      );
      await engine.retry(job.id);
      expect(
        engine.currentJobs.firstWhere((j) => j.id == job.id).status,
        ProcessingJobStatus.pending,
      );
      engine.dispose().ignore();
    });
  });

  group('AudioProcessingEngine — remove', () {
    test('removes job from currentJobs', () async {
      final engine = _makeEngine(repo, ffmpeg);
      final job = await engine.enqueue(
        inputPath: '/src/v.mp4',
        request: _request(),
      );
      await engine.cancel(job.id);
      await engine.remove(job.id);
      expect(engine.currentJobs.where((j) => j.id == job.id), isEmpty);
      engine.dispose().ignore();
    });

    test('calls repository.deleteByJobId', () async {
      final engine = _makeEngine(repo, ffmpeg);
      final job = await engine.enqueue(
        inputPath: '/src/v.mp4',
        request: _request(),
      );
      await engine.cancel(job.id);
      await engine.remove(job.id);
      verify(() => repo.deleteByJobId(job.id)).called(1);
      engine.dispose().ignore();
    });
  });

  group('AudioProcessingEngine — clearCompleted', () {
    test('removes terminal jobs from memory', () async {
      final engine = _makeEngine(repo, ffmpeg);
      final j1 = await engine.enqueue(
        inputPath: '/src/v1.mp4',
        request: _request(),
      );
      final j2 = await engine.enqueue(
        inputPath: '/src/v2.mp4',
        request: _request(),
      );
      await engine.cancel(j1.id);
      await engine.cancel(j2.id);
      await engine.clearCompleted();
      expect(engine.currentJobs, isEmpty);
      engine.dispose().ignore();
    });

    test('calls repository.clearCompleted to sync DB', () async {
      final engine = _makeEngine(repo, ffmpeg);
      final job = await engine.enqueue(
        inputPath: '/src/v.mp4',
        request: _request(),
      );
      await engine.cancel(job.id);
      await engine.clearCompleted();
      verify(() => repo.clearCompleted()).called(1);
      engine.dispose().ignore();
    });
  });

  group('AudioProcessingEngine — initialize', () {
    test('marks interrupted jobs as failed', () async {
      final row = _makeInterruptedRow(jobId: 'interrupted-1');
      when(() => repo.getInterrupted()).thenAnswer((_) async => [row]);

      final engine = _makeEngine(repo, ffmpeg);
      await engine.initialize();

      expect(engine.currentJobs.length, 1);
      expect(engine.currentJobs.first.status, ProcessingJobStatus.failed);
      expect(engine.currentJobs.first.id, 'interrupted-1');
      engine.dispose().ignore();
    });

    test('calls updateStatus(failed) for each interrupted job', () async {
      final row = _makeInterruptedRow(jobId: 'interrupted-2');
      when(() => repo.getInterrupted()).thenAnswer((_) async => [row]);

      final engine = _makeEngine(repo, ffmpeg);
      await engine.initialize();

      verify(
        () => repo.updateStatus(
          'interrupted-2',
          ProcessingJobStatus.failed,
          errorMessage: any(named: 'errorMessage'),
          outputPath: any(named: 'outputPath'),
        ),
      ).called(1);
      engine.dispose().ignore();
    });

    test('does nothing when no interrupted jobs exist', () async {
      when(() => repo.getInterrupted()).thenAnswer((_) async => []);
      final engine = _makeEngine(repo, ffmpeg);
      await engine.initialize();
      expect(engine.currentJobs, isEmpty);
      engine.dispose().ignore();
    });
  });

  group('AudioProcessingEngine — ordering', () {
    test('currentJobs are sorted newest-first', () async {
      final engine = _makeEngine(repo, ffmpeg);
      await engine.enqueue(inputPath: '/src/first.mp4', request: _request());
      await Future.delayed(const Duration(milliseconds: 5));
      await engine.enqueue(inputPath: '/src/second.mp4', request: _request());
      expect(engine.currentJobs.first.inputPath, '/src/second.mp4');
      expect(engine.currentJobs.last.inputPath, '/src/first.mp4');
      engine.dispose().ignore();
    });
  });
}
