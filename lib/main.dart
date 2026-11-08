import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/constants/app_constants.dart';
import 'core/logging/app_logger.dart';

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
  try {
    await windowManager.ensureInitialized();

    // Use a solid dark background instead of transparent to avoid white screen on Windows
    // Transparent background with normal title bar can cause rendering issues on some Windows versions
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
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
        backgroundColor: Color(0xFF070912), // DesignTokens.bgDeep - solid dark background
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
      ),
      () async {
        try {
          await windowManager.show();
          await windowManager.focus();
        } catch (e, stack) {
          // ignore: avoid_print
          print('[ERROR] Failed to show/focus window: $e');
          // ignore: avoid_print
          print(stack);
        }
      },
    );
  } catch (e, stack) {
    // ignore: avoid_print
    print('[ERROR] Window manager initialization failed: $e');
    // ignore: avoid_print
    print(stack);
    // Continue without window manager if it fails
  }

  runApp(const ProviderScope(child: CreatorForgeApp()));
}
