import 'dart:convert';

import 'package:drift/drift.dart';

import '../core/logging/app_logger.dart';
import '../database/app_database.dart';
import '../models/processing_job.dart';

class ProcessingJobRepository {
  final AppDatabase _db;
  final _log = AppLogger.get('ProcessingJobRepository');

  ProcessingJobRepository(this._db);

  Future<void> upsertJob(ProcessingJob job) async {
    try {
      await _db
          .into(_db.processingJobsTable)
          .insertOnConflictUpdate(
            ProcessingJobsTableCompanion(
              jobId: Value(job.id),
              jobType: Value(_typeToString(job.jobType)),
              inputPath: Value(job.inputPath),
              outputPath: Value(job.outputPath),
              status: Value(_statusToString(job.status)),
              paramsJson: Value(jsonEncode(job.params)),
              errorMessage: Value(job.errorMessage),
              createdAt: Value(job.createdAt),
              completedAt: Value(job.completedAt),
            ),
          );
    } catch (e) {
      _log.warning('Failed to upsert job ${job.id}.', e);
    }
  }

  Future<void> updateStatus(
    String jobId,
    ProcessingJobStatus status, {
    String? errorMessage,
    String? outputPath,
  }) async {
    try {
      await (_db.update(
        _db.processingJobsTable,
      )..where((t) => t.jobId.equals(jobId))).write(
        ProcessingJobsTableCompanion(
          status: Value(_statusToString(status)),
          errorMessage: Value(errorMessage),
          outputPath: outputPath != null
              ? Value(outputPath)
              : const Value.absent(),
          completedAt: Value(
            status == ProcessingJobStatus.completed ||
                    status == ProcessingJobStatus.failed ||
                    status == ProcessingJobStatus.cancelled
                ? DateTime.now()
                : null,
          ),
        ),
      );
    } catch (e) {
      _log.warning('Failed to update status for job $jobId.', e);
    }
  }

  /// Returns jobs that were in a non-terminal state at last exit.
  Future<List<ProcessingJobsTableData>> getInterrupted() async {
    return (_db.select(_db.processingJobsTable)
          ..where((t) => t.status.isIn(['pending', 'processing']))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  Future<void> clearCompleted() => (_db.delete(
    _db.processingJobsTable,
  )..where((t) => t.status.isIn(['completed', 'cancelled']))).go();

  Future<void> deleteByJobId(String jobId) => (_db.delete(
    _db.processingJobsTable,
  )..where((t) => t.jobId.equals(jobId))).go();

  static String _typeToString(ProcessingJobType t) => switch (t) {
    ProcessingJobType.audioExtract => 'audioExtract',
    ProcessingJobType.vocalSeparation => 'vocalSeparation',
    ProcessingJobType.backgroundRemoval => 'backgroundRemoval',
    ProcessingJobType.mediaConvert => 'mediaConvert',
  };

  static String _statusToString(ProcessingJobStatus s) => switch (s) {
    ProcessingJobStatus.pending => 'pending',
    ProcessingJobStatus.processing => 'processing',
    ProcessingJobStatus.completed => 'completed',
    ProcessingJobStatus.failed => 'failed',
    ProcessingJobStatus.cancelled => 'cancelled',
  };
}
