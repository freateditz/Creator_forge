import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import '../core/config/app_config.dart';
import 'tables/download_history_table.dart';
import 'tables/settings_table.dart';
import 'tables/processing_jobs_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [DownloadHistoryTable, SettingsTable, ProcessingJobsTable],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {},
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
