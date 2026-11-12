import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

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
      when(() => mockRepo.deleteSegmentsByTaskId(any())).thenAnswer((_) async {});

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

      mockServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      mockServer.listen((HttpRequest request) async {
        if (request.method == 'HEAD') {
          request.response.statusCode = HttpStatus.methodNotAllowed;
          await request.response.close();
          return;
        }

        final range = request.headers.value('range');
        if (range != null) {
          final match = RegExp(r'bytes=(\d+)-(\d+)').firstMatch(range);
          if (match != null) {
            final start = int.parse(match.group(1)!);
            final end = int.parse(match.group(2)!);
            final chunk = fileData.sublist(start, end + 1);

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

        request.response.statusCode = HttpStatus.ok;
        request.response.contentLength = fileData.length;
        request.response.add(fileData);
        await request.response.close();
      });

      final url =
          'http://${mockServer.address.host}:${mockServer.port}/probe.bin';

      final task = await engine.enqueue(
        url: url,
        outputDirectory: tempOutputDir.path,
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

      await mockServer.close();

      expect(completedTask, isNotNull);
      expect(completedTask!.status, DownloadStatus.completed);
      final finalFile = File(
        p.join(tempOutputDir.path, completedTask.outputFilename!),
      );
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

      await GlobalConnectionScheduler.instance.acquireSlot('task1', 0, 'example.com');
      expect(GlobalConnectionScheduler.instance.activeConnectionCount, 1);

      await GlobalConnectionScheduler.instance.acquireSlot('task1', 1, 'example.com');
      expect(GlobalConnectionScheduler.instance.activeConnectionCount, 2);

      // Release slots for task1
      GlobalConnectionScheduler.instance.releaseTaskSlots('task1');
      expect(GlobalConnectionScheduler.instance.activeConnectionCount, 0);
    });
  });
}
