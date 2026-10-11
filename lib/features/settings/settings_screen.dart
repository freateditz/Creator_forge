import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/app_logger.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/app_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(appSettingsProvider);
    final ffmpegVersion = ref.watch(ffmpegVersionProvider);
    final ytdlpVersion = ref.watch(ytdlpVersionProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: AppTextStyles.displayMedium,
            ).animate().fadeIn(duration: 200.ms),
            const SizedBox(height: 4),
            Text(
              'Configure CreatorForge preferences',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textMedium,
              ),
            ).animate().fadeIn(delay: 50.ms, duration: 200.ms),
            const SizedBox(height: 28),
            settingsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text(
                'Failed to load settings.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.error,
                ),
              ),
              data: (settings) => Column(
                children: [
                  _SettingsSection(
                    title: 'Downloads',
                    children: [
                      _FolderTile(
                        label: 'Default Download Directory',
                        value: settings.defaultDownloadsDir,
                        icon: Icons.folder_outlined,
                        onPick: (path) => ref
                            .read(appSettingsProvider.notifier)
                            .save((s) => s.copyWith(defaultDownloadsDir: path)),
                      ),
                      _StepperTile(
                        label: 'Max Concurrent Downloads',
                        value: settings.maxConcurrentDownloads,
                        min: 1,
                        max: 8,
                        icon: Icons.download_outlined,
                        onChanged: (v) => ref
                            .read(appSettingsProvider.notifier)
                            .save((s) => s.copyWith(maxConcurrentDownloads: v)),
                      ),
                      _SwitchTile(
                        label: 'Keep Download History',
                        value: settings.keepDownloadHistory,
                        icon: Icons.history,
                        onChanged: (v) => ref
                            .read(appSettingsProvider.notifier)
                            .save((s) => s.copyWith(keepDownloadHistory: v)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _SettingsSection(
                    title: 'Processing',
                    children: [
                      _DropdownTile<String>(
                        label: 'GPU Preference',
                        value: settings.gpuPreference,
                        icon: Icons.memory,
                        options: const {
                          'auto': 'Auto (recommended)',
                          'cpu': 'CPU only',
                          'cuda': 'CUDA (NVIDIA)',
                          'mps': 'MPS (Apple Silicon)',
                        },
                        onChanged: (v) => ref
                            .read(appSettingsProvider.notifier)
                            .save((s) => s.copyWith(gpuPreference: v)),
                      ),
                      _StepperTile(
                        label: 'Max Concurrent Jobs',
                        value: settings.maxConcurrentJobs,
                        min: 1,
                        max: 4,
                        icon: Icons.tune,
                        onChanged: (v) => ref
                            .read(appSettingsProvider.notifier)
                            .save((s) => s.copyWith(maxConcurrentJobs: v)),
                      ),
                      _SwitchTile(
                        label: 'Auto Delete Temp Files',
                        value: settings.autoDeleteTempFiles,
                        icon: Icons.auto_delete_outlined,
                        onChanged: (v) => ref
                            .read(appSettingsProvider.notifier)
                            .save((s) => s.copyWith(autoDeleteTempFiles: v)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _SettingsSection(
                    title: 'Application',
                    children: [
                      _SwitchTile(
                        label: 'Show Notifications',
                        value: settings.showNotifications,
                        icon: Icons.notifications_outlined,
                        onChanged: (v) => ref
                            .read(appSettingsProvider.notifier)
                            .save((s) => s.copyWith(showNotifications: v)),
                      ),
                      _SwitchTile(
                        label: 'Start Minimized',
                        value: settings.startMinimized,
                        icon: Icons.minimize_outlined,
                        onChanged: (v) => ref
                            .read(appSettingsProvider.notifier)
                            .save((s) => s.copyWith(startMinimized: v)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _SettingsSection(
                    title: 'Dependencies',
                    children: [
                      _ProvisionableTile(
                        label: 'FFmpeg',
                        versionAsync: ffmpegVersion,
                        icon: Icons.settings_applications_outlined,
                        provisioningProvider: ffmpegProvisioningProvider,
                        supportsAutoInstall: Platform.isWindows,
                        installHint: Platform.isWindows
                            ? null
                            : 'Install via: brew install ffmpeg',
                      ),
                      _ProvisionableTile(
                        label: 'yt-dlp',
                        versionAsync: ytdlpVersion,
                        icon: Icons.download_for_offline_outlined,
                        provisioningProvider: ytdlpProvisioningProvider,
                        supportsAutoInstall:
                            Platform.isWindows || Platform.isMacOS,
                        installHint: null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _SettingsSection(
                    title: 'Diagnostics',
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: () async {
                                final info = AppLogger.diagnosticInfo;
                                await Clipboard.setData(
                                  ClipboardData(text: info.toString()),
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Diagnostic info copied to clipboard.',
                                      ),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.copy_outlined, size: 16),
                              label: const Text('Copy Diagnostic Info'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section container ─────────────────────────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.headingMedium),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(children: _withDividers(children)),
        ),
      ],
    ).animate().fadeIn(duration: 250.ms);
  }

  List<Widget> _withDividers(List<Widget> items) {
    final result = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      result.add(items[i]);
      if (i < items.length - 1) {
        result.add(const Divider(height: 1, indent: 16, endIndent: 16));
      }
    }
    return result;
  }
}

// ── Tile variants ─────────────────────────────────────────────────────────────

class _FolderTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final void Function(String) onPick;

  const _FolderTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final path = await getDirectoryPath(confirmButtonText: 'Select');
        if (path != null) onPick(path);
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textMedium),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: AppTextStyles.bodyMedium)),
            const SizedBox(width: 12),
            Text(
              value,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMedium,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, size: 16, color: AppColors.textLow),
          ],
        ),
      ),
    );
  }
}

class _StepperTile extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final IconData icon;
  final void Function(int) onChanged;

  const _StepperTile({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textMedium),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: AppTextStyles.bodyMedium)),
          _StepButton(
            icon: Icons.remove,
            enabled: value > min,
            onTap: () => onChanged(value - 1),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 28,
            child: Text(
              '$value',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 4),
          _StepButton(
            icon: Icons.add,
            enabled: value < max,
            onTap: () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(
          icon,
          size: 14,
          color: enabled ? AppColors.textHigh : AppColors.textDisabled,
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String label;
  final bool value;
  final IconData icon;
  final void Function(bool) onChanged;

  const _SwitchTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textMedium),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: AppTextStyles.bodyMedium)),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.primary,
              activeTrackColor: AppColors.primaryDim,
            ),
          ],
        ),
      ),
    );
  }
}

