import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/constants/app_constants.dart';
import 'core/design/design_tokens.dart';
import 'core/logging/app_logger.dart';
import 'services/desktop/desktop_lifecycle_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize config and logger with error handling
  try {
    await AppConfig.initialize();
    await AppLogger.initialize();
  } catch (e, stack) {
    // If logging isn't ready, print to stderr
    // ignore: avoid_print
    print('[ERROR] Failed to initialize config/logger: $e');
    // ignore: avoid_print
    print(stack);
  }

  // Initialize window manager with proper error handling
  // This must happen BEFORE runApp to ensure window is ready
  try {
    await windowManager.ensureInitialized();

    // Set window options early to prevent white flash
    // Use a solid dark background matching DesignTokens.bgDeep
    // This prevents white screen on both macOS and Windows
    const WindowOptions windowOptions = WindowOptions(
      size: Size(
        AppConstants.defaultWindowWidth,
        AppConstants.defaultWindowHeight,
      ),
      minimumSize: Size(
        AppConstants.minWindowWidth,
        AppConstants.minWindowHeight,
      ),
      center: true,
      title: AppConstants.appName,
      backgroundColor: DesignTokens.bgDeep, // Solid dark background
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      try {
        // Ensure window is fully configured before showing
        await windowManager.setBackgroundColor(DesignTokens.bgDeep);
        await windowManager.show();
        await windowManager.focus();
        await DesktopLifecycleService.instance.initialize();
      } catch (e, stack) {
        // ignore: avoid_print
        print('[ERROR] Failed to show/focus window: $e');
        // ignore: avoid_print
        print(stack);
      }
    });
  } catch (e, stack) {
    // ignore: avoid_print
    print('[ERROR] Window manager initialization failed: $e');
    // ignore: avoid_print
    print(stack);
    // Continue without window manager if it fails - app will still run
  }

  runApp(const ProviderScope(child: CreatorForgeApp()));
}
