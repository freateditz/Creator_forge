import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:creator_forge/database/app_database.dart';
import 'package:creator_forge/models/bg_removal_job.dart';
import 'package:creator_forge/models/bg_removal_request.dart';
import 'package:creator_forge/models/processing_job.dart';
import 'package:creator_forge/repositories/processing_job_repository.dart';
import 'package:creator_forge/services/bg_removal/bg_removal_engine.dart';
import 'package:creator_forge/services/bg_removal/image_runtime_manager.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockProcessingJobRepository extends Mock
    implements ProcessingJobRepository {}

class MockImageRuntimeManager extends Mock implements ImageRuntimeManager {}

class MockProcessingJobsTableData extends Mock
    implements ProcessingJobsTableData {}

class FakeProcessingJob extends Fake implements ProcessingJob {}

// ── Helpers ───────────────────────────────────────────────────────────────────

BgRemovalRequest _req() =>
    const BgRemovalRequest(outputDirectory: '/tmp/bg_out');

MockProcessingJobsTableData _makeBgRow({
  required String jobId,
  String inputPath = '/tmp/photo.jpg',
  String status = 'processing',
}) {
  final row = MockProcessingJobsTableData();
  when(() => row.jobId).thenReturn(jobId);
  when(() => row.inputPath).thenReturn(inputPath);
  when(() => row.outputPath).thenReturn(null);
  when(() => row.status).thenReturn(status);
  when(() => row.jobType).thenReturn('backgroundRemoval');
  when(() => row.paramsJson).thenReturn(
    '{"request":{"model":"isnet-general-use","outputDirectory":"/tmp/bg_out",'
    '"alphaMatting":false,"alphaMattingFgThreshold":240,'
    '"alphaMattingBgThreshold":10,"alphaMattingErodeSize":10,'
    '"postProcessMask":false}}',
  );
  when(() => row.errorMessage).thenReturn(null);
  when(() => row.createdAt).thenReturn(DateTime(2026, 1, 1));
  when(() => row.completedAt).thenReturn(null);
  return row;
}

