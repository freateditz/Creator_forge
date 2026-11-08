import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/design_tokens.dart';
import '../../core/design/glass_pane.dart';
import '../../models/download_task.dart';
import '../../providers/app_providers.dart';
import '../../routing/route_paths.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(downloadTasksProvider).valueOrNull ?? [];
    final separationJobs = ref.watch(separationJobsProvider).valueOrNull ?? [];
    final bgJobs = ref.watch(bgRemovalJobsProvider).valueOrNull ?? [];
    final audioJobs = ref.watch(audioJobsProvider).valueOrNull ?? [];
    final dirSizeBytes = ref.watch(downloadsDirSizeProvider).valueOrNull;

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
      backgroundColor: DesignTokens.bgApp,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildStatsRow(
              totalDownloads,
              activeDownloads,
              activeProcessing,
              dirSizeBytes,
            ),
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
                  Text(
                    'Dashboard',
                    style: const TextStyle(
                      color: DesignTokens.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 32,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your creator workspace',
                    style: const TextStyle(
                      color: DesignTokens.textSecondary,
                      fontSize: 15,
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

  static String _formatBytes(int? bytes) {
    if (bytes == null) return '…';
    if (bytes == 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    final formatted = value < 10
        ? value.toStringAsFixed(1)
        : value.toStringAsFixed(0);
    return '$formatted ${units[unitIndex]}';
  }

  Widget _buildStatsRow(
    int totalDownloads,
    int activeDownloads,
    int activeProcessing,
    int? dirSizeBytes,
  ) {
    return Row(
          children: [
            Expanded(
              child: _GlassStatCard(
                label: 'Total Downloads',
                value: '$totalDownloads',
                icon: Icons.download_done,
                iconColor: DesignTokens.accentCyan,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _GlassStatCard(
                label: 'Active Downloads',
                value: '$activeDownloads',
                icon: Icons.downloading,
                iconColor: DesignTokens.warning,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _GlassStatCard(
                label: 'Processing Jobs',
                value: '$activeProcessing',
                icon: Icons.tune,
                iconColor: DesignTokens.accentViolet,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _GlassStatCard(
                label: 'Storage Used',
                value: _formatBytes(dirSizeBytes),
                icon: Icons.folder_outlined,
                iconColor: DesignTokens.accentPink,
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
        const Text(
          'Quick Actions',
          style: TextStyle(
            color: DesignTokens.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 2.4,
          children: [
            _GlassActionCard(
              icon: Icons.play_circle_outline,
              label: 'Download Video',
              subtitle: 'YouTube, Instagram & more',
              accent: DesignTokens.accentCyan,
              onTap: () => context.go(RoutePaths.youtube),
            ),
            _GlassActionCard(
              icon: Icons.audiotrack,
              label: 'Extract Audio',
              subtitle: 'Pull audio from any video',
              accent: DesignTokens.accentCyan,
              onTap: () => context.go(RoutePaths.audio),
            ),
            _GlassActionCard(
              icon: Icons.graphic_eq,
              label: 'Separate Vocals',
              subtitle: 'Isolate vocals & instrumentals',
              accent: DesignTokens.accentViolet,
              onTap: () => context.go(RoutePaths.vocalSeparator),
            ),
            _GlassActionCard(
              icon: Icons.auto_fix_high_outlined,
              label: 'Remove Background',
              subtitle: 'AI background removal',
              accent: DesignTokens.accentPink,
              onTap: () => context.go(RoutePaths.backgroundRemover),
            ),
            _GlassActionCard(
              icon: Icons.swap_horiz,
              label: 'Convert Media',
              subtitle: 'Video, audio & image formats',
              accent: DesignTokens.success,
              onTap: () => context.go(RoutePaths.converter),
            ),
            _GlassActionCard(
              icon: Icons.extension_outlined,
              label: 'Browser Downloads',
              subtitle: 'Download from any site',
              accent: DesignTokens.warning,
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
        const Text(
          'Recent Activity',
          style: TextStyle(
            color: DesignTokens.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 14),
        GlassPane(
          padding: EdgeInsets.zero,
          borderRadius: BorderRadius.circular(16),
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
                          color: DesignTokens.textTertiary,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No recent activity',
                          style: TextStyle(
                            color: DesignTokens.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Downloads and processing jobs will appear here.',
                          style: TextStyle(
                            color: DesignTokens.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (int i = 0; i < recent.length; i++) ...[
                      _GlassRecentDownloadRow(task: recent[i]),
                      if (i < recent.length - 1)
                        const Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: DesignTokens.glassBorder,
                        ),
                    ],
                  ],
                ),
        ),
      ],
    ).animate().fadeIn(delay: 200.ms, duration: 300.ms);
  }
}

class _GlassStatCard extends StatelessWidget {
  const _GlassStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return GlassPane(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: DesignTokens.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 24,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: DesignTokens.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassActionCard extends StatelessWidget {
  const _GlassActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: GlassPane(
          padding: const EdgeInsets.all(14),
          borderRadius: BorderRadius.circular(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0.2),
                      accent.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Icon(icon, size: 20, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: DesignTokens.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: DesignTokens.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassRecentDownloadRow extends StatelessWidget {
  final DownloadTask task;
  const _GlassRecentDownloadRow({required this.task});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (task.status) {
      DownloadStatus.completed => DesignTokens.success,
      DownloadStatus.failed => DesignTokens.error,
      DownloadStatus.cancelled => DesignTokens.warning,
      DownloadStatus.downloading || DownloadStatus.merging => DesignTokens.info,
      _ => DesignTokens.warning,
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
              style: const TextStyle(
                color: DesignTokens.textPrimary,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            statusLabel,
            style: TextStyle(
              color: statusColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
