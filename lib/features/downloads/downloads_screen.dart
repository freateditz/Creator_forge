import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/download_task.dart';
import '../../providers/app_providers.dart';
import 'widgets/download_task_tile.dart';

enum _FilterTab { all, active, completed, failed }

class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  _FilterTab _filter = _FilterTab.all;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(downloadTasksProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(tasksAsync),
            const SizedBox(height: 20),
            _buildFilterBar(),
            const SizedBox(height: 16),
            Expanded(child: _buildTaskList(tasksAsync)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AsyncValue<List<DownloadTask>> tasksAsync) {
    final tasks = tasksAsync.valueOrNull ?? [];
    final activeCount = tasks
        .where(
          (t) =>
              t.status == DownloadStatus.downloading ||
              t.status == DownloadStatus.resolving ||
              t.status == DownloadStatus.merging,
        )
        .length;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Downloads', style: AppTextStyles.displayMedium),
              const SizedBox(height: 2),
              Text(
                activeCount > 0
                    ? '$activeCount active download${activeCount == 1 ? '' : 's'}'
                    : '${tasks.length} total',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
        ),
        if (tasks.any(
          (t) =>
              t.status == DownloadStatus.completed ||
              t.status == DownloadStatus.cancelled,
        ))
          OutlinedButton.icon(
            onPressed: () => ref.read(downloadEngineProvider).clearCompleted(),
            icon: const Icon(Icons.clear_all, size: 16),
            label: const Text('Clear completed'),
          ),
      ],
    ).animate().fadeIn(duration: 200.ms);
  }

  Widget _buildFilterBar() {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: _FilterTab.values.map((tab) {
              final isActive = _filter == tab;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _FilterChip(
                  label: _tabLabel(tab),
                  isActive: isActive,
                  onTap: () => setState(() => _filter = tab),
                ),
              );
            }).toList(),
          ),
        ),
        SizedBox(
          width: 220,
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search downloads…',
              prefixIcon: Icon(Icons.search, size: 16),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            style: AppTextStyles.bodySmall,
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
      ],
    );
  }

  Widget _buildTaskList(AsyncValue<List<DownloadTask>> tasksAsync) {
    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          'Failed to load downloads.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
        ),
      ),
      data: (tasks) {
        final filtered = _filterTasks(tasks);

        if (filtered.isEmpty) {
          return _buildEmptyState(tasks.isEmpty);
        }

        return ListView.separated(
          itemCount: filtered.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) =>
              DownloadTaskTile(task: filtered[i]).animate().fadeIn(
                delay: Duration(milliseconds: i * 30),
                duration: 200.ms,
              ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool noTasks) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.download_outlined,
            size: 48,
            color: AppColors.textLow,
          ),
          const SizedBox(height: 14),
          Text(
            noTasks ? 'No downloads yet' : 'No downloads match this filter',
            style: AppTextStyles.headingSmall,
          ),
          const SizedBox(height: 6),
          Text(
            noTasks
                ? 'Start a download from YouTube or any supported site.'
                : 'Try changing the filter above.',
            style: AppTextStyles.bodySmall,
          ),
        ],
      ).animate().fadeIn(duration: 300.ms),
    );
  }

  List<DownloadTask> _filterTasks(List<DownloadTask> tasks) {
    var filtered = switch (_filter) {
      _FilterTab.all => tasks,
      _FilterTab.active =>
        tasks
            .where(
              (t) =>
                  t.status == DownloadStatus.queued ||
                  t.status == DownloadStatus.resolving ||
                  t.status == DownloadStatus.downloading ||
                  t.status == DownloadStatus.merging ||
                  t.status == DownloadStatus.paused,
            )
            .toList(),
      _FilterTab.completed =>
        tasks.where((t) => t.status == DownloadStatus.completed).toList(),
      _FilterTab.failed =>
        tasks
            .where(
              (t) =>
                  t.status == DownloadStatus.failed ||
                  t.status == DownloadStatus.cancelled,
            )
            .toList(),
    };

    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      filtered = filtered
          .where(
            (t) =>
                (t.title ?? t.url).toLowerCase().contains(q) ||
                t.url.toLowerCase().contains(q),
          )
          .toList();
    }

    return filtered;
  }

  String _tabLabel(_FilterTab tab) => switch (tab) {
    _FilterTab.all => 'All',
    _FilterTab.active => 'Active',
    _FilterTab.completed => 'Completed',
    _FilterTab.failed => 'Failed',
  };
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primarySurface : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: isActive ? AppColors.primary : AppColors.textMedium,
          ),
        ),
      ),
    );
  }
}
