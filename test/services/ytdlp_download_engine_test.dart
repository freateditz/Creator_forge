import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:creator_forge/database/app_database.dart';
import 'package:creator_forge/models/download_task.dart';
import 'package:creator_forge/repositories/download_history_repository.dart';
import 'package:creator_forge/services/download/ytdlp_download_engine.dart';
import 'package:creator_forge/services/ffmpeg/ffmpeg_service.dart';

// ── Mocks & fakes ────────────────────────────────────────────────────────────

class MockDownloadHistoryRepository extends Mock
    implements DownloadHistoryRepository {}

class MockFfmpegService extends Mock implements FfmpegService {}

class MockDownloadHistoryTableData extends Mock
    implements DownloadHistoryTableData {}

class FakeDownloadTask extends Fake implements DownloadTask {}

// ── Helpers ──────────────────────────────────────────────────────────────────

MockDownloadHistoryTableData _makeRow({
  required String taskId,
  required String url,
  String? title,
  String? thumbnailUrl,
  String? channelName,
  String? outputPath,
  String status = 'downloading',
}) {
  final row = MockDownloadHistoryTableData();
  when(() => row.taskId).thenReturn(taskId);
  when(() => row.url).thenReturn(url);
  when(() => row.title).thenReturn(title ?? 'Test Video');
  when(() => row.thumbnailUrl).thenReturn(thumbnailUrl);
  when(() => row.channelName).thenReturn(channelName);
  when(() => row.outputPath).thenReturn(outputPath ?? '/tmp/downloads');
  when(() => row.status).thenReturn(status);
  when(() => row.createdAt).thenReturn(DateTime(2026, 1, 1));
  when(() => row.completedAt).thenReturn(null);
  return row;
}

