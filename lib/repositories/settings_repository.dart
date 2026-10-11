import 'dart:convert';

import '../core/config/app_config.dart';
import '../core/logging/app_logger.dart';
import '../database/app_database.dart';
import '../models/app_settings.dart';

class SettingsRepository {
  final AppDatabase _db;
  final _log = AppLogger.get('SettingsRepository');

  SettingsRepository(this._db);

  Future<AppSettings> load() async {
    try {
      final json = await _db.getSetting('app_settings');
      if (json != null) {
        final decoded = jsonDecode(json) as Map<String, dynamic>;
        return AppSettings.fromJson(
          decoded,
          fallbackDownloadsDir: AppConfig.instance.defaultDownloadsDir,
          fallbackTempDir: AppConfig.instance.tempDir,
        );
      }
    } catch (e) {
      _log.warning('Failed to load settings, using defaults.', e);
    }
    return AppSettings(
      defaultDownloadsDir: AppConfig.instance.defaultDownloadsDir,
      tempDir: AppConfig.instance.tempDir,
    );
  }

  Future<void> save(AppSettings settings) async {
    try {
      await _db.setSetting('app_settings', jsonEncode(settings.toJson()));
    } catch (e) {
      _log.severe('Failed to save settings.', e);
      rethrow;
    }
  }
}
