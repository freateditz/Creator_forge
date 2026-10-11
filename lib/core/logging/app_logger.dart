import 'dart:io';

import 'package:logging/logging.dart';

import '../config/app_config.dart';

class AppLogger {
  AppLogger._();

  static IOSink? _logFileSink;
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    hierarchicalLoggingEnabled = true;
    Logger.root.level = Level.ALL;

    try {
      final logPath = AppConfig.instance.logPath;
      final logFile = File(logPath);
      _logFileSink = logFile.openWrite(mode: FileMode.append);
    } catch (_) {
      // Log file unavailable; continue without file logging
    }

    Logger.root.onRecord.listen((record) {
      final line = _format(record);
      _writeLine(line, record.level);
    });

    _initialized = true;
  }

  static String _format(LogRecord r) {
    final ts = r.time.toIso8601String();
    final level = r.level.name.padRight(7);
    final module = r.loggerName.padRight(20);
    final err = r.error != null ? ' | error: ${r.error}' : '';
    final stack = r.stackTrace != null ? '\n${r.stackTrace}' : '';
    return '[$ts] $level $module ${r.message}$err$stack';
  }

  static void _writeLine(String line, Level level) {
    if (level >= Level.WARNING) {
      stderr.writeln(line);
    } else {
      // ignore: avoid_print
      print(line);
    }
    _logFileSink?.writeln(line);
  }

  static Logger get(String name) => Logger(name);

  static Future<void> close() async {
    await _logFileSink?.flush();
    await _logFileSink?.close();
  }

  static String get diagnosticInfo {
    final config = AppConfig.instance;
    return '''
=== CreatorForge Diagnostic Info ===
App Version: 1.0.0+1
Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}
Dart SDK: ${Platform.version}
App Data: ${config.appDataDir}
Log Path: ${config.logPath}
DB Path: ${config.dbPath}
=================================
''';
  }
}
