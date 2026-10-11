import 'package:drift/drift.dart';

class ProcessingJobsTable extends Table {
  @override
  String get tableName => 'processing_jobs';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get jobId => text().unique()();
  TextColumn get jobType => text()();
  TextColumn get inputPath => text()();
  TextColumn get outputPath => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get paramsJson => text().nullable()();
  TextColumn get errorMessage => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
}
