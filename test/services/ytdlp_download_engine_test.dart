import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:creator_forge/database/app_database.dart';
import 'package:creator_forge/models/download_task.dart';
import 'package:creator_forge/repositories/download_history_repository.dart';
import 'package:creator_forge/services/download/ytdlp_download_engine.dart';
import 'package:creator_forge/services/download/ytdlp_locator.dart';
import 'package:creator_forge/services/ffmpeg/ffmpeg_service.dart';

// ── Mocks & fakes ────────────────────────────────────────────────────────────

class MockDownloadHistoryRepository extends Mock
    implements DownloadHistoryRepository {}

class MockFfmpegService extends Mock implements FfmpegService {}

class MockYtDlpLocator extends Mock implements YtDlpLocator {}

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

/// Returns a locator whose [resolve] call never settles.
/// This prevents _startDownload from proceeding past the locator step,
/// making queue/cancel/remove tests fully deterministic without launching
/// any real process or file-system lookup.
MockYtDlpLocator _hangingLocator() {
  final loc = MockYtDlpLocator();
  // Each call returns a new Completer future that is never completed.
  when(() => loc.resolve()).thenAnswer((_) => Completer<String?>().future);
  return loc;
}

/// Returns a locator that immediately reports yt-dlp as absent.
/// Use in tests that need _startDownload to complete (and fail gracefully).
MockYtDlpLocator _absentLocator() {
  final loc = MockYtDlpLocator();
  when(() => loc.resolve()).thenAnswer((_) async => null);
  return loc;
}

