import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../routing/route_paths.dart';
import 'widgets/quick_action_card.dart';
import 'widgets/stat_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildStatsRow(),
            const SizedBox(height: 28),
            _buildQuickActions(context),
            const SizedBox(height: 28),
            _buildRecentActivity(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dashboard', style: AppTextStyles.displayMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Your creator workspace',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
        )
        .animate()
        .fadeIn(delay: 50.ms, duration: 300.ms)
        .slideY(begin: -0.05, end: 0);
  }

  Widget _buildStatsRow() {
    return const Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Total Downloads',
                value: '0',
                icon: Icons.download_done,
                iconColor: AppColors.primary,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: StatCard(
                label: 'Active Downloads',
                value: '0',
                icon: Icons.downloading,
                iconColor: AppColors.statusDownloading,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: StatCard(
                label: 'Processing Jobs',
                value: '0',
                icon: Icons.tune,
                iconColor: AppColors.warning,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: StatCard(
                label: 'Storage Used',
                value: '—',
                icon: Icons.folder_outlined,
                iconColor: AppColors.secondary,
              ),
            ),
          ],
        )
        .animate()
        .fadeIn(delay: 100.ms, duration: 300.ms)
        .slideY(begin: 0.05, end: 0);
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions', style: AppTextStyles.headingMedium),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 2.4,
          children: [
            QuickActionCard(
              icon: Icons.play_circle_outline,
              label: 'Download Video',
              subtitle: 'YouTube, Instagram & more',
              accent: AppColors.primary,
              onTap: () => context.go(RoutePaths.youtube),
            ),
            QuickActionCard(
              icon: Icons.audiotrack,
              label: 'Extract Audio',
              subtitle: 'Pull audio from any video',
              accent: const Color(0xFF22D3EE),
              onTap: () => context.go(RoutePaths.audio),
            ),
            QuickActionCard(
              icon: Icons.graphic_eq,
              label: 'Separate Vocals',
              subtitle: 'Isolate vocals & instrumentals',
              accent: const Color(0xFFA78BFA),
              onTap: () => context.go(RoutePaths.vocalSeparator),
            ),
            QuickActionCard(
              icon: Icons.auto_fix_high_outlined,
              label: 'Remove Background',
              subtitle: 'AI background removal',
              accent: AppColors.secondary,
              onTap: () => context.go(RoutePaths.backgroundRemover),
            ),
            QuickActionCard(
              icon: Icons.swap_horiz,
              label: 'Convert Media',
              subtitle: 'Video, audio & image formats',
              accent: const Color(0xFF34D399),
              onTap: () => context.go(RoutePaths.converter),
            ),
            QuickActionCard(
              icon: Icons.extension_outlined,
              label: 'Browser Downloads',
              subtitle: 'Download from any site',
              accent: const Color(0xFFFBBF24),
              onTap: () => context.go(RoutePaths.browserDownloads),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 150.ms, duration: 300.ms);
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Activity', style: AppTextStyles.headingMedium),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.inbox_outlined,
                    size: 40,
                    color: AppColors.textLow,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No recent activity',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textMedium,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Downloads and processing jobs will appear here.',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 200.ms, duration: 300.ms);
  }
}
