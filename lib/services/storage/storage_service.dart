import 'dart:io';

import '../../core/config/app_config.dart';
import '../../core/errors/app_exception.dart';
import '../../core/logging/app_logger.dart';

class StorageService {
  final _log = AppLogger.get('StorageService');

  Future<int> getAvailableBytes(String directory) async {
    try {
      FileStat.statSync(directory);
      // dart:io doesn't expose free disk space directly on all platforms;
      // platform channel integration is deferred to a future phase.
      return -1;
    } catch (e) {
      _log.warning('Could not get available bytes.', e);
      return -1;
    }
  }

  /// Returns the total size in bytes of all files inside [directory].
  Future<int> getDirectorySize(String directory) async {
    try {
      final dir = Directory(directory);
      if (!await dir.exists()) return 0;
      var size = 0;
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          try {
            size += await entity.length();
          } catch (_) {}
        }
      }
      return size;
    } catch (e) {
      _log.warning('Could not measure directory size: $directory', e);
      return 0;
    }
  }

  Future<void> cleanTempDir() async {
    try {
      final dir = Directory(AppConfig.instance.tempDir);
      if (await dir.exists()) {
        await for (final entity in dir.list()) {
          try {
            await entity.delete(recursive: true);
          } catch (e) {
            _log.warning('Could not delete temp file: ${entity.path}', e);
          }
        }
      }
    } catch (e) {
      _log.warning('Failed to clean temp directory.', e);
    }
  }

  Future<int> getTempDirSize() async {
    try {
      final dir = Directory(AppConfig.instance.tempDir);
      if (!await dir.exists()) return 0;
      var size = 0;
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          size += await entity.length();
        }
      }
      return size;
    } catch (_) {
      return 0;
    }
  }

  Future<void> ensureDirectoryExists(String path) async {
    try {
      await Directory(path).create(recursive: true);
    } catch (e) {
      throw StorageException(
        'Could not create directory.',
        technicalDetails: e.toString(),
        cause: e,
      );
    }
  }
}
