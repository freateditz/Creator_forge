// ignore_for_file: avoid_dynamic_calls

import 'dart:io';

import 'package:creator_forge/database/app_database.dart';
import 'package:creator_forge/models/download_task.dart';
import 'package:creator_forge/repositories/download_history_repository.dart';
import 'package:creator_forge/services/download/segmented_http_engine.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Integration tests for crash recovery using actual SQLite database and filesystem.
/// These tests simulate application restarts by recreating engine instances
/// with persisted database state and physical segment files.
void main() {
  group('Download Recovery Integration Tests (SQLite + Filesystem)', () {
    late Directory tempDir;
    late Directory tempOutputDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'creator_forge_integration_test_',
      );
      tempOutputDir = await Directory.systemTemp.createTemp(
        'creator_forge_output_',
      );
    });

    tearDown(() async {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    });

    AppDatabase createDatabase(String dbPath) {
      final file = File(dbPath);
      return AppDatabase.forTesting(NativeDatabase(file));
    }

    // Helper to get task by ID from database
    Future<DownloadHistoryTableData?> getTaskById(
      AppDatabase db,
      String taskId,
    ) async {
      return (db.select(
        db.downloadHistoryTable,
      )..where((t) => t.taskId.equals(taskId))).getSingleOrNull();
    }

    test('A. Valid completed segments are preserved on restart', () async {
      final testData = List.generate(1024 * 1024, (i) => i % 256);
      final fileSize = testData.length;
      final taskId =
          'test-valid-segments-${DateTime.now().millisecondsSinceEpoch}';
      final dbPath = p.join(tempDir.path, 'test_a.db');

      // Create mock HTTP server with correct responses
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        final rangeHeader = request.headers.value('range');
        if (rangeHeader != null) {
          final match = RegExp(r'bytes=(\d+)-(\d+)').firstMatch(rangeHeader);
          if (match != null) {
            final start = int.parse(match.group(1)!);
            final end = int.parse(match.group(2)!);
            final chunk = testData.sublist(start, end + 1);

            request.response.statusCode = HttpStatus.partialContent;
            request.response.headers.set(
              'content-range',
              'bytes $start-$end/$fileSize',
            );
            request.response.headers.set('etag', '"test-etag-valid"');
            request.response.headers.set('accept-ranges', 'bytes');
            request.response.contentLength = chunk.length;
            request.response.add(chunk);
            await request.response.close();
            return;
          }
        }

        request.response.statusCode = HttpStatus.ok;
        request.response.contentLength = fileSize;
        request.response.headers.set('etag', '"test-etag-valid"');
        request.response.headers.set('accept-ranges', 'bytes');
        request.response.add(testData);
        await request.response.close();
      });

      final tempAppDir = await Directory.systemTemp.createTemp(
        'creator_forge_app_a_',
      );
      final tempSegmentsDir = Directory(p.join(tempAppDir.path, 'segments'));
      await tempSegmentsDir.create();

      // Phase 1: Create database and populate with task + segments
      {
        final db = createDatabase(dbPath);
        final repo = DownloadHistoryRepository(db);

        final task = DownloadTask(
          id: taskId,
          url: 'http://${server.address.host}:${server.port}/test.bin',
          title: 'Valid Segments Test',
          outputDirectory: tempOutputDir.path,
          outputFilename: 'test_valid_segments.bin',
          status: DownloadStatus.downloading,
          createdAt: DateTime.now(),
          totalBytes: fileSize,
          downloadedBytes: fileSize,
          eTag: 'test-etag-valid',
        );

        await repo.upsertTask(task);

        // Create segment files (simulate 4 completed segments)
        final segmentCount = 4;
        final segmentSize = fileSize ~/ segmentCount;

        for (var i = 0; i < segmentCount; i++) {
          final start = i * segmentSize;
          final end = i == segmentCount - 1
              ? fileSize - 1
              : (i + 1) * segmentSize - 1;
          final segmentPath = p.join(tempSegmentsDir.path, 'seg_$i.tmp');

          final segmentData = testData.sublist(start, end + 1);
          final segmentFile = File(segmentPath);
          await segmentFile.writeAsBytes(segmentData);

          await repo.upsertSegment(
            taskId: taskId,
            index: i,
            start: start,
            end: end,
            downloaded: end - start + 1,
            status: 'completed',
            segmentPath: segmentPath,
            expectedBytes: end - start + 1,
          );
        }

        await db.close();
      }

      await server.close();

      // Phase 2: Simulate app restart - create NEW database instance on same file
      {
        final db2 = createDatabase(dbPath);
        final repo2 = DownloadHistoryRepository(db2);

        final engine = SegmentedHttpEngine(
          historyRepo: repo2,
          maxConcurrent: 2,
          segmentCount: 4,
          defaultOutputDir: tempAppDir.path,
        );

        // Call initialize to trigger recovery
        await engine.initialize();

        // Get task by ID (it was updated by initialize)
        final taskData = await getTaskById(db2, taskId);
        expect(
          taskData,
          isNotNull,
          reason: 'Task should exist after initialize',
        );
        expect(
          taskData!.status,
          equals('paused'),
          reason: 'Status should be paused (resumable) for valid segments',
        );
        expect(
          taskData.lastError,
          contains('Resume'),
          reason: 'Should have resume message for valid segments',
        );

        // Verify segments are present in DB
        final segmentsData = await db2.select(db2.downloadSegmentsTable).get();
        expect(
          segmentsData.length,
          4,
          reason: 'All segments should be present in DB',
        );

        // Verify segment verification works
        final verification = await repo2.verifySegments(
          taskId,
          tempSegmentsDir.path,
        );
        expect(
          verification.$1,
          greaterThan(0),
          reason: 'Should verify valid segments',
        );

        await engine.dispose();
        await db2.close();
      }

      await tempAppDir.delete(recursive: true);
    });

    test('B. Missing segments are detected and valid ones preserved', () async {
      final testData = List.generate(512 * 1024, (i) => i % 256);
      final fileSize = testData.length;
      final taskId =
          'test-missing-segments-${DateTime.now().millisecondsSinceEpoch}';
      final dbPath = p.join(tempDir.path, 'test_b.db');

      final tempAppDir = await Directory.systemTemp.createTemp(
        'creator_forge_app_b_',
      );
      final tempSegmentsDir = Directory(p.join(tempAppDir.path, 'segments'));
      await tempSegmentsDir.create();

      // Phase 1: Create database with 4 segments
      {
        final db = createDatabase(dbPath);
        final repo = DownloadHistoryRepository(db);

        final task = DownloadTask(
          id: taskId,
          url: 'https://example.com/test.bin',
          title: 'Missing Segments Test',
          outputDirectory: tempOutputDir.path,
          outputFilename: 'test_missing.bin',
          status: DownloadStatus.downloading,
          createdAt: DateTime.now(),
          totalBytes: fileSize,
          eTag: 'test-etag-missing',
        );

        await repo.upsertTask(task);

        final segmentCount = 4;
        final segmentSize = fileSize ~/ segmentCount;

        for (var i = 0; i < segmentCount; i++) {
          final start = i * segmentSize;
          final end = i == segmentCount - 1
              ? fileSize - 1
              : (i + 1) * segmentSize - 1;
          final segmentPath = p.join(tempSegmentsDir.path, 'seg_$i.tmp');

          final segmentData = testData.sublist(start, end + 1);
          final segmentFile = File(segmentPath);
          await segmentFile.writeAsBytes(segmentData);

          await repo.upsertSegment(
            taskId: taskId,
            index: i,
            start: start,
            end: end,
            downloaded: end - start + 1,
            status: 'completed',
            segmentPath: segmentPath,
            expectedBytes: end - start + 1,
          );
        }

        // Delete segment 2 (simulate partial crash)
        final missingSegmentPath = p.join(tempSegmentsDir.path, 'seg_2.tmp');
        try {
          await File(missingSegmentPath).delete();
        } catch (_) {}

        await db.close();
      }

      // Phase 2: Restart with new database instance
      {
        final db2 = createDatabase(dbPath);
        final repo2 = DownloadHistoryRepository(db2);

        final engine = SegmentedHttpEngine(
          historyRepo: repo2,
          maxConcurrent: 2,
          segmentCount: 4,
          defaultOutputDir: tempAppDir.path,
        );

        await engine.initialize();

        // Get task by ID
        final taskData = await getTaskById(db2, taskId);
        expect(taskData, isNotNull, reason: 'Task should exist');
        expect(
          taskData!.lastError,
          contains('corrupted'),
          reason: 'Missing segment should be detected as corrupted',
        );

        await engine.dispose();
        await db2.close();
      }

      await tempAppDir.delete(recursive: true);
    });

    test('C. Corrupted segments with incorrect size are rejected', () async {
      final testData = List.generate(256 * 1024, (i) => i % 256);
      final fileSize = testData.length;
      final taskId =
          'test-corrupted-segments-${DateTime.now().millisecondsSinceEpoch}';
      final dbPath = p.join(tempDir.path, 'test_c.db');

      final tempAppDir = await Directory.systemTemp.createTemp(
        'creator_forge_app_c_',
      );
      final tempSegmentsDir = Directory(p.join(tempAppDir.path, 'segments'));
      await tempSegmentsDir.create();

      // Phase 1: Create database with one valid and one corrupted segment
      {
        final db = createDatabase(dbPath);
        final repo = DownloadHistoryRepository(db);

        final task = DownloadTask(
          id: taskId,
          url: 'https://example.com/test.bin',
          title: 'Corrupted Segments Test',
          outputDirectory: tempOutputDir.path,
          outputFilename: 'test_corrupted.bin',
          status: DownloadStatus.downloading,
          createdAt: DateTime.now(),
          totalBytes: fileSize,
          eTag: 'test-etag-corrupted',
        );

        await repo.upsertTask(task);

        final segmentCount = 2;
        final segmentSize = fileSize ~/ segmentCount;

        // Segment 0: valid
        final seg0Path = p.join(tempSegmentsDir.path, 'seg_0.tmp');
        await File(seg0Path).writeAsBytes(testData.sublist(0, segmentSize));

        await repo.upsertSegment(
          taskId: taskId,
          index: 0,
          start: 0,
          end: segmentSize - 1,
          downloaded: segmentSize,
          status: 'completed',
          segmentPath: seg0Path,
          expectedBytes: segmentSize,
        );

        // Segment 1: CORRUPTED (wrong size and content)
        final seg1Path = p.join(tempSegmentsDir.path, 'seg_1.tmp');
        final corruptedData = [1, 2, 3, 4, 5];
        await File(seg1Path).writeAsBytes(corruptedData);

        // expectedBytes set to the CORRECT size, but actual file is corrupted (wrong size)
        await repo.upsertSegment(
          taskId: taskId,
          index: 1,
          start: segmentSize,
          end: fileSize - 1,
          downloaded: corruptedData.length,
          status: 'completed',
          segmentPath: seg1Path,
          expectedBytes: segmentSize,
        );

        await db.close();
      }

      // Phase 2: Verify with new database instance
      {
        final db2 = createDatabase(dbPath);
        final repo2 = DownloadHistoryRepository(db2);

        final verification = await repo2.verifySegments(
          taskId,
          tempSegmentsDir.path,
        );
        // Segment 0: valid (size matches expectedBytes=segmentSize)
        // Segment 1: invalid (size 5 != expectedBytes=segmentSize)
        expect(verification.$1, 1, reason: 'Only 1 segment should be valid');
        expect(verification.$2, 2, reason: 'Total segments count');
        expect(verification.$3, false, reason: 'Not all segments are valid');

        await db2.close();
      }

      await tempAppDir.delete(recursive: true);
    });

    test('D. Incomplete segments are never treated as completed', () async {
      final testData = List.generate(128 * 1024, (i) => i % 256);
      final fileSize = testData.length;
      final taskId =
          'test-incomplete-segments-${DateTime.now().millisecondsSinceEpoch}';
      final dbPath = p.join(tempDir.path, 'test_d.db');

      final tempAppDir = await Directory.systemTemp.createTemp(
        'creator_forge_app_d_',
      );
      final tempSegmentsDir = Directory(p.join(tempAppDir.path, 'segments'));
      await tempSegmentsDir.create();

      // Phase 1: Create database with complete + incomplete segment
      {
        final db = createDatabase(dbPath);
        final repo = DownloadHistoryRepository(db);

        final task = DownloadTask(
          id: taskId,
          url: 'https://example.com/test.bin',
          title: 'Incomplete Segments Test',
          outputDirectory: tempOutputDir.path,
          outputFilename: 'test_incomplete.bin',
          status: DownloadStatus.downloading,
          createdAt: DateTime.now(),
          totalBytes: fileSize,
          downloadedBytes: 64 * 1024,
          eTag: 'test-etag-incomplete',
        );

        await repo.upsertTask(task);

        final segmentCount = 2;
        final fullSegmentSize = fileSize ~/ segmentCount;

        // Segment 0: complete
        final seg0Path = p.join(tempSegmentsDir.path, 'seg_0.tmp');
        await File(seg0Path).writeAsBytes(testData.sublist(0, fullSegmentSize));

        await repo.upsertSegment(
          taskId: taskId,
          index: 0,
          start: 0,
          end: fullSegmentSize - 1,
          downloaded: fullSegmentSize,
          status: 'completed',
          segmentPath: seg0Path,
          expectedBytes: fullSegmentSize,
        );

        // Segment 1: INCOMPLETE (only half the data)
        final seg1Path = p.join(tempSegmentsDir.path, 'seg_1.tmp');
        final incompleteData = testData.sublist(0, fullSegmentSize ~/ 2);
        await File(seg1Path).writeAsBytes(incompleteData);

        await repo.upsertSegment(
          taskId: taskId,
          index: 1,
          start: fullSegmentSize,
          end: fileSize - 1,
          downloaded: incompleteData.length,
          status: 'downloading', // Status is not completed
          segmentPath: seg1Path,
          expectedBytes: fullSegmentSize,
        );

        await db.close();
      }

      // Phase 2: Verify with new database instance
      {
        final db2 = createDatabase(dbPath);
        final repo2 = DownloadHistoryRepository(db2);

        final verification = await repo2.verifySegments(
          taskId,
          tempSegmentsDir.path,
        );
        expect(
          verification.$1,
          1,
          reason: 'Only completed segments should count as valid',
        );

        await db2.close();
      }

      await tempAppDir.delete(recursive: true);
    });

    test('E. Merge phase crash recovery detects interrupted merge', () async {
      final fileSize = 1024 * 1024;
      final taskId =
          'test-merge-crash-${DateTime.now().millisecondsSinceEpoch}';
      final dbPath = p.join(tempDir.path, 'test_e.db');

      final tempAppDir = await Directory.systemTemp.createTemp(
        'creator_forge_app_e_',
      );
      final tempOutputDir = Directory(p.join(tempAppDir.path, 'output'));
      await tempOutputDir.create();

      // Create a partial .part file (simulating crash during merge)
      final partFilePath = p.join(tempOutputDir.path, 'test_merge_part.bin');
      final partialData = List.generate(512 * 1024, (i) => i % 256);
      await File(partFilePath).writeAsBytes(partialData);

      // Phase 1: Create database with merging task
      {
        final db = createDatabase(dbPath);
        final repo = DownloadHistoryRepository(db);

        final task = DownloadTask(
          id: taskId,
          url: 'https://example.com/merge.bin',
          title: 'Merge Crash Test',
          outputDirectory: tempOutputDir.path,
          outputFilename: 'merge_result.bin',
          status: DownloadStatus.merging,
          createdAt: DateTime.now(),
          totalBytes: fileSize,
          downloadedBytes: fileSize,
          mergingStartedAt: DateTime.now(),
          eTag: 'test-etag-merge',
        );

        await repo.upsertTask(task);

        // Create segment records for merge
        final segmentCount = 4;
        final segmentSize = fileSize ~/ segmentCount;

        for (var i = 0; i < segmentCount; i++) {
          final segmentPath = p.join(tempAppDir.path, 'seg_$i.tmp');
          await repo.upsertSegment(
            taskId: taskId,
            index: i,
            start: i * segmentSize,
            end: (i + 1) * segmentSize - 1,
            downloaded: segmentSize,
            status: 'completed',
            segmentPath: segmentPath,
            expectedBytes: segmentSize,
          );
        }

        await db.close();
      }

      // Phase 2: Restart with new database instance
      {
        final db2 = createDatabase(dbPath);
        final repo2 = DownloadHistoryRepository(db2);

        final engine = SegmentedHttpEngine(
          historyRepo: repo2,
          maxConcurrent: 2,
          segmentCount: 4,
          defaultOutputDir: tempAppDir.path,
        );

        await engine.initialize();

        final taskData = await getTaskById(db2, taskId);
        expect(taskData, isNotNull, reason: 'Task should exist');
        expect(
          taskData!.status,
          equals('failed'),
          reason: 'Merge crash should mark task as failed',
        );
        expect(
          taskData.lastError,
          contains('Retry'),
          reason: 'Should indicate retry needed',
        );

        await engine.dispose();
        await db2.close();
      }

      await tempAppDir.delete(recursive: true);
    });

    test('F. Recovery state survives database restart', () async {
      final taskId =
          'test-recovery-state-${DateTime.now().millisecondsSinceEpoch}';
      final dbPath = p.join(tempDir.path, 'test_f.db');

      final tempAppDir = await Directory.systemTemp.createTemp(
        'creator_forge_app_f_',
      );

      // Phase 1: Create database with recovery state
      {
        final db = createDatabase(dbPath);
        final repo = DownloadHistoryRepository(db);

        final task = DownloadTask(
          id: taskId,
          url: 'https://example.com/test.bin',
          title: 'Recovery State Test',
          outputDirectory: tempOutputDir.path,
          outputFilename: 'test.bin',
          status: DownloadStatus.downloading,
          createdAt: DateTime.now(),
          totalBytes: 1024,
          errorMessage: 'Resume: 3 segments valid',
          recoveryState: 'resumable',
        );

        await repo.upsertTask(task);
        await db.close();
      }

      // Phase 2: Reopen database
      {
        final db2 = createDatabase(dbPath);
        final repo2 = DownloadHistoryRepository(db2);

        final recoveredTasks = await repo2.getInterrupted();
        expect(recoveredTasks.length, 1);

        final taskData = await getTaskById(db2, taskId);
        expect(taskData, isNotNull, reason: 'Task should exist');
        expect(
          taskData!.recoveryState,
          equals('resumable'),
          reason: 'Recovery state should persist across DB restart',
        );

        await db2.close();
      }

      await tempAppDir.delete(recursive: true);
    });

    test(
      'G. ETag validation prevents segment reuse across resource changes',
      () async {
        final testData = List.generate(64 * 1024, (i) => i % 256);
        final taskId =
            'test-etag-validation-${DateTime.now().millisecondsSinceEpoch}';
        final dbPath = p.join(tempDir.path, 'test_g.db');

        final tempAppDir = await Directory.systemTemp.createTemp(
          'creator_forge_app_g_',
        );
        final tempSegmentsDir = Directory(p.join(tempAppDir.path, 'segments'));
        await tempSegmentsDir.create();

        // Phase 1: Create database with OLD ETag and completed segment
        // Task must be in failed/cancelled state for retry() to work
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final serverUrl =
            'http://${server.address.host}:${server.port}/test.bin';

        server.listen((request) async {
          request.response.statusCode = HttpStatus.ok;
          request.response.contentLength = testData.length;
          request.response.headers.set('etag', 'new-etag-v2');
          request.response.headers.set('accept-ranges', 'bytes');
          request.response.add(testData);
          await request.response.close();
        });

        {
          final db = createDatabase(dbPath);
          final repo = DownloadHistoryRepository(db);

          // Status must be non-terminal so initialize()/getInterrupted() loads the
          // task into the engine. Set tempDirectory to match segment location.
          final tempDir = tempSegmentsDir.path;
          final task = DownloadTask(
            id: taskId,
            url: serverUrl,
            title: 'ETag Validation Test',
            outputDirectory: tempOutputDir.path,
            outputFilename: 'test.bin',
            status: DownloadStatus.downloading,
            createdAt: DateTime.now(),
            totalBytes: testData.length,
            eTag: 'old-etag-v1',
            tempDirectory: tempDir,
          );

          await repo.upsertTask(task);

          final segmentPath = p.join(tempDir, 'seg_0.tmp');
          await File(segmentPath).writeAsBytes(testData);

          await repo.upsertSegment(
            taskId: taskId,
            index: 0,
            start: 0,
            end: testData.length - 1,
            downloaded: testData.length,
            status: 'completed',
            segmentPath: segmentPath,
            expectedBytes: testData.length,
          );

          await db.close();
        }

        // Phase 2: Restart engine and trigger retry (which does HEAD request and ETag validation)
        {
          final db2 = createDatabase(dbPath);
          final repo2 = DownloadHistoryRepository(db2);

          final engine = SegmentedHttpEngine(
            historyRepo: repo2,
            maxConcurrent: 2,
            segmentCount: 1,
            defaultOutputDir: tempAppDir.path,
          );

          // Initialize to load the task from DB
          await engine.initialize();

          // Task will be paused (resumable) - use resume() to trigger download
          // which includes HEAD request and ETag validation
          await engine.resume(taskId);

          // Wait for the task to be processed and either complete or fail
          // The ETag validation happens in _startDownload which runs asynchronously
          DownloadTask? updatedTask;
          for (int i = 0; i < 30; i++) {
            await Future.delayed(const Duration(milliseconds: 200));
            // Check if task exists in currentTasks
            final tasks = engine.currentTasks;
            final matchingTask = tasks.firstWhere(
              (t) => t.id == taskId,
              orElse: () => throw StateError('Task not found'),
            );
            if (matchingTask.eTag == 'new-etag-v2') {
              updatedTask = matchingTask;
              break;
            }
          }

          // Verify ETag was updated in memory (and thus will be persisted)
          expect(
            updatedTask,
            isNotNull,
            reason: 'Task should have updated ETag',
          );
          expect(
            updatedTask!.eTag,
            equals('new-etag-v2'),
            reason: 'ETag should be updated from server after resource change detected',
          );

          // Give time for _persistTask to complete (it's async)
          await Future.delayed(const Duration(milliseconds: 500));

          // Also verify in database - need to query fresh
          final dbTask = await getTaskById(db2, taskId);
          expect(dbTask, isNotNull);
          expect(
            dbTask!.eTag,
            equals('new-etag-v2'),
            reason: 'ETag should be persisted to database',
          );

          await engine.dispose();
          await db2.close();
        }

        await server.close();
        await tempAppDir.delete(recursive: true);
      },
    );

    test(
      'H. Database records reconcile with physical files after crash',
      () async {
        final fileSize = 256 * 1024;
        final taskId =
            'test-reconciliation-${DateTime.now().millisecondsSinceEpoch}';
        final dbPath = p.join(tempDir.path, 'test_h.db');

        final tempAppDir = await Directory.systemTemp.createTemp(
          'creator_forge_app_h_',
        );
        final tempSegmentsDir = Directory(p.join(tempAppDir.path, 'segments'));
        await tempSegmentsDir.create();

        // Phase 1: Create database with segment record pointing to non-existent file
        {
          final db = createDatabase(dbPath);
          final repo = DownloadHistoryRepository(db);

          final task = DownloadTask(
            id: taskId,
            url: 'https://example.com/test.bin',
            title: 'Reconciliation Test',
            outputDirectory: tempOutputDir.path,
            outputFilename: 'test.bin',
            status: DownloadStatus.downloading,
            createdAt: DateTime.now(),
            totalBytes: fileSize,
            eTag: 'test-etag-recon',
          );

          await repo.upsertTask(task);

          // DB says we have a segment at a path that doesn't match tempDir/seg_0.tmp
          // The verifySegments uses seg.segmentPath OR tempDir/seg_0.tmp
          // We set a path that won't exist in either location
          await repo.upsertSegment(
            taskId: taskId,
            index: 0,
            start: 0,
            end: fileSize - 1,
            downloaded: fileSize,
            status: 'completed',
            segmentPath: p.join(tempAppDir.path, 'nonexistent_seg.tmp'),
            expectedBytes: fileSize,
          );

          await db.close();
        }

        // Phase 2: Simulate crash and restart
        {
          final db2 = createDatabase(dbPath);
          final repo2 = DownloadHistoryRepository(db2);

          // Verify segments - should find 0 valid since file doesn't exist
          // We pass tempSegmentsDir.path as the tempDir for fallback paths
          final verification = await repo2.verifySegments(
            taskId,
            tempSegmentsDir.path,
          );
          expect(verification.$1, 0, reason: 'No segments should be valid');
          expect(verification.$2, 1, reason: '1 segment recorded in DB');

          await db2.close();
        }

        await tempAppDir.delete(recursive: true);
      },
    );
  });
}
