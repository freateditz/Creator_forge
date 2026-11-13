import 'package:drift/drift.dart';

import 'download_history_table.dart';

/// Per-segment persistence for resumable, crash-recoverable downloads.
///
/// Each segment has an explicit lifecycle:
///   pending → downloading → completed
///                    ↘ failed
///
/// A segment must NOT be marked COMPLETED until its response has been
/// validated, the expected bytes written, the file flushed/closed, and this
/// row updated — in that order. A crash between file-writing and row-update
/// must never leave a falsely-completed segment behind.
class DownloadSegmentsTable extends Table {
  @override
  String get tableName => 'download_segments';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get taskId => text().references(
    DownloadHistoryTable,
    #taskId,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get segmentIndex => integer()();
  IntColumn get startOffset => integer()();
  IntColumn get endOffset => integer()();
  IntColumn get expectedBytes => integer()();
  IntColumn get bytesDownloaded => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get mimeType => text().nullable()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  IntColumn get httpStatus => integer().nullable()();
  DateTimeColumn get lastUpdatedAt => dateTime()();

  // ── Segment file path for verification ──────────────────────────────────────
  /// Path to the segment file. Segments are stored at
  /// {tempDir}/seg_{segmentIndex}.tmp - this column allows verification
  /// that the DB record matches an actual file on disk.
  TextColumn get segmentPath => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {taskId, segmentIndex},
  ];
}
