import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/design/design_tokens.dart';
import 'core/theme/app_theme.dart';
import 'routing/app_router.dart';

class CreatorForgeApp extends ConsumerWidget {
  const CreatorForgeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'CreatorForge',
      debugShowCheckedModeBanner: false,
      // Force dark theme and set background to prevent white flash
      theme: AppTheme.dark.copyWith(
        scaffoldBackgroundColor: DesignTokens.bgDeep,
      ),
      // Dark theme for system dark mode
      darkTheme: AppTheme.dark.copyWith(
        scaffoldBackgroundColor: DesignTokens.bgDeep,
      ),
      themeMode: ThemeMode.dark,
      routerConfig: appRouter,
      // Builder to ensure background covers entire window
      builder: (context, child) {
        return ColoredBox(
          color: DesignTokens.bgDeep,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