YtDlpDownloadEngine _makeEngine(
  MockDownloadHistoryRepository repo,
  MockFfmpegService ffmpeg, {
  String outputDir = '/tmp/cf_test_output',
  MockYtDlpLocator? locator,
}) {
  return YtDlpDownloadEngine(
    historyRepo: repo,
    ffmpegService: ffmpeg,
    locator: locator ?? _hangingLocator(),
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
    when(() => ffmpeg.getPath()).thenAnswer((_) async => null);
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

    test('PASS formatSelector through to stored task', () async {
      final engine = _makeEngine(repo, ffmpeg);
      final task = await engine.enqueue(
        url: 'https://example.com/video',
        formatSelector: 'bestvideo+bestaudio',
      );
      expect(task.selectedFormat, 'bestvideo+bestaudio');
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

    test('preserves queued tasks when clearing completed', () async {
      final engine = _makeEngine(repo, ffmpeg);
      final queued = await engine.enqueue(url: 'https://example.com/v1');
      final cancelled = await engine.enqueue(url: 'https://example.com/v2');
      await engine.cancel(cancelled.id);
      await engine.clearCompleted();
      // Queued task must survive; only cancelled/completed ones are removed.
      expect(engine.currentTasks.any((t) => t.id == queued.id), isTrue);
      expect(engine.currentTasks.any((t) => t.id == cancelled.id), isFalse);
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

    test('remove without prior cancel removes the task', () async {
      final engine = _makeEngine(repo, ffmpeg);
      final task = await engine.enqueue(url: 'https://example.com/video');
      // remove() calls cancel() internally
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

  // ── Race-condition and lifecycle regression tests ─────────────────────────

  group('YtDlpDownloadEngine — clearCompleted', () {
    test('clearCompleted removes completed tasks from memory', () async {
      final engine = _makeEngine(repo, ffmpeg);
      final t1 = await engine.enqueue(url: 'https://example.com/v1');
      final t2 = await engine.enqueue(url: 'https://example.com/v2');
      await engine.cancel(t1.id);
      await engine.cancel(t2.id);
      await engine.clearCompleted();
      expect(engine.currentTasks, isEmpty);
      engine.dispose().ignore();
    });
  });

  group('YtDlpDownloadEngine — queue-removal race', () {
    test('enqueue + immediate remove does not crash', () async {
      // _startDownload is suspended at the locator. remove() runs before
      // the locator returns. Engine must not crash when the locator eventually
      // resolves for a task that no longer exists.
      final engine = _makeEngine(repo, ffmpeg);
      final task = await engine.enqueue(url: 'https://example.com/video');
      await engine.remove(task.id);
      expect(engine.currentTasks.where((t) => t.id == task.id), isEmpty);
      engine.dispose().ignore();
    });

    test(
      'enqueue + cancel: no crash after locator resolves with null',
      () async {
        // Use an absent locator so _startDownload completes quickly.
        // After the fix, _finishTask must not crash even though cancel already
        // ran and changed the task state.
        final engine = _makeEngine(repo, ffmpeg, locator: _absentLocator());
        final task = await engine.enqueue(url: 'https://example.com/video');
        await engine.cancel(task.id);
        // Pump the event queue to let the in-flight _startDownload settle.
        await pumpEventQueue();
        // No exception thrown; task is still in cancelled state.
        final t = engine.currentTasks.firstWhere(
          (t) => t.id == task.id,
          orElse: () => task,
        );
        expect(
          t.status == DownloadStatus.cancelled ||
              t.status == DownloadStatus.failed,
          isTrue,
        );
        engine.dispose().ignore();
      },
    );

    test('late _finishTask for a removed task is a no-op — no crash, no ghost entry', () async {
      // A controllable completer lets the test simulate a locator result
      // arriving AFTER the task has already been removed.
      final completer = Completer<String?>();
      final loc = MockYtDlpLocator();
      when(() => loc.resolve()).thenAnswer((_) => completer.future);

      final engine = _makeEngine(repo, ffmpeg, locator: loc);
      final task = await engine.enqueue(url: 'https://example.com/video');

      // Remove while _startDownload is suspended waiting for the locator.
      await engine.remove(task.id);
      expect(engine.currentTasks, isEmpty);

      // Now resolve the locator (yt-dlp not found) — simulates a late callback.
      completer.complete(null);
      await pumpEventQueue();

      // No crash, no task resurrected.
      expect(engine.currentTasks, isEmpty);
      await engine.dispose();
    });

    test('queue processing continues after one task is removed', () async {
      final engine = _makeEngine(repo, ffmpeg);
      final t1 = await engine.enqueue(url: 'https://example.com/v1');
      final t2 = await engine.enqueue(url: 'https://example.com/v2');
      await engine.remove(t1.id);
      // t2 must still be tracked.
      expect(engine.currentTasks.any((t) => t.id == t2.id), isTrue);
      engine.dispose().ignore();
    });

    test(
      'late locator completion for existing task updates status and persists',
      () async {
        // When the locator eventually returns null (yt-dlp not found),
        // _finishTask must update the task to 'failed' and persist exactly once
        // without crashing — even though other async work may have run first.
        final completer = Completer<String?>();
        final loc = MockYtDlpLocator();
        when(() => loc.resolve()).thenAnswer((_) => completer.future);

        final engine = _makeEngine(repo, ffmpeg, locator: loc);
        final task = await engine.enqueue(url: 'https://example.com/video');
        clearInteractions(repo);
        when(() => repo.upsertTask(any())).thenAnswer((_) async {});

        // Complete the locator — yt-dlp not found.
        completer.complete(null);
        await pumpEventQueue();

        // Task should be failed; repo should have been called for the persist.
        final updated = engine.currentTasks.firstWhere((t) => t.id == task.id);
        expect(updated.status, DownloadStatus.failed);
        verify(() => repo.upsertTask(any())).called(1);
        engine.dispose().ignore();
      },
    );

    test(
      'clearCompleted while tasks are mid-queue: queued tasks are untouched',
      () async {
        final engine = _makeEngine(repo, ffmpeg);
        final active = await engine.enqueue(url: 'https://example.com/active');
        final done = await engine.enqueue(url: 'https://example.com/done');
        await engine.cancel(done.id);
        await engine.clearCompleted();
        // Only the cancelled task is cleared.
        expect(engine.currentTasks.any((t) => t.id == done.id), isFalse);
        expect(engine.currentTasks.any((t) => t.id == active.id), isTrue);
        engine.dispose().ignore();
      },
    );

    test(
      'DB clearCompleted called exactly once per clearCompleted invocation',
      () async {
        final engine = _makeEngine(repo, ffmpeg);
        final task = await engine.enqueue(url: 'https://example.com/video');
        await engine.cancel(task.id);
        await engine.clearCompleted();
        verify(() => repo.clearCompleted()).called(1);
        engine.dispose().ignore();
      },
    );

    test('remove persists cancelled state to repo', () async {
      final engine = _makeEngine(repo, ffmpeg);
      final task = await engine.enqueue(url: 'https://example.com/video');
      // reset call count after enqueue's upsert
      clearInteractions(repo);
      when(() => repo.upsertTask(any())).thenAnswer((_) async {});

      await engine.remove(task.id);

      // cancel() inside remove() calls _persistTask with cancelled status.
      final captured = verify(() => repo.upsertTask(captureAny())).captured;
      expect(captured, isNotEmpty);
      final persisted = captured.last as DownloadTask;
      expect(persisted.id, task.id);
      expect(persisted.status, DownloadStatus.cancelled);
      engine.dispose().ignore();
    });

    test('_finishTask after dispose is silent — no stream emit, no persist, no crash', () async {
      final completer = Completer<String?>();
      final loc = MockYtDlpLocator();
      when(() => loc.resolve()).thenAnswer((_) => completer.future);

      final engine = _makeEngine(repo, ffmpeg, locator: loc);
      await engine.enqueue(url: 'https://example.com/video');

      await engine.dispose();
      clearInteractions(repo);
      when(() => repo.upsertTask(any())).thenAnswer((_) async {});

      // Resolve locator after dispose — _finishTask must bail out silently.
      completer.complete(null);
      await pumpEventQueue();

      verifyNever(() => repo.upsertTask(any()));
    });
  });
}
