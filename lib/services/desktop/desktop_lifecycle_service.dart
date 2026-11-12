import 'dart:io';

import 'package:window_manager/window_manager.dart';

import '../../core/logging/app_logger.dart';

class DesktopLifecycleService with WindowListener {
  static final DesktopLifecycleService instance = DesktopLifecycleService._();
  DesktopLifecycleService._();

  final _log = AppLogger.get('DesktopLifecycleService');
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) return;
    _initialized = true;

    try {
      await windowManager.setPreventClose(true);
      windowManager.addListener(this);
      _log.info(
        'Desktop lifecycle service initialized (Close to Tray active).',
      );
    } catch (e, st) {
      _log.warning('Failed to initialize desktop lifecycle: $e', st);
    }
  }

  @override
  void onWindowClose() async {
    try {
      _log.info('Window close intercepted — hiding window to tray/background.');
      await windowManager.hide();
    } catch (e) {
      _log.warning('Error handling window close: $e');
    }
  }

  Future<void> restoreWindow() async {
    try {
      await windowManager.show();
      await windowManager.focus();
    } catch (e) {
      _log.warning('Error restoring window: $e');
    }
  }

  Future<void> exitApp() async {
    try {
      _log.info('Explicit exit requested.');
      await windowManager.setPreventClose(false);
      await windowManager.close();
    } catch (e) {
      _log.warning('Error exiting app: $e');
    }
  }

  Future<void> dispose() async {
    try {
      windowManager.removeListener(this);
    } catch (_) {}
  }
}