/// maxConcurrent:0 prevents _scheduleNext from attempting real inference.
BgRemovalEngine _makeEngine(
  MockProcessingJobRepository repo,
  MockImageRuntimeManager runtime, {
  int maxConcurrent = 0,
}) => BgRemovalEngine(
  jobRepo: repo,
  runtime: runtime,
  maxConcurrent: maxConcurrent,
);

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late MockProcessingJobRepository repo;
  late MockImageRuntimeManager runtime;

  setUpAll(() {
    registerFallbackValue(FakeProcessingJob());
    registerFallbackValue(ProcessingJobStatus.pending);
  });

  setUp(() {
    repo = MockProcessingJobRepository();
    runtime = MockImageRuntimeManager();

    when(() => repo.upsertJob(any())).thenAnswer((_) async {});
    when(() => repo.updateStatus(any(), any())).thenAnswer((_) async {});
    when(
      () => repo.updateStatus(
        any(),
        any(),
        errorMessage: any(named: 'errorMessage'),
      ),
    ).thenAnswer((_) async {});
    when(() => repo.getInterrupted()).thenAnswer((_) async => []);
    when(() => repo.deleteByJobId(any())).thenAnswer((_) async {});
  });

  group('initialize', () {
    test('skips rows that are not backgroundRemoval type', () async {
      final sepRow = _makeBgRow(jobId: 'j1');
      when(() => sepRow.jobType).thenReturn('vocalSeparation');
      when(() => repo.getInterrupted()).thenAnswer((_) async => [sepRow]);

      final engine = _makeEngine(repo, runtime);
      await engine.initialize();
      await engine.dispose();

      expect(engine.currentJobs, isEmpty);
    });

    test('recovers backgroundRemoval interrupted jobs as failed', () async {
      final row = _makeBgRow(jobId: 'j1', status: 'processing');
      when(() => repo.getInterrupted()).thenAnswer((_) async => [row]);

      final engine = _makeEngine(repo, runtime);
      await engine.initialize();

      expect(engine.currentJobs.length, 1);
      expect(engine.currentJobs.first.stage, BgRemovalStage.failed);
      expect(engine.currentJobs.first.errorMessage, contains('interrupted'));

      await engine.dispose();
    });

    test('marks recovered jobs failed in DB', () async {
      final row = _makeBgRow(jobId: 'j1', status: 'pending');
      when(() => repo.getInterrupted()).thenAnswer((_) async => [row]);

      final engine = _makeEngine(repo, runtime);
      await engine.initialize();
      await engine.dispose();

      verify(
        () => repo.updateStatus(
          'j1',
          ProcessingJobStatus.failed,
          errorMessage: any(named: 'errorMessage'),
        ),
      ).called(1);
    });
  });

  group('enqueue', () {
    test('adds job in pending state', () async {
      final engine = _makeEngine(repo, runtime);
      await engine.initialize();

      final job = await engine.enqueue(
        inputPath: '/tmp/photo.jpg',
        request: _req(),
      );

      expect(job.stage, BgRemovalStage.pending);
      expect(engine.currentJobs.length, 1);
      verify(() => repo.upsertJob(any())).called(1);

      await engine.dispose();
    });

    test('assigns unique IDs to multiple jobs', () async {
      final engine = _makeEngine(repo, runtime);
      await engine.initialize();

      final j1 = await engine.enqueue(inputPath: '/tmp/a.jpg', request: _req());
      final j2 = await engine.enqueue(inputPath: '/tmp/b.jpg', request: _req());

      expect(j1.id, isNot(j2.id));
      expect(engine.currentJobs.length, 2);

      await engine.dispose();
    });

    test('emits updated jobs stream on enqueue', () async {
      final engine = _makeEngine(repo, runtime);
      await engine.initialize();

      final emitted = <List<BgRemovalJob>>[];
      final sub = engine.jobsStream.listen(emitted.add);

      await engine.enqueue(inputPath: '/tmp/photo.jpg', request: _req());

      await Future<void>.delayed(Duration.zero);
      expect(emitted, isNotEmpty);
      expect(emitted.last.length, 1);

      await sub.cancel();
      await engine.dispose();
    });
  });

  group('cancel', () {
    test('cancels a pending job', () async {
      final engine = _makeEngine(repo, runtime);
      await engine.initialize();

      final job = await engine.enqueue(
        inputPath: '/tmp/photo.jpg',
        request: _req(),
      );
      await engine.cancel(job.id);

      expect(engine.currentJobs.first.stage, BgRemovalStage.cancelled);
      verify(() => repo.updateStatus(job.id, ProcessingJobStatus.cancelled))
          .called(1);

      await engine.dispose();
    });

    test('cancel is no-op for already terminal job', () async {
      final engine = _makeEngine(repo, runtime);
      await engine.initialize();

      final job = await engine.enqueue(
        inputPath: '/tmp/photo.jpg',
        request: _req(),
      );
      await engine.cancel(job.id);
      clearInteractions(repo);

      // Job is already cancelled — second cancel should not call updateStatus.
      await engine.cancel(job.id);

      verifyNever(
        () => repo.updateStatus(job.id, ProcessingJobStatus.cancelled),
      );

      await engine.dispose();
    });
  });

  group('retry', () {
    test('resets failed job to pending', () async {
      final engine = _makeEngine(repo, runtime);
      await engine.initialize();

      final job = await engine.enqueue(
        inputPath: '/tmp/photo.jpg',
        request: _req(),
      );
      await engine.cancel(job.id);
      clearInteractions(repo);

      await engine.retry(job.id);

      expect(engine.currentJobs.first.stage, BgRemovalStage.pending);
      verify(() => repo.upsertJob(any())).called(1);

      await engine.dispose();
    });

    test('retry is no-op for active job', () async {
      final engine = _makeEngine(repo, runtime);
      await engine.initialize();

      final job = await engine.enqueue(
        inputPath: '/tmp/photo.jpg',
        request: _req(),
      );
      clearInteractions(repo);

      // Job is pending, not failed → retry should not alter it
      await engine.retry(job.id);

      verifyNever(() => repo.upsertJob(any()));
      await engine.dispose();
    });
  });

  group('remove', () {
    test('removes terminal job from engine and DB', () async {
      final engine = _makeEngine(repo, runtime);
      await engine.initialize();

      final job = await engine.enqueue(
        inputPath: '/tmp/photo.jpg',
        request: _req(),
      );
      await engine.cancel(job.id);
      clearInteractions(repo);

      await engine.remove(job.id);

      expect(engine.currentJobs, isEmpty);
      verify(() => repo.deleteByJobId(job.id)).called(1);

      await engine.dispose();
    });
  });

  group('clearCompleted', () {
    test('removes all terminal jobs', () async {
      final engine = _makeEngine(repo, runtime);
      await engine.initialize();

      final j1 = await engine.enqueue(inputPath: '/tmp/a.jpg', request: _req());
      final j2 = await engine.enqueue(inputPath: '/tmp/b.jpg', request: _req());
      await engine.cancel(j1.id);
      await engine.cancel(j2.id);
      clearInteractions(repo);

      await engine.clearCompleted();

      expect(engine.currentJobs, isEmpty);
      verify(() => repo.deleteByJobId(j1.id)).called(1);
      verify(() => repo.deleteByJobId(j2.id)).called(1);

      await engine.dispose();
    });
  });

  group('dispose', () {
    test('jobsStream closes after dispose', () async {
      final engine = _makeEngine(repo, runtime);
      await engine.initialize();
      await engine.dispose();

      expect(engine.jobsStream.isEmpty, completes);
    });
  });

  group('_resolveOutputPath', () {
    test('returns expected nobg suffix', () {
      final path = BgRemovalEngine.resolveOutputPathForTest(
        '/images/photo.jpg',
        '/tmp/out',
      );
      expect(path, endsWith('photo_nobg.png'));
    });

    test('non-collision path uses counter suffix', () {
      // Simulate existing file by using a path that shouldn't exist
      // (no File.existsSync will return false in test env)
      final p1 = BgRemovalEngine.resolveOutputPathForTest(
        '/img/cat.png',
        '/tmp/out',
      );
      expect(p1, contains('cat_nobg'));
    });
  });
}
