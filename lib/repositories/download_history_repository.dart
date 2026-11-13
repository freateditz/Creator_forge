import 'dart:io';

import 'package:drift/drift.dart';

import '../core/logging/app_logger.dart';
import '../database/app_database.dart';
import '../models/download_task.dart';

class DownloadHistoryRepository {
  final AppDatabase _db;
  final _log = AppLogger.get('DownloadHistoryRepository');

  DownloadHistoryRepository(this._db);

  Future<List<DownloadHistoryTableData>> getRecent({int limit = 100}) async {
    return (_db.select(_db.downloadHistoryTable)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit))
        .get();
  }

  /// Returns tasks that were in a non-terminal state when the app last exited.
  Future<List<DownloadHistoryTableData>> getInterrupted() async {
    return (_db.select(_db.downloadHistoryTable)
          ..where(
            (t) => t.status.isIn([
              'queued',
              'resolving',
              'downloading',
              'merging',
            ]),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  Future<void> upsertTask(DownloadTask task) async {
    try {
      final companion = DownloadHistoryTableCompanion(
        taskId: Value(task.id),
        url: Value(task.url),
        title: Value(task.title ?? 'Untitled'),
        thumbnailUrl: Value(task.thumbnailUrl),
        channelName: Value(task.channelName),
        outputPath: Value(task.outputPath ?? task.outputDirectory),
        outputFilename: Value(task.outputFilename ?? ''),
        format: Value(task.selectedFormat ?? ''),
        fileSizeBytes: Value(task.totalBytes),
        durationSeconds: Value(task.durationSeconds),
        status: Value(_statusToString(task.status)),
        eTag: Value(task.eTag),
        lastModified: Value(task.lastModified),
        profile: Value(task.profile),
        createdAt: Value(task.createdAt),
        completedAt: Value(task.completedAt),
        // Phase 2: Category and destination folder
        category: Value(task.category?.name ?? 'other'),
        destinationFolder: Value(task.destinationFolder),
        // Phase 3.1: Crash recovery metadata
        mergingStartedAt: Value(task.mergingStartedAt),
        recoveryState: Value(task.recoveryState),
        originalFileSize: Value(task.originalFileSize?.toString()),
        originalETag: Value(task.originalETag),
        tempDirectory: Value(task.tempDirectory),
      );
      // First try to find existing task by taskId
      final existing = await (_db.select(
        _db.downloadHistoryTable,
      )..where((t) => t.taskId.equals(task.id))).getSingleOrNull();

      if (existing != null) {
        // Update existing task (using primary key 'id')
        await (_db.update(
          _db.downloadHistoryTable,
        )..where((t) => t.id.equals(existing.id))).write(companion);
      } else {
        // Insert new task
        await _db.into(_db.downloadHistoryTable).insert(companion);
      }
    } catch (e) {
      _log.warning('Failed to upsert task ${task.id}.', e);
    }
  }

  // ── Segments ──────────────────────────────────────────────────────────────

  Future<List<DownloadSegmentsTableData>> getSegments(String taskId) async {
    return (_db.select(_db.downloadSegmentsTable)
          ..where((t) => t.taskId.equals(taskId))
          ..orderBy([(t) => OrderingTerm.asc(t.segmentIndex)]))
        .get();
  }

  Future<void> upsertSegment({
    required String taskId,
    required int index,
    required int start,
    required int end,
    required int downloaded,
    required String status,
    String? segmentPath,
    int? expectedBytes,
  }) async {
    try {
      await _db
          .into(_db.downloadSegmentsTable)
          .insertOnConflictUpdate(
            DownloadSegmentsTableCompanion(
              taskId: Value(taskId),
              segmentIndex: Value(index),
              startOffset: Value(start),
              endOffset: Value(end),
              expectedBytes: expectedBytes != null
                  ? Value(expectedBytes)
                  : Value(end - start + 1),
              bytesDownloaded: Value(downloaded),
              status: Value(status),
              lastUpdatedAt: Value(DateTime.now()),
              segmentPath: Value(segmentPath),
            ),
          );
    } catch (e) {
      _log.warning('Failed to upsert segment $index for task $taskId.', e);
    }
  }

  Future<void> deleteSegmentsByTaskId(String taskId) async {
    await (_db.delete(
      _db.downloadSegmentsTable,
    )..where((t) => t.taskId.equals(taskId))).go();
  }

  /// Verifies that all segments for a task exist on disk and match expected sizes.
  /// Returns a tuple of (verifiedCount, totalCount, allValid).
  Future<(int, int, bool)> verifySegments(String taskId, String tempDir) async {
    final segments = await getSegments(taskId);
    if (segments.isEmpty) return (0, 0, false);

    int verifiedCount = 0;
    for (final seg in segments) {
      final expectedPath =
          seg.segmentPath ?? '$tempDir/seg_${seg.segmentIndex}.tmp';
      final file = File(expectedPath);
      if (await file.exists()) {
        final actualSize = await file.length();
        if (actualSize == seg.bytesDownloaded &&
            actualSize == seg.expectedBytes) {
          verifiedCount++;
        }
      }
    }
    return (verifiedCount, segments.length, verifiedCount == segments.length);
  }

  /// Gets task with segment data for recovery analysis.
  Future<
    ({DownloadHistoryTableData? task, List<DownloadSegmentsTableData> segments})
  >
  getTaskWithSegments(String taskId) async {
    final task = await (_db.select(
      _db.downloadHistoryTable,
    )..where((t) => t.taskId.equals(taskId))).getSingleOrNull();
    final segments = await getSegments(taskId);
    return (task: task, segments: segments);
  }

  Future<void> updateStatus(
    String taskId,
    String status, {
    String? errorMessage,
    String? outputPath,
    int? totalBytes,
    int? downloadedBytes,
    String? lastUpdatedAt,
  }) async {
    try {
      final companion = DownloadHistoryTableCompanion(
        status: Value(status),
        completedAt:
            status == 'completed' || status == 'failed' || status == 'cancelled'
            ? Value(DateTime.now())
            : const Value.absent(),
        lastError: errorMessage != null
            ? Value(errorMessage)
            : const Value.absent(),
        outputPath: outputPath != null
            ? Value(outputPath)
            : const Value.absent(),
        fileSizeBytes: totalBytes != null
            ? Value(totalBytes)
            : const Value.absent(),
        actualBytes: downloadedBytes != null
            ? Value(downloadedBytes)
            : const Value.absent(),
        lastUpdatedAt: lastUpdatedAt != null
            ? Value(DateTime.parse(lastUpdatedAt))
            : Value(DateTime.now()),
      );

      await (_db.update(
        _db.downloadHistoryTable,
      )..where((t) => t.taskId.equals(taskId))).write(companion);
    } catch (e) {
      _log.warning('Failed to update status for task $taskId.', e);
    }
  }

  Future<void> insert(DownloadHistoryTableCompanion entry) async {
    try {
      await _db.into(_db.downloadHistoryTable).insertOnConflictUpdate(entry);
    } catch (e) {
      _log.warning('Failed to insert download history entry.', e);
    }
  }

  Future<void> deleteById(int id) => (_db.delete(
    _db.downloadHistoryTable,
  )..where((t) => t.id.equals(id))).go();

  Future<void> deleteByTaskId(String taskId) => (_db.delete(
    _db.downloadHistoryTable,
  )..where((t) => t.taskId.equals(taskId))).go();

  Future<void> clearCompleted() => (_db.delete(
    _db.downloadHistoryTable,
  )..where((t) => t.status.isIn(['completed', 'cancelled']))).go();

  Future<void> clearAll() => _db.delete(_db.downloadHistoryTable).go();

  /// Updates the recovery state of a task (e.g., 'resumable', 'corrupted', 'merging', 'merging_failed').
  Future<void> updateRecoveryState(String taskId, String recoveryState) async {
    try {
      await (_db.update(
        _db.downloadHistoryTable,
      )..where((t) => t.taskId.equals(taskId))).write(
        DownloadHistoryTableCompanion(
          recoveryState: Value(recoveryState),
          lastUpdatedAt: Value(DateTime.now()),
        ),
      );
    } catch (e) {
      _log.warning('Failed to update recovery state for $taskId.', e);
    }
  }

  /// Sets the mergingStartedAt timestamp when merge phase begins.
  Future<void> setMergingStarted(String taskId) async {
    try {
      await (_db.update(
        _db.downloadHistoryTable,
      )..where((t) => t.taskId.equals(taskId))).write(
        DownloadHistoryTableCompanion(
          mergingStartedAt: Value(DateTime.now()),
          status: const Value('merging'),
          lastUpdatedAt: Value(DateTime.now()),
        ),
      );
    } catch (e) {
      _log.warning('Failed to set mergingStartedAt for $taskId.', e);
    }
  }

  /// Updates a segment's path after file creation.
  Future<void> updateSegmentPath(
    String taskId,
    int segmentIndex,
    String segmentPath,
  ) async {
    try {
      await (_db.update(_db.downloadSegmentsTable)..where(
            (t) =>
                t.taskId.equals(taskId) & t.segmentIndex.equals(segmentIndex),
          ))
          .write(
            DownloadSegmentsTableCompanion(
              segmentPath: Value(segmentPath),
              lastUpdatedAt: Value(DateTime.now()),
            ),
          );
    } catch (e) {
      _log.warning(
        'Failed to update segment path for $taskId segment $segmentIndex.',
        e,
      );
    }
  }

  String _statusToString(DownloadStatus status) => switch (status) {
    DownloadStatus.queued => 'queued',
    DownloadStatus.resolving => 'resolving',
    DownloadStatus.downloading => 'downloading',
    DownloadStatus.paused => 'paused',
    DownloadStatus.merging => 'merging',
    DownloadStatus.completed => 'completed',
    DownloadStatus.failed => 'failed',
    DownloadStatus.cancelled => 'cancelled',
  };
}
