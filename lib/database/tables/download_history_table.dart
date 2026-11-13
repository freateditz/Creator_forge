import 'package:drift/drift.dart';

class DownloadHistoryTable extends Table {
  @override
  String get tableName => 'download_history';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get taskId => text().unique()();
  TextColumn get url => text()();
  TextColumn get title => text().withDefault(const Constant('Untitled'))();
  TextColumn get thumbnailUrl => text().nullable()();
  TextColumn get channelName => text().nullable()();
  TextColumn get outputPath => text().withDefault(const Constant(''))();
  TextColumn get outputFilename => text().withDefault(const Constant(''))();
  TextColumn get format => text().withDefault(const Constant(''))();
  IntColumn get fileSizeBytes => integer().nullable()();
  IntColumn get durationSeconds => integer().nullable()();
  TextColumn get status => text().withDefault(const Constant('completed'))();
  TextColumn get eTag => text().nullable()();
  TextColumn get lastModified => text().nullable()();
  TextColumn get profile => text().nullable()();
  TextColumn get metadataJson => text().nullable()();

  // ── Category and destination ──────────────────────────────────────────────
  TextColumn get category => text().withDefault(const Constant('other'))();
  TextColumn get destinationFolder => text().nullable()();

  // ── Session metadata for persistent resume / crash recovery ──────────────
  TextColumn get refreshedUrl => text().nullable()();
  TextColumn get tempDirectory => text().nullable()();
  TextColumn get mimeType => text().nullable()();
  IntColumn get segmentCount => integer().withDefault(const Constant(0))();
  IntColumn get actualBytes => integer().nullable()();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get lastUpdatedAt => dateTime().nullable()();

  // ── Crash recovery state tracking ─────────────────────────────────────────
  /// Timestamp when merge/finalization started. Used for crash recovery.
  DateTimeColumn get mergingStartedAt => dateTime().nullable()();

  /// Recovery state: unknown, resumable, corrupted, merging, merging_failed
  /// Set during initialization to indicate recovery status.
  TextColumn get recoveryState => text().nullable()();

  /// Original expected file size - used to verify merged output after crash
  TextColumn get originalFileSize => text().nullable()();

  /// Original ETag - used to validate resource identity before segment reuse
  TextColumn get originalETag => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
}