class _DropdownTile<T> extends StatelessWidget {
  final String label;
  final T value;
  final IconData icon;
  final Map<T, String> options;
  final void Function(T) onChanged;

  const _DropdownTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textMedium),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: AppTextStyles.bodyMedium)),
          DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isDense: true,
              borderRadius: BorderRadius.circular(8),
              dropdownColor: AppColors.surfaceHigher,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMedium,
              ),
              items: options.entries
                  .map(
                    (e) =>
                        DropdownMenuItem<T>(value: e.key, child: Text(e.value)),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProvisionableTile extends ConsumerWidget {
  final String label;
  final AsyncValue<String?> versionAsync;
  final IconData icon;
  final NotifierProvider<dynamic, ProvisioningState> provisioningProvider;
  final bool supportsAutoInstall;
  final String? installHint;

  const _ProvisionableTile({
    required this.label,
    required this.versionAsync,
    required this.icon,
    required this.provisioningProvider,
    required this.supportsAutoInstall,
    this.installHint,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provisioning = ref.watch(provisioningProvider);
    final isInstalled = versionAsync.valueOrNull != null;

    final statusColor = versionAsync.when(
      loading: () => null,
      error: (_, _) => AppColors.error,
      data: (v) => v != null ? AppColors.success : AppColors.error,
    );
    final statusText = versionAsync.when(
      loading: () => 'Checking…',
      error: (_, _) => 'Not found',
      data: (v) => v != null ? 'v$v — installed' : 'Not found',
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.textMedium),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: AppTextStyles.bodyMedium)),
              if (statusColor != null)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
              Text(
                statusText,
                style: AppTextStyles.bodySmall.copyWith(
                  color: statusColor ?? AppColors.textMedium,
                ),
              ),
              if (!isInstalled &&
                  supportsAutoInstall &&
                  provisioning.status == ProvisioningStatus.idle) ...[
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () =>
                      ref.read(provisioningProvider.notifier).provision(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                  ),
                  child: Text(
                    'Auto-install',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
              if (provisioning.status == ProvisioningStatus.done &&
                  !isInstalled) ...[
                const SizedBox(width: 10),
                Text(
                  'Installed — restart may be required',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.success,
                  ),
                ),
              ],
            ],
          ),
          if (provisioning.status == ProvisioningStatus.downloading) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: provisioning.progress > 0 ? provisioning.progress : null,
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              provisioning.progress > 0
                  ? 'Downloading… ${(provisioning.progress * 100).toStringAsFixed(0)}%'
                  : 'Downloading…',
              style: AppTextStyles.caption,
            ),
          ],
          if (provisioning.status == ProvisioningStatus.error &&
              provisioning.errorMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              'Failed: ${provisioning.errorMessage}',
              style: AppTextStyles.caption.copyWith(color: AppColors.error),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => ref.read(provisioningProvider.notifier).reset(),
              child: Text(
                'Dismiss',
                style: AppTextStyles.caption.copyWith(color: AppColors.primary),
              ),
            ),
          ],
          if (!isInstalled && !supportsAutoInstall && installHint != null) ...[
            const SizedBox(height: 4),
            Text(installHint!, style: AppTextStyles.caption),
          ],
        ],
      ),
    );
  }
}
