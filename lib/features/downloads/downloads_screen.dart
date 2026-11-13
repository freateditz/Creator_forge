import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design_tokens.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/download_task.dart';
import '../../providers/app_providers.dart';
import 'widgets/download_task_tile.dart';

enum _FilterTab { all, active, completed, failed }

enum _CategoryFilter {
  all,
  videos,
  music,
  documents,
  compressed,
  programs,
  images,
  other,
}

enum _SortOption {
  dateDesc,
  dateAsc,
  nameAsc,
  nameDesc,
  sizeDesc,
  sizeAsc,
  statusAsc,
  statusDesc,
}

class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  _FilterTab _filter = _FilterTab.all;
  _CategoryFilter _categoryFilter = _CategoryFilter.all;
  _SortOption _sortOption = _SortOption.dateDesc;
  String _search = '';

  // Multi-selection state
  final Set<String> _selectedTaskIds = {};
  bool _isSelectionMode = false;

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(unifiedDownloadTasksProvider);

    return Scaffold(
      backgroundColor: DesignTokens.bgDeep,
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
        if (_isSelectionMode) ...[
          Text(
            '${_selectedTaskIds.length} selected',
            style: AppTextStyles.headingMedium.copyWith(
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 16),
          OutlinedButton.icon(
            onPressed: _clearSelection,
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Clear selection'),
          ),
          const SizedBox(width: 8),
          if (_selectedTaskIds.isNotEmpty) ...[
            OutlinedButton.icon(
              onPressed: () => _bulkAction(BulkAction.pause),
              icon: const Icon(Icons.pause, size: 16),
              label: const Text('Pause'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _bulkAction(BulkAction.resume),
              icon: const Icon(Icons.play_arrow, size: 16),
              label: const Text('Resume'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _bulkAction(BulkAction.cancel),
              icon: const Icon(Icons.cancel, size: 16),
              label: const Text('Cancel'),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _bulkAction(BulkAction.retry),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _bulkAction(BulkAction.remove),
              icon: const Icon(Icons.delete, size: 16),
              label: const Text('Remove'),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
            ),
          ],
        ] else ...[
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
              onPressed: () =>
                  ref.read(downloadEngineProvider).clearCompleted(),
              icon: const Icon(Icons.clear_all, size: 16),
              label: const Text('Clear completed'),
            ),
        ],
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
        const SizedBox(width: 12),
        Flexible(
          flex: 2,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: DropdownButtonFormField<_CategoryFilter>(
              initialValue: _categoryFilter,
              isDense: true,
              decoration: const InputDecoration(
                hintText: 'All categories',
                prefixIcon: Icon(Icons.category, size: 16),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(),
              ),
              style: AppTextStyles.bodySmall,
              items: _CategoryFilter.values.map((cat) {
                return DropdownMenuItem(
                  value: cat,
                  child: Text(
                    _categoryLabel(cat),
                    style: AppTextStyles.bodySmall,
                  ),
                );
              }).toList(),
              onChanged: (v) =>
                  setState(() => _categoryFilter = v ?? _CategoryFilter.all),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          flex: 2,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
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
        ),
        const SizedBox(width: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: DropdownButtonFormField<_SortOption>(
            initialValue: _sortOption,
            isDense: true,
            decoration: const InputDecoration(
              hintText: 'Sort',
              prefixIcon: Icon(Icons.sort, size: 16),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(),
            ),
            style: AppTextStyles.bodySmall,
            items: _SortOption.values.map((opt) {
              return DropdownMenuItem(
                value: opt,
                child: Text(_sortLabel(opt), style: AppTextStyles.bodySmall),
              );
            }).toList(),
            onChanged: (v) =>
                setState(() => _sortOption = v ?? _SortOption.dateDesc),
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
        final sorted = _sortTasks(filtered);

        if (sorted.isEmpty) {
          return _buildEmptyState(tasks.isEmpty);
        }

        return ListView.separated(
          itemCount: sorted.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final task = sorted[i];
            final isSelected = _selectedTaskIds.contains(task.id);
            return DownloadTaskTile(
              task: task,
              isSelected: isSelected,
              isSelectionMode: _isSelectionMode,
              onTap: () => _toggleSelection(task.id),
              onLongPress: () => _enterSelectionMode(task.id),
            ).animate().fadeIn(
              delay: Duration(milliseconds: i * 30),
              duration: 200.ms,
            );
          },
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

    // Filter by category
    if (_categoryFilter != _CategoryFilter.all) {
      filtered = filtered
          .where((t) => t.category?.name == _categoryFilter.name)
          .toList();
    }

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

  String _categoryLabel(_CategoryFilter cat) => switch (cat) {
    _CategoryFilter.all => 'All categories',
    _CategoryFilter.videos => 'Videos',
    _CategoryFilter.music => 'Music',
    _CategoryFilter.documents => 'Documents',
    _CategoryFilter.compressed => 'Compressed',
    _CategoryFilter.programs => 'Programs',
    _CategoryFilter.images => 'Images',
    _CategoryFilter.other => 'Other',
  };

  String _sortLabel(_SortOption opt) => switch (opt) {
    _SortOption.dateDesc => 'Date (newest)',
    _SortOption.dateAsc => 'Date (oldest)',
    _SortOption.nameAsc => 'Name (A–Z)',
    _SortOption.nameDesc => 'Name (Z–A)',
    _SortOption.sizeDesc => 'Size (largest)',
    _SortOption.sizeAsc => 'Size (smallest)',
    _SortOption.statusAsc => 'Status (A–Z)',
    _SortOption.statusDesc => 'Status (Z–A)',
  };

  List<DownloadTask> _sortTasks(List<DownloadTask> tasks) {
    final sorted = List<DownloadTask>.from(tasks);
    switch (_sortOption) {
      case _SortOption.dateDesc:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case _SortOption.dateAsc:
        sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case _SortOption.nameAsc:
        sorted.sort(
          (a, b) => (a.title ?? a.url).toLowerCase().compareTo(
            (b.title ?? b.url).toLowerCase(),
          ),
        );
        break;
      case _SortOption.nameDesc:
        sorted.sort(
          (a, b) => (b.title ?? b.url).toLowerCase().compareTo(
            (a.title ?? a.url).toLowerCase(),
          ),
        );
        break;
      case _SortOption.sizeDesc:
        sorted.sort((a, b) => (b.totalBytes ?? 0).compareTo(a.totalBytes ?? 0));
        break;
      case _SortOption.sizeAsc:
        sorted.sort((a, b) => (a.totalBytes ?? 0).compareTo(b.totalBytes ?? 0));
        break;
      case _SortOption.statusAsc:
        sorted.sort((a, b) => a.status.name.compareTo(b.status.name));
        break;
      case _SortOption.statusDesc:
        sorted.sort((a, b) => b.status.name.compareTo(a.status.name));
        break;
    }
    return sorted;
  }

  void _toggleSelection(String taskId) {
    setState(() {
      if (_selectedTaskIds.contains(taskId)) {
        _selectedTaskIds.remove(taskId);
        if (_selectedTaskIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedTaskIds.add(taskId);
      }
    });
  }

  void _enterSelectionMode(String taskId) {
    setState(() {
      _isSelectionMode = true;
      _selectedTaskIds.add(taskId);
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedTaskIds.clear();
      _isSelectionMode = false;
    });
  }

  void _bulkAction(BulkAction action) {
    final engine = ref.read(downloadEngineProvider);
    final segmentedEngine = ref.read(segmentedEngineProvider);

    for (final taskId in _selectedTaskIds) {
      switch (action) {
        case BulkAction.pause:
          engine.pause(taskId);
          segmentedEngine.pause(taskId);
          break;
        case BulkAction.resume:
          engine.resume(taskId);
          segmentedEngine.resume(taskId);
          break;
        case BulkAction.cancel:
          engine.cancel(taskId);
          segmentedEngine.cancel(taskId);
          break;
        case BulkAction.retry:
          engine.retry(taskId);
          segmentedEngine.retry(taskId);
          break;
        case BulkAction.remove:
          engine.remove(taskId);
          segmentedEngine.remove(taskId);
          break;
      }
    }
    _clearSelection();
  }
}

enum BulkAction { pause, resume, cancel, retry, remove }

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
