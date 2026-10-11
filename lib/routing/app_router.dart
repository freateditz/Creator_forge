import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/audio/audio_screen.dart';
import '../features/background_remover/background_remover_screen.dart';
import '../features/browser_downloads/browser_downloads_screen.dart';
import '../features/converter/converter_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/downloads/downloads_screen.dart';
import '../features/instagram/instagram_screen.dart';
import '../features/pinterest/pinterest_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/vocal_separator/vocal_separator_screen.dart';
import '../features/youtube/youtube_screen.dart';
import '../widgets/app_shell.dart';
import 'route_paths.dart';

final appRouter = GoRouter(
  initialLocation: RoutePaths.dashboard,
  debugLogDiagnostics: false,
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: RoutePaths.dashboard,
          pageBuilder: (context, state) =>
              _noTransition(state, const DashboardScreen()),
        ),
        GoRoute(
          path: RoutePaths.downloads,
          pageBuilder: (context, state) =>
              _noTransition(state, const DownloadsScreen()),
        ),
        GoRoute(
          path: RoutePaths.youtube,
          pageBuilder: (context, state) =>
              _noTransition(state, const YouTubeScreen()),
        ),
        GoRoute(
          path: RoutePaths.instagram,
          pageBuilder: (context, state) =>
              _noTransition(state, const InstagramScreen()),
        ),
        GoRoute(
          path: RoutePaths.pinterest,
          pageBuilder: (context, state) =>
              _noTransition(state, const PinterestScreen()),
        ),
        GoRoute(
          path: RoutePaths.audio,
          pageBuilder: (context, state) =>
              _noTransition(state, const AudioScreen()),
        ),
        GoRoute(
          path: RoutePaths.vocalSeparator,
          pageBuilder: (context, state) =>
              _noTransition(state, const VocalSeparatorScreen()),
        ),
        GoRoute(
          path: RoutePaths.backgroundRemover,
          pageBuilder: (context, state) =>
              _noTransition(state, const BackgroundRemoverScreen()),
        ),
        GoRoute(
          path: RoutePaths.converter,
          pageBuilder: (context, state) =>
              _noTransition(state, const ConverterScreen()),
        ),
        GoRoute(
          path: RoutePaths.browserDownloads,
          pageBuilder: (context, state) =>
              _noTransition(state, const BrowserDownloadsScreen()),
        ),
        GoRoute(
          path: RoutePaths.settings,
          pageBuilder: (context, state) =>
              _noTransition(state, const SettingsScreen()),
        ),
      ],
    ),
  ],
);

CustomTransitionPage<void> _noTransition(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        child,
  );
}
