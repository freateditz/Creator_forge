import 'package:flutter/material.dart';
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
                      _SettingsTile(
                        label: 'Default Download Directory',
                        value: settings.defaultDownloadsDir,
                        icon: Icons.folder_outlined,
                      ),
                      _SettingsTile(
                        label: 'Max Concurrent Downloads',
                        value: '${settings.maxConcurrentDownloads}',
                        icon: Icons.download_outlined,
                      ),
                      _SettingsTile(
                        label: 'Keep Download History',
                        value: settings.keepDownloadHistory
                            ? 'Enabled'
                            : 'Disabled',
                        icon: Icons.history,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _SettingsSection(
                    title: 'Processing',
                    children: [
                      _SettingsTile(
                        label: 'GPU Preference',
                        value: settings.gpuPreference.toUpperCase(),
                        icon: Icons.memory,
                      ),
                      _SettingsTile(
                        label: 'Max Concurrent Jobs',
                        value: '${settings.maxConcurrentJobs}',
                        icon: Icons.tune,
                      ),
                      _SettingsTile(
                        label: 'Auto Delete Temp Files',
                        value: settings.autoDeleteTempFiles
                            ? 'Enabled'
                            : 'Disabled',
                        icon: Icons.auto_delete_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _SettingsSection(
                    title: 'Dependencies',
                    children: [
                      _SettingsTile(
                        label: 'FFmpeg',
                        value: ffmpegVersion.when(
                          loading: () => 'Checking...',
                          error: (_, _) => 'Not found',
                          data: (v) =>
                              v != null ? 'v$v — installed' : 'Not found',
                        ),
                        icon: Icons.settings_applications_outlined,
                        statusColor: ffmpegVersion.when(
                          loading: () => null,
                          error: (_, _) => AppColors.error,
                          data: (v) =>
                              v != null ? AppColors.success : AppColors.error,
                        ),
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
                              onPressed: () {
                                // ignore: unused_local_variable
                                final info = AppLogger.diagnosticInfo;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Diagnostic info copied.'),
                                  ),
                                );
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
          child: Column(children: _buildWithDividers(children)),
        ),
      ],
    ).animate().fadeIn(duration: 250.ms);
  }

  List<Widget> _buildWithDividers(List<Widget> items) {
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

class _SettingsTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? statusColor;

  const _SettingsTile({
    required this.label,
    required this.value,
    required this.icon,
    this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
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
            value,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMedium,
            ),
          ),
        ],
      ),
    );
  }
}
