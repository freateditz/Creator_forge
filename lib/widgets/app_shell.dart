import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_colors.dart';
import '../providers/app_providers.dart';
import '../providers/browser_integration_provider.dart';
import '../routing/route_paths.dart';
import 'app_sidebar.dart';

class AppShell extends ConsumerStatefulWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  void initState() {
    super.initState();
    // Kick off lightweight browser health check after the first frame so it
    // never blocks the UI build. initialize() is a no-op after the first call.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(browserIntegrationProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Ensure the IPC server starts and is kept alive for the app's lifetime.
    ref.watch(ipcServerProvider);

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.comma):
            const _SettingsIntent(),
        LogicalKeySet(
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.shift,
          LogicalKeyboardKey.keyD,
        ): const _DownloadsIntent(),
      },
      child: Actions(
        actions: {
          _SettingsIntent: CallbackAction<_SettingsIntent>(
            onInvoke: (_) => context.go(RoutePaths.settings),
          ),
          _DownloadsIntent: CallbackAction<_DownloadsIntent>(
            onInvoke: (_) => context.go(RoutePaths.downloads),
          ),
        },
        child: Focus(
          autofocus: true,
          child: Material(
            color: AppColors.background,
            child: Row(
              children: [
                const AppSidebar(),
                Expanded(child: widget.child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsIntent extends Intent {
  const _SettingsIntent();
}

class _DownloadsIntent extends Intent {
  const _DownloadsIntent();
}
