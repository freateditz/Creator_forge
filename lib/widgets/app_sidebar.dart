import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../routing/route_paths.dart';
import 'sidebar_item.dart';

class AppSidebar extends StatelessWidget {
  const AppSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    return Container(
      width: AppConstants.sidebarWidth,
      color: AppColors.sidebarBackground,
      child: Column(
        children: [
          _buildHeader(),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              children: [
                _buildSectionLabel('OVERVIEW'),
                SidebarItem(
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard,
                  label: 'Dashboard',
                  isActive: location == RoutePaths.dashboard,
                  onTap: () => context.go(RoutePaths.dashboard),
                ),
                const SizedBox(height: 12),
                _buildSectionLabel('DOWNLOADS'),
                SidebarItem(
                  icon: Icons.download_outlined,
                  activeIcon: Icons.download,
                  label: 'Downloads',
                  isActive: location == RoutePaths.downloads,
                  onTap: () => context.go(RoutePaths.downloads),
                ),
                SidebarItem(
                  icon: Icons.play_circle_outline,
                  activeIcon: Icons.play_circle,
                  label: 'YouTube',
                  isActive: location == RoutePaths.youtube,
                  onTap: () => context.go(RoutePaths.youtube),
                ),
                SidebarItem(
                  icon: Icons.camera_alt_outlined,
                  activeIcon: Icons.camera_alt,
                  label: 'Instagram',
                  isActive: location == RoutePaths.instagram,
                  onTap: () => context.go(RoutePaths.instagram),
                ),
                SidebarItem(
                  icon: Icons.push_pin_outlined,
                  activeIcon: Icons.push_pin,
                  label: 'Pinterest',
                  isActive: location == RoutePaths.pinterest,
                  onTap: () => context.go(RoutePaths.pinterest),
                ),
                SidebarItem(
                  icon: Icons.extension_outlined,
                  activeIcon: Icons.extension,
                  label: 'Browser',
                  isActive: location == RoutePaths.browserDownloads,
                  onTap: () => context.go(RoutePaths.browserDownloads),
                ),
                const SizedBox(height: 12),
                _buildSectionLabel('AUDIO'),
                SidebarItem(
                  icon: Icons.audio_file_outlined,
                  activeIcon: Icons.audio_file,
                  label: 'Audio Tools',
                  isActive: location == RoutePaths.audio,
                  onTap: () => context.go(RoutePaths.audio),
                ),
                SidebarItem(
                  icon: Icons.graphic_eq,
                  activeIcon: Icons.graphic_eq,
                  label: 'Vocal Separator',
                  isActive: location == RoutePaths.vocalSeparator,
                  onTap: () => context.go(RoutePaths.vocalSeparator),
                ),
                const SizedBox(height: 12),
                _buildSectionLabel('VISUAL'),
                SidebarItem(
                  icon: Icons.auto_fix_high_outlined,
                  activeIcon: Icons.auto_fix_high,
                  label: 'Bg Remover',
                  isActive: location == RoutePaths.backgroundRemover,
                  onTap: () => context.go(RoutePaths.backgroundRemover),
                ),
                SidebarItem(
                  icon: Icons.swap_horiz,
                  activeIcon: Icons.swap_horiz,
                  label: 'Converter',
                  isActive: location == RoutePaths.converter,
                  onTap: () => context.go(RoutePaths.converter),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: SidebarItem(
              icon: Icons.settings_outlined,
              activeIcon: Icons.settings,
              label: 'Settings',
              isActive: location == RoutePaths.settings,
              onTap: () => context.go(RoutePaths.settings),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.bolt, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Text(AppConstants.appName, style: AppTextStyles.headingMedium),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Text(label, style: AppTextStyles.labelSmall),
    );
  }
}
