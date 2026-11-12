import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import '../core/config/app_config.dart';
import 'tables/download_history_table.dart';
import 'tables/download_segments_table.dart';
import 'tables/settings_table.dart';
import 'tables/processing_jobs_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    DownloadHistoryTable,
    DownloadSegmentsTable,
    SettingsTable,
    ProcessingJobsTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // Add new columns to download_history
        await m.addColumn(
          downloadHistoryTable,
          downloadHistoryTable.eTag as dynamic,
        );
        await m.addColumn(
          downloadHistoryTable,
          downloadHistoryTable.lastModified as dynamic,
        );
        await m.addColumn(
          downloadHistoryTable,
          downloadHistoryTable.profile as dynamic,
        );
        // Create download_segments table
        await m.createTable(downloadSegmentsTable);
      }
      if (from < 3) {
        // Enrich download_segments with the metadata needed for crash recovery
        // (expectedBytes, mimeType, retryCount, lastError, httpStatus).
        await m.addColumn(
          downloadSegmentsTable,
          downloadSegmentsTable.expectedBytes as dynamic,
        );
        await m.addColumn(
          downloadSegmentsTable,
          downloadSegmentsTable.mimeType as dynamic,
        );
        await m.addColumn(
          downloadSegmentsTable,
          downloadSegmentsTable.retryCount as dynamic,
        );
        await m.addColumn(
          downloadSegmentsTable,
          downloadSegmentsTable.lastError as dynamic,
        );
        await m.addColumn(
          downloadSegmentsTable,
          downloadSegmentsTable.httpStatus as dynamic,
        );
      }
      if (from < 4) {
        // Enrich download_history with session metadata needed for persistent
        // resume / crash recovery.
        await m.addColumn(
          downloadHistoryTable,
          downloadHistoryTable.refreshedUrl as dynamic,
        );
        await m.addColumn(
          downloadHistoryTable,
          downloadHistoryTable.tempDirectory as dynamic,
        );
        await m.addColumn(
          downloadHistoryTable,
          downloadHistoryTable.mimeType as dynamic,
        );
        await m.addColumn(
          downloadHistoryTable,
          downloadHistoryTable.segmentCount as dynamic,
        );
        await m.addColumn(
          downloadHistoryTable,
          downloadHistoryTable.actualBytes as dynamic,
        );
        await m.addColumn(
          downloadHistoryTable,
          downloadHistoryTable.lastError as dynamic,
        );
        await m.addColumn(
          downloadHistoryTable,
          downloadHistoryTable.lastUpdatedAt as dynamic,
        );
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<String?> getSetting(String key) async {
    final row = await (select(
      settingsTable,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String value) =>
      into(settingsTable).insertOnConflictUpdate(
        SettingsTableCompanion(
          key: Value(key),
          value: Value(value),
          updatedAt: Value(DateTime.now()),
        ),
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final file = File(AppConfig.instance.dbPath);
    return NativeDatabase.createInBackground(file);
  });
}
