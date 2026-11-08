import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/design/beams_background.dart';
import '../core/design/liquid_sidebar.dart';
import '../core/design/design_tokens.dart';
import '../providers/app_providers.dart';
import '../providers/browser_integration_provider.dart';
import '../routing/route_paths.dart';

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
    // Kick off lightweight browser health check and auto-provisioning after the first frame
    // so it never blocks the UI build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(browserIntegrationProvider.notifier).initialize();
      _autoProvisionDependencies();
    });
  }

  Future<void> _autoProvisionDependencies() async {
    try {
      final provisioner = ref.read(dependencyProvisionerProvider);
      if (!provisioner.isYtDlpProvisioned) {
        await ref.read(ytdlpProvisioningProvider.notifier).provision();
      }
      if (Platform.isWindows && !provisioner.isFfmpegProvisioned) {
        await ref.read(ffmpegProvisioningProvider.notifier).provision();
      }
    } catch (_) {}
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
            color: DesignTokens.bgDeep,
            child: Stack(
              children: [
                // Animated beam background
                const BeamsBackground(),
                // Glass sidebar + content
                Row(
                  children: [
                    _buildSidebar(),
                    Expanded(child: widget.child),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return LiquidSidebar(
      width: 220,
      borderRadius: 18,
      logo: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          gradient: DesignTokens.accentGradient,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.bolt, color: Colors.white, size: 20),
      ),
      title: const Text(
        'CreatorForge',
        style: TextStyle(
          color: DesignTokens.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 18,
          letterSpacing: -0.3,
        ),
      ),
      sections: [
        LiquidSidebarSection(
          label: 'OVERVIEW',
          items: [
            LiquidSidebarItem(
              icon: Icons.dashboard_outlined,
              activeIcon: Icons.dashboard,
              label: 'Dashboard',
              route: RoutePaths.dashboard,
            ),
          ],
        ),
        LiquidSidebarSection(
          label: 'DOWNLOADS',
          items: [
            LiquidSidebarItem(
              icon: Icons.download_outlined,
              activeIcon: Icons.download,
              label: 'Downloads',
              route: RoutePaths.downloads,
            ),
            LiquidSidebarItem(
              icon: Icons.play_circle_outline,
              activeIcon: Icons.play_circle,
              label: 'YouTube',
              route: RoutePaths.youtube,
            ),
            LiquidSidebarItem(
              icon: Icons.camera_alt_outlined,
              activeIcon: Icons.camera_alt,
              label: 'Instagram',
              route: RoutePaths.instagram,
            ),
            LiquidSidebarItem(
              icon: Icons.push_pin_outlined,
              activeIcon: Icons.push_pin,
              label: 'Pinterest',
              route: RoutePaths.pinterest,
            ),
            LiquidSidebarItem(
              icon: Icons.extension_outlined,
              activeIcon: Icons.extension,
              label: 'Browser',
              route: RoutePaths.browserDownloads,
            ),
          ],
        ),
        LiquidSidebarSection(
          label: 'AUDIO',
          items: [
            LiquidSidebarItem(
              icon: Icons.audio_file_outlined,
              activeIcon: Icons.audio_file,
              label: 'Audio Tools',
              route: RoutePaths.audio,
            ),
            LiquidSidebarItem(
              icon: Icons.graphic_eq,
              activeIcon: Icons.graphic_eq,
              label: 'Vocal Separator',
              route: RoutePaths.vocalSeparator,
            ),
          ],
        ),
        LiquidSidebarSection(
          label: 'VISUAL',
          items: [
            LiquidSidebarItem(
              icon: Icons.auto_fix_high_outlined,
              activeIcon: Icons.auto_fix_high,
              label: 'Bg Remover',
              route: RoutePaths.backgroundRemover,
            ),
            LiquidSidebarItem(
              icon: Icons.swap_horiz,
              activeIcon: Icons.swap_horiz,
              label: 'Converter',
              route: RoutePaths.converter,
            ),
          ],
        ),
      ],
      footer: [
        LiquidSidebarItem(
          icon: Icons.settings_outlined,
          activeIcon: Icons.settings,
          label: 'Settings',
          route: RoutePaths.settings,
        ),
      ],
    );
  }
}

class _SettingsIntent extends Intent {
  const _SettingsIntent();
}

class _DownloadsIntent extends Intent {
  const _DownloadsIntent();
}