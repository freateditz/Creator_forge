import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import 'package:creator_forge/database/app_database.dart';
import 'package:creator_forge/models/download_task.dart';
import 'package:creator_forge/repositories/download_history_repository.dart';
import 'package:creator_forge/services/download/segmented_http_engine.dart';
import 'package:creator_forge/services/download/connection_scheduler.dart';

class MockDownloadHistoryRepository extends Mock
    implements DownloadHistoryRepository {}

void main() {
  group('Phase 2 & 3 Persistent Resume & Crash Recovery Tests', () {
    late MockDownloadHistoryRepository mockRepo;
    late SegmentedHttpEngine engine;
    late HttpServer mockServer;
    late Directory tempOutputDir;

    setUpAll(() async {
      registerFallbackValue(
        DownloadTask(
          id: 'fallback-id',
          url: 'https://example.com',
          title: 'fallback',
          outputDirectory: '',
          outputFilename: 'fallback',
          status: DownloadStatus.queued,
          createdAt: DateTime.now(),
        ),
      );
    });

    setUp(() async {
      mockRepo = MockDownloadHistoryRepository();
      when(() => mockRepo.upsertTask(any())).thenAnswer((_) async {});
      when(() => mockRepo.getInterrupted()).thenAnswer((_) async => []);
      when(() => mockRepo.getSegments(any())).thenAnswer((_) async => []);
      when(() => mockRepo.deleteSegmentsByTaskId(any()))
          .thenAnswer((_) async {});
      when(() => mockRepo.getTaskWithSegments(any())).thenAnswer(
        (_) async => (task: null, segments: <DownloadSegmentsTableData>[]),
      );
      when(() => mockRepo.updateRecoveryState(any(), any()))
          .thenAnswer((_) async {});
      when(() => mockRepo.setMergingStarted(any())).thenAnswer((_) async {});
      when(() => mockRepo.updateSegmentPath(any(), any(), any()))
          .thenAnswer((_) async {});
      when(() => mockRepo.verifySegments(any(), any()))
          .thenAnswer((_) async => (0, 0, false));
      when(
        () => mockRepo.updateStatus(
          any(),
          any(),
          errorMessage: any(named: 'errorMessage'),
        ),
      ).thenAnswer((_) async {});
      when(() => mockRepo.updateStatus(any(), any())).thenAnswer((_) async {});

      tempOutputDir = await Directory.systemTemp.createTemp(
        'creator_forge_resume_test_',
      );

      GlobalConnectionScheduler.instance.reset();

      engine = SegmentedHttpEngine(
        historyRepo: mockRepo,
        maxConcurrent: 2,
        segmentCount: 4,
        defaultOutputDir: tempOutputDir.path,
      );
    });

    tearDown(() async {
      await engine.dispose();
      GlobalConnectionScheduler.instance.reset();
      try {
        await tempOutputDir.delete(recursive: true);
      } catch (_) {}
    });

    test('Range GET probe fallback when HEAD is unsupported', () async {
      final fileData = List.generate(1024 * 1024, (i) => i % 256); // 1 MB

      // DIAGNOSTIC: Track server lifecycle
      final serverStart = DateTime.now();
      mockServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      print('[DIAG] HEAD-fallback test: Server bound at ${mockServer.address.host}:${mockServer.port} (took ${DateTime.now().difference(serverStart).inMilliseconds}ms)');
      mockServer.listen((HttpRequest request) async {
        print('[DIAG] HEAD-fallback test: Received ${request.method} ${request.uri.path}');
        if (request.method == 'HEAD') {
          print('[DIAG] HEAD-fallback test: Responding to HEAD with 405 Method Not Allowed');
          request.response.statusCode = HttpStatus.methodNotAllowed;
          await request.response.close();
          return;
        }

        final range = request.headers.value('range');
        print('[DIAG] HEAD-fallback test: Range header: $range');
        if (range != null) {
          final match = RegExp(r'bytes=(\d+)-(\d+)').firstMatch(range);
          if (match != null) {
            final start = int.parse(match.group(1)!);
            final end = int.parse(match.group(2)!);
            final chunk = fileData.sublist(start, end + 1);

            print('[DIAG] HEAD-fallback test: Responding to Range bytes=$start-$end with 206 Partial Content');
            request.response.statusCode = HttpStatus.partialContent;
            request.response.headers.set(
              'content-range',
              'bytes $start-$end/${fileData.length}',
            );
            request.response.headers.set('accept-ranges', 'bytes');
            request.response.contentLength = chunk.length;
            request.response.add(chunk);
            await request.response.close();
            return;
          }
        }

        print('[DIAG] HEAD-fallback test: Fallback to full 200 OK');
        request.response.statusCode = HttpStatus.ok;
        request.response.contentLength = fileData.length;
        request.response.add(fileData);
        await request.response.close();
      });

      final url =
          'http://${mockServer.address.host}:${mockServer.port}/probe.bin';

      final task = await engine.enqueue(
        url: url,
        outputDirectory: '${tempOutputDir.path}_explicit',
      );

      DownloadTask? completedTask;
      for (int i = 0; i < 60; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        final current = engine.currentTasks.firstWhere((t) => t.id == task.id);
        if (current.status == DownloadStatus.completed ||
            current.status == DownloadStatus.failed) {
          completedTask = current;
          break;
        }
      }

      print('[DIAG] HEAD-fallback test: Closing mock server');
      await mockServer.close();
      print('[DIAG] HEAD-fallback test: Server closed');

      expect(completedTask, isNotNull);
      expect(completedTask!.status, DownloadStatus.completed);
      final finalFile = File(
        p.join(completedTask.outputDirectory, completedTask.outputFilename!),
      );
      print('[DIAG] HEAD-fallback test: Final file exists=${finalFile.existsSync()}, size=${finalFile.existsSync() ? finalFile.lengthSync() : -1}');
      expect(finalFile.existsSync(), isTrue);
      expect(finalFile.lengthSync(), fileData.length);
    });

    test('Scheduler limits concurrent connections and releases slots on pause/cancel', () async {
      GlobalConnectionScheduler.instance.configure(
        maxGlobal: 2,
        maxPerHost: 2,
        maxPerDownload: 2,
      );

      expect(GlobalConnectionScheduler.instance.activeConnectionCount, 0);

      await GlobalConnectionScheduler.instance.acquireSlot(
        'task1',
        0,
        'example.com',
      );
      expect(GlobalConnectionScheduler.instance.activeConnectionCount, 1);

      await GlobalConnectionScheduler.instance.acquireSlot(
        'task1',
        1,
        'example.com',
      );
      expect(GlobalConnectionScheduler.instance.activeConnectionCount, 2);

      // Release slots for task1
      GlobalConnectionScheduler.instance.releaseTaskSlots('task1');
      expect(GlobalConnectionScheduler.instance.activeConnectionCount, 0);
    });
  });
}
