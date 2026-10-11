import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../constants/app_constants.dart';

class AppConfig {
  AppConfig._();

  static AppConfig? _instance;
  static AppConfig get instance => _instance!;

  late final String appDataDir;
  late final String binDir;
  late final String tempDir;
  late final String logsDir;
  late final String modelsDir;
  late final String defaultDownloadsDir;
  late final String dbPath;
  late final String logPath;

  static Future<AppConfig> initialize() async {
    if (_instance != null) return _instance!;

    final config = AppConfig._();
    await config._init();
    _instance = config;
    return config;
  }

  Future<void> _init() async {
    final appSupport = await getApplicationSupportDirectory();
    final documents = await getApplicationDocumentsDirectory();

    appDataDir = p.join(appSupport.path, AppConstants.appName);
    binDir = p.join(appDataDir, 'bin');
    tempDir = p.join(appDataDir, 'temp');
    logsDir = p.join(appDataDir, 'logs');
    modelsDir = p.join(appDataDir, 'models');
    defaultDownloadsDir = p.join(documents.path, AppConstants.appName);
    dbPath = p.join(appDataDir, AppConstants.dbFileName);
    logPath = p.join(logsDir, AppConstants.logFileName);

    for (final dir in [
      appDataDir,
      binDir,
      tempDir,
      logsDir,
      modelsDir,
      defaultDownloadsDir,
    ]) {
      await Directory(dir).create(recursive: true);
    }
  }
}