YtDlpDownloadEngine _makeEngine(
  MockDownloadHistoryRepository repo,
  MockFfmpegService ffmpeg, {
  String outputDir = '/tmp/cf_test_output',
}) {
  return YtDlpDownloadEngine(
    historyRepo: repo,
    ffmpegService: ffmpeg,
    defaultOutputDir: outputDir,
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late MockDownloadHistoryRepository repo;
  late MockFfmpegService ffmpeg;

  setUpAll(() {
    registerFallbackValue(FakeDownloadTask());
    registerFallbackValue(DownloadStatus.queued);
  });

  setUp(() {
    repo = MockDownloadHistoryRepository();
    ffmpeg = MockFfmpegService();
    when(() => repo.upsertTask(any())).thenAnswer((_) async {});
    when(() => repo.updateStatus(any(), any())).thenAnswer((_) async {});
    when(
      () => repo.updateStatus(
        any(),
        any(),
        errorMessage: any(named: 'errorMessage'),
      ),
    ).thenAnswer((_) async {});
    when(() => repo.clearCompleted()).thenAnswer((_) async {});
    when(() => repo.getInterrupted()).thenAnswer((_) async => []);
  });

  group('YtDlpDownloadEngine — enqueue', () {
    test('creates task with queued status and correct url', () async {
      final engine = _makeEngine(repo, ffmpeg);
      final task = await engine.enqueue(
        url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      );
      expect(task.status, DownloadStatus.queued);
      expect(task.url, 'https://www.youtube.com/watch?v=dQw4w9WgXcQ');
      expect(task.outputDirectory, '/tmp/cf_test_output');
      engine.dispose().ignore();
    });

    test('persists task to repo on enqueue', () async {
      final engine = _makeEngine(repo, ffmpeg);
      await engine.enqueue(url: 'https://example.com/video');
      verify(() => repo.upsertTask(any())).called(greaterThanOrEqualTo(1));
      engine.dispose().ignore();
    });

    test('enqueued task appears in currentTasks', () async {
      final engine = _makeEngine(repo, ffmpeg);
      await engine.enqueue(url: 'https://example.com/video');
      expect(engine.currentTasks.length, 1);
      engine.dispose().ignore();
    });

    test('emits updated list on enqueue', () async {
      final engine = _makeEngine(repo, ffmpeg);
      final future = engine.tasksStream.first;
      await engine.enqueue(url: 'https://example.com/video');
      final tasks = await future;
      expect(tasks.length, 1);
      engine.dispose().ignore();
    });
  });

  group('YtDlpDownloadEngine — cancel', () {
    test('cancelling a queued task marks it cancelled', () async {
      final engine = _makeEngine(repo, ffmpeg);
      final task = await engine.enqueue(url: 'https://example.com/video');
      await engine.cancel(task.id);
      expect(
        engine.currentTasks.firstWhere((t) => t.id == task.id).status,
        DownloadStatus.cancelled,
      );
      engine.dispose().ignore();
    });

    test('cancel on nonexistent id is a no-op', () async {
      final engine = _makeEngine(repo, ffmpeg);
      await expectLater(engine.cancel('nonexistent-id'), completes);
      engine.dispose().ignore();
    });
  });

  group('YtDlpDownloadEngine — retry', () {
    test('retry of failed task resets to queued with no error', () async {
      final engine = _makeEngine(repo, ffmpeg);
      final task = await engine.enqueue(url: 'https://example.com/video');
      // Manually put it in failed state by cancelling then using internal state
      await engine.cancel(task.id);
      await engine.retry(task.id);
      final updated = engine.currentTasks.firstWhere((t) => t.id == task.id);
      expect(updated.status, DownloadStatus.queued);
      expect(updated.errorMessage, isNull);
      expect(updated.speedBps, isNull);
      expect(updated.etaSeconds, isNull);
      engine.dispose().ignore();
    });

    test('retry of failed task preserves url, title, and type', () async {
      final engine = _makeEngine(repo, ffmpeg);
      final task = await engine.enqueue(
        url: 'https://example.com/video',
        downloadType: DownloadType.audioOnly,
      );
      await engine.cancel(task.id);
      await engine.retry(task.id);
      final updated = engine.currentTasks.firstWhere((t) => t.id == task.id);
      expect(updated.url, task.url);
      expect(updated.downloadType, DownloadType.audioOnly);
      engine.dispose().ignore();
    });

    test('retry does nothing if task is not failed/cancelled', () async {
      final engine = _makeEngine(repo, ffmpeg);
      final task = await engine.enqueue(url: 'https://example.com/video');
      // Task is queued — retry should be a no-op
      await engine.retry(task.id);
      expect(
        engine.currentTasks.firstWhere((t) => t.id == task.id).status,
        DownloadStatus.queued,
      );
      engine.dispose().ignore();
    });
  });

  group('YtDlpDownloadEngine — clearCompleted', () {
    test('removes completed tasks from memory', () async {
      final engine = _makeEngine(repo, ffmpeg);
      final t1 = await engine.enqueue(url: 'https://example.com/v1');
      final t2 = await engine.enqueue(url: 'https://example.com/v2');
      // Cancel both to put them in a terminal state
      await engine.cancel(t1.id);
      await engine.cancel(t2.id);
      await engine.clearCompleted();
      expect(engine.currentTasks, isEmpty);
      engine.dispose().ignore();
    });

    test('calls repository.clearCompleted to sync DB', () async {
      final engine = _makeEngine(repo, ffmpeg);
      final task = await engine.enqueue(url: 'https://example.com/video');
      await engine.cancel(task.id);
      await engine.clearCompleted();
      verify(() => repo.clearCompleted()).called(1);
      engine.dispose().ignore();
    });
  });

  group('YtDlpDownloadEngine — remove', () {
    test('removes task from currentTasks entirely', () async {
      final engine = _makeEngine(repo, ffmpeg);
      final task = await engine.enqueue(url: 'https://example.com/video');
      await engine.cancel(task.id);
      await engine.remove(task.id);
      expect(engine.currentTasks.where((t) => t.id == task.id), isEmpty);
      engine.dispose().ignore();
    });
  });

  group('YtDlpDownloadEngine — initialize', () {
    test('marks interrupted tasks as failed', () async {
      final row = _makeRow(
        taskId: 'interrupted-id',
        url: 'https://example.com/video',
        status: 'downloading',
      );
      when(() => repo.getInterrupted()).thenAnswer((_) async => [row]);
      when(
        () => repo.updateStatus(
          any(),
          any(),
          errorMessage: any(named: 'errorMessage'),
        ),
      ).thenAnswer((_) async {});

      final engine = _makeEngine(repo, ffmpeg);
      await engine.initialize();

      expect(engine.currentTasks.length, 1);
      expect(engine.currentTasks.first.status, DownloadStatus.failed);
      expect(engine.currentTasks.first.id, 'interrupted-id');
      engine.dispose().ignore();
    });

    test('calls updateStatus(failed) for each interrupted task', () async {
      final row = _makeRow(
        taskId: 'interrupted-id',
        url: 'https://example.com/video',
        status: 'downloading',
      );
      when(() => repo.getInterrupted()).thenAnswer((_) async => [row]);
      when(
        () => repo.updateStatus(
          any(),
          any(),
          errorMessage: any(named: 'errorMessage'),
        ),
      ).thenAnswer((_) async {});

      final engine = _makeEngine(repo, ffmpeg);
      await engine.initialize();

      verify(
        () => repo.updateStatus(
          'interrupted-id',
          'failed',
          errorMessage: any(named: 'errorMessage'),
        ),
      ).called(1);
      engine.dispose().ignore();
    });

    test('does nothing when no interrupted tasks exist', () async {
      when(() => repo.getInterrupted()).thenAnswer((_) async => []);
      final engine = _makeEngine(repo, ffmpeg);
      await engine.initialize();
      expect(engine.currentTasks, isEmpty);
      engine.dispose().ignore();
    });
  });

  group('YtDlpDownloadEngine — tasksStream ordering', () {
    test('currentTasks are sorted newest-first', () async {
      final engine = _makeEngine(repo, ffmpeg);
      await engine.enqueue(url: 'https://example.com/first');
      await Future.delayed(const Duration(milliseconds: 5));
      await engine.enqueue(url: 'https://example.com/second');
      final tasks = engine.currentTasks;
      expect(tasks.first.url, 'https://example.com/second');
      expect(tasks.last.url, 'https://example.com/first');
      engine.dispose().ignore();
    });
  });
}
