import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/download_task.dart';
import '../../providers/app_providers.dart';
import '../downloads/widgets/download_task_tile.dart';

class BrowserDownloadsScreen extends ConsumerWidget {
  const BrowserDownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final server = ref.watch(ipcServerProvider);
    final browserIds = ref.watch(browserTaskIdsProvider);
    final allTasksAsync = ref.watch(downloadTasksProvider);

    final isRunning = server.isRunning;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(isRunning: isRunning),
          Expanded(
            child: ListView(
              children: [
                _StatusCard(isRunning: isRunning),
                _SetupInstructions(isRunning: isRunning),
                const SizedBox(height: 8),
                allTasksAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, st) => const SizedBox.shrink(),
                  data: (tasks) {
                    final browserTasks = tasks
                        .where((t) => browserIds.contains(t.id))
                        .toList();
                    if (browserTasks.isEmpty) return const SizedBox.shrink();
                    return _BrowserQueue(
                      tasks: browserTasks,
                      onClearCompleted:
                          browserTasks.any(
                            (t) =>
                                t.status == DownloadStatus.completed ||
                                t.status == DownloadStatus.cancelled,
                          )
                          ? () => ref
                                .read(downloadEngineProvider)
                                .clearCompleted()
                          : null,
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final bool isRunning;
  const _Header({required this.isRunning});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.extension_outlined,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Browser Downloads', style: AppTextStyles.headingLarge),
                Text(
                  'Download media from any page via the browser extension',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isRunning
                  ? AppColors.successSurface
                  : AppColors.errorSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isRunning
                    ? AppColors.success.withValues(alpha: 0.3)
                    : AppColors.error.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isRunning ? AppColors.success : AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isRunning ? 'Host Running' : 'Host Stopped',
                  style: AppTextStyles.caption.copyWith(
                    color: isRunning ? AppColors.success : AppColors.error,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status card ──────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final bool isRunning;
  const _StatusCard({required this.isRunning});

  @override
  Widget build(BuildContext context) {
    if (!isRunning) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.errorSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.error,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'The local IPC host could not start. Restart CreatorForge to retry.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.successSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: AppColors.success,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'CreatorForge is ready. Install the browser extension and the native host to get started.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.success),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Setup instructions ───────────────────────────────────────────────────────

class _SetupInstructions extends StatefulWidget {
  final bool isRunning;
  const _SetupInstructions({required this.isRunning});

  @override
  State<_SetupInstructions> createState() => _SetupInstructionsState();
}

class _SetupInstructionsState extends State<_SetupInstructions> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(
                    Icons.install_desktop_outlined,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Setup Instructions',
                      style: AppTextStyles.labelMedium,
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 18,
                    color: AppColors.textMedium,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  _Step(
                    number: '1',
                    title: 'Install the native messaging host',
                    description: Platform.isMacOS
                        ? 'Run: native-host/scripts/install_macos.sh'
                        : 'Run: native-host\\scripts\\install_windows.ps1',
                    copyText: Platform.isMacOS
                        ? 'bash native-host/scripts/install_macos.sh'
                        : 'powershell -ExecutionPolicy Bypass -File native-host\\scripts\\install_windows.ps1',
                  ),
                  const SizedBox(height: 10),
                  const _Step(
                    number: '2',
                    title: 'Load the browser extension',
                    description: 'Open Chrome or Edge → chrome://extensions/ → Enable Developer mode → Load unpacked → select the browser-extension/dist/ directory.',
                  ),
                  const SizedBox(height: 10),
                  const _Step(
                    number: '3',
                    title: 'Update the native host allowed origin',
                    description: 'Copy the extension ID shown in chrome://extensions/ and run the install script again with that ID, or edit the native-host manifest and re-register.',
                  ),
                  const SizedBox(height: 10),
                  const _Step(
                    number: '4',
                    title: 'Use the extension',
                    description: 'Navigate to any page with video or audio. Click the CreatorForge extension icon, select a media item, and click "Send to CreatorForge".',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'For full setup instructions, see native-host/README.md in the CreatorForge source.',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String number;
  final String title;
  final String description;
  final String? copyText;

  const _Step({
    required this.number,
    required this.title,
    required this.description,
    this.copyText,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
          ),
          child: Center(
            child: Text(
              number,
              style: AppTextStyles.caption.copyWith(color: AppColors.primary),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.labelMedium),
              const SizedBox(height: 2),
              Text(description, style: AppTextStyles.caption),
              if (copyText != null) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: copyText!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Copied to clipboard'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.copy_rounded,
                          size: 12,
                          color: AppColors.textMedium,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            copyText!,
                            style: AppTextStyles.caption.copyWith(
                              fontFamily: 'monospace',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Browser-initiated download queue ─────────────────────────────────────────

class _BrowserQueue extends ConsumerWidget {
  final List<DownloadTask> tasks;
  final VoidCallback? onClearCompleted;

  const _BrowserQueue({required this.tasks, this.onClearCompleted});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Row(
            children: [
              Text('Browser Downloads', style: AppTextStyles.headingSmall),
              Text(' · ${tasks.length}', style: AppTextStyles.bodySmall),
              const Spacer(),
              if (onClearCompleted != null)
                TextButton(
                  onPressed: onClearCompleted,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textMedium,
                    textStyle: AppTextStyles.labelSmall,
                  ),
                  child: const Text('Clear completed'),
                ),
            ],
          ),
        ),
        for (final task in tasks)
          Padding(
            key: ValueKey(task.id),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: DownloadTaskTile(task: task),
          ),
      ],
    );
  }
}
