import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import 'package:creator_forge/database/app_database.dart';
import 'package:creator_forge/models/download_task.dart';
import 'package:creator_forge/repositories/download_history_repository.dart';
import 'package:creator_forge/services/download/segmented_http_engine.dart';

class MockDownloadHistoryRepository extends Mock
    implements DownloadHistoryRepository {}

void main() {
  group('SegmentedHttpEngine Tests', () {
    late MockDownloadHistoryRepository mockRepo;
    late SegmentedHttpEngine engine;
    late HttpServer mockServer;
    late Directory tempOutputDir;
    late Directory tempAppDir;

    setUpAll(() async {
      registerFallbackValue(
        DownloadHistoryTableCompanion(taskId: const drift.Value('fallback-id')),
      );
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

      // Set up all mock methods to return proper Future<void>
      when(() => mockRepo.upsertTask(any()))
          .thenAnswer((_) => Future<void>.value());
      when(() => mockRepo.getInterrupted()).thenAnswer((_) async => []);
      when(() => mockRepo.getTaskWithSegments(any())).thenAnswer(
        (_) async => (task: null, segments: <DownloadSegmentsTableData>[]),
      );

      when(() => mockRepo.updateRecoveryState(any(), any()))
          .thenAnswer((_) => Future<void>.value());
      when(() => mockRepo.setMergingStarted(any()))
          .thenAnswer((_) => Future<void>.value());
      when(() => mockRepo.updateSegmentPath(any(), any(), any()))
          .thenAnswer((_) => Future<void>.value());
      when(() => mockRepo.verifySegments(any(), any()))
          .thenAnswer((_) => Future.value((0, 0, false)));

      when(
        () => mockRepo.updateStatus(
          any(),
          any(),
          errorMessage: any(named: 'errorMessage'),
        ),
      ).thenAnswer((_) => Future<void>.value());
      when(() => mockRepo.updateStatus(any(), any()))
          .thenAnswer((_) => Future<void>.value());

      when(() => mockRepo.deleteSegmentsByTaskId(any()))
          .thenAnswer((_) => Future<void>.value());
      when(() => mockRepo.deleteByTaskId(any()))
          .thenAnswer((_) => Future<void>.value());
      when(() => mockRepo.clearCompleted())
          .thenAnswer((_) => Future<void>.value());
      when(() => mockRepo.getSegments(any()))
          .thenAnswer((_) async => <DownloadSegmentsTableData>[]);
      when(
        () => mockRepo.upsertSegment(
          taskId: any(named: 'taskId'),
          index: any(named: 'index'),
          start: any(named: 'start'),
          end: any(named: 'end'),
          downloaded: any(named: 'downloaded'),
          status: any(named: 'status'),
          segmentPath: any(named: 'segmentPath'),
        ),
      ).thenAnswer((_) => Future<void>.value());

      tempAppDir = await Directory.systemTemp.createTemp(
        'creator_forge_test_app_',
      );
      tempOutputDir = await Directory.systemTemp.createTemp(
        'creator_forge_test_out_',
      );

      engine = SegmentedHttpEngine(
        historyRepo: mockRepo,
        maxConcurrent: 2,
        segmentCount: 4,
        defaultOutputDir: tempOutputDir.path,
      );
    });

    tearDown(() async {
      await engine.dispose();
      try {
        await tempAppDir.delete(recursive: true);
      } catch (_) {}
      try {
        await tempOutputDir.delete(recursive: true);
      } catch (_) {}
    });

    test('Downloads file successfully with range support (HTTP 206)', () async {
      final fileData = List.generate(
        2 * 1024 * 1024,
        (i) => i % 256,
      ); // 2 MB test file

      mockServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      mockServer.listen((HttpRequest request) async {
        final path = request.uri.path;
        if (path == '/head') {
          request.response.headers.set('accept-ranges', 'bytes');
          request.response.contentLength = fileData.length;
          request.response.statusCode = HttpStatus.ok;
          await request.response.close();
          return;
        }

        final rangeHeader = request.headers.value('range');
        if (rangeHeader != null) {
          final match = RegExp(r'bytes=(\d+)-(\d+)').firstMatch(rangeHeader);
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
          'http://${mockServer.address.host}:${mockServer.port}/file.bin';

      final task = await engine.enqueue(
        url: url,
        outputDirectory: '${tempOutputDir.path}_explicit',
      );
      expect(task.status, DownloadStatus.queued);

      DownloadTask? completedTask;
      for (int i = 0; i < 50; i++) {
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
      expect(completedTask.outputFilename, isNotNull);

      final finalFile = File(
        p.join(completedTask.outputDirectory, completedTask.outputFilename!),
      );
      expect(finalFile.existsSync(), isTrue);
      expect(finalFile.lengthSync(), fileData.length);
    });

    test('Falls back to single stream if server returns HTTP 200 instead of 206 on Range request', () async {
      final fileData = List.generate(1024 * 1024, (i) => i % 256); // 1 MB

      mockServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      mockServer.listen((HttpRequest request) async {
        request.response.statusCode = HttpStatus.ok;
        request.response.contentLength = fileData.length;
        request.response.headers.set('accept-ranges', 'bytes');
        request.response.add(fileData);
        await request.response.close();
      });

      final url =
          'http://${mockServer.address.host}:${mockServer.port}/fallback.bin';
      final task = await engine.enqueue(
        url: url,
        outputDirectory: tempOutputDir.path,
      );

      DownloadTask? completedTask;
      for (int i = 0; i < 100; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        final current = engine.currentTasks.firstWhere((t) => t.id == task.id);
        if (current.status == DownloadStatus.completed ||
            current.status == DownloadStatus.failed) {
          completedTask = current;
          break;
        }
      }

      await mockServer.close();

      expect(completedTask?.status, DownloadStatus.completed);
      expect(completedTask?.outputFilename, isNotNull);

      final finalFile = File(
        p.join(completedTask!.outputDirectory, completedTask.outputFilename!),
      );
      expect(finalFile.existsSync(), isTrue);
      expect(finalFile.lengthSync(), fileData.length);
    });
  });
}
