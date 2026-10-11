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
      await _db
          .into(_db.downloadHistoryTable)
          .insertOnConflictUpdate(
            DownloadHistoryTableCompanion(
              taskId: Value(task.id),
              url: Value(task.url),
              title: Value(task.title ?? 'Untitled'),
              thumbnailUrl: Value(task.thumbnailUrl),
              channelName: Value(task.channelName),
              outputPath: Value(task.outputPath ?? task.outputDirectory),
              format: Value(task.selectedFormat ?? ''),
              fileSizeBytes: Value(task.totalBytes),
              durationSeconds: Value(task.durationSeconds),
              status: Value(_statusToString(task.status)),
              createdAt: Value(task.createdAt),
              completedAt: Value(task.completedAt),
            ),
          );
    } catch (e) {
      _log.warning('Failed to upsert task ${task.id}.', e);
    }
  }

  Future<void> updateStatus(
    String taskId,
    String status, {
    String? errorMessage,
    String? outputPath,
  }) async {
    try {
      await (_db.update(
        _db.downloadHistoryTable,
      )..where((t) => t.taskId.equals(taskId))).write(
        DownloadHistoryTableCompanion(
          status: Value(status),
          completedAt: Value(DateTime.now()),
        ),
      );
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
