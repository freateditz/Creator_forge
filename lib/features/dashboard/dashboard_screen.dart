import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/download_task.dart';
import '../../providers/app_providers.dart';
import '../../routing/route_paths.dart';
import 'widgets/quick_action_card.dart';
import 'widgets/stat_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(downloadTasksProvider).valueOrNull ?? [];
    final separationJobs = ref.watch(separationJobsProvider).valueOrNull ?? [];
    final bgJobs = ref.watch(bgRemovalJobsProvider).valueOrNull ?? [];
    final audioJobs = ref.watch(audioJobsProvider).valueOrNull ?? [];

    final totalDownloads = downloads
        .where((t) => t.status == DownloadStatus.completed)
        .length;
    final activeDownloads = downloads
        .where(
          (t) =>
              t.status == DownloadStatus.downloading ||
              t.status == DownloadStatus.resolving ||
              t.status == DownloadStatus.queued ||
              t.status == DownloadStatus.merging,
        )
        .length;
    final activeProcessing =
        separationJobs.where((j) => !j.isTerminal).length +
        bgJobs.where((j) => !j.isTerminal).length +
        audioJobs.where((j) => !j.isTerminal).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildStatsRow(totalDownloads, activeDownloads, activeProcessing),
            const SizedBox(height: 28),
            _buildQuickActions(context),
            const SizedBox(height: 28),
            _buildRecentActivity(downloads),
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

  Widget _buildStatsRow(
    int totalDownloads,
    int activeDownloads,
    int activeProcessing,
  ) {
    return Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Total Downloads',
                value: '$totalDownloads',
                icon: Icons.download_done,
                iconColor: AppColors.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StatCard(
                label: 'Active Downloads',
                value: '$activeDownloads',
                icon: Icons.downloading,
                iconColor: AppColors.statusDownloading,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StatCard(
                label: 'Processing Jobs',
                value: '$activeProcessing',
                icon: Icons.tune,
                iconColor: AppColors.warning,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
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

  Widget _buildRecentActivity(List<DownloadTask> downloads) {
    final recent = downloads.reversed.take(5).toList();

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
          child: recent.isEmpty
              ? Center(
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
                )
              : Column(
                  children: [
                    for (int i = 0; i < recent.length; i++) ...[
                      _RecentDownloadRow(task: recent[i]),
                      if (i < recent.length - 1)
                        const Divider(height: 1, indent: 16, endIndent: 16),
                    ],
                  ],
                ),
        ),
      ],
    ).animate().fadeIn(delay: 200.ms, duration: 300.ms);
  }
}

class _RecentDownloadRow extends StatelessWidget {
  final DownloadTask task;
  const _RecentDownloadRow({required this.task});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (task.status) {
      DownloadStatus.completed => AppColors.statusCompleted,
      DownloadStatus.failed => AppColors.statusFailed,
      DownloadStatus.cancelled => AppColors.statusCancelled,
      DownloadStatus.downloading ||
      DownloadStatus.merging => AppColors.statusDownloading,
      _ => AppColors.statusQueued,
    };

    final statusLabel = switch (task.status) {
      DownloadStatus.completed => 'Done',
      DownloadStatus.failed => 'Failed',
      DownloadStatus.cancelled => 'Cancelled',
      DownloadStatus.downloading => 'Downloading',
      DownloadStatus.merging => 'Merging',
      DownloadStatus.resolving => 'Resolving',
      DownloadStatus.queued => 'Queued',
      DownloadStatus.paused => 'Paused',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              task.title ?? task.url,
              style: AppTextStyles.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            statusLabel,
            style: AppTextStyles.caption.copyWith(color: statusColor),
          ),
        ],
      ),
    );
  }
}
