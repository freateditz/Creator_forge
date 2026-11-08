import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/app_providers.dart';

/// A dedicated screen for managing all external dependencies.
/// Shows status of FFmpeg, yt-dlp, and Python with one-click install.
class DependencySetupScreen extends ConsumerWidget {
  const DependencySetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ffmpegVersion = ref.watch(ffmpegVersionProvider);
    final ytdlpVersion = ref.watch(ytdlpVersionProvider);
    final pythonVersion = ref.watch(pythonVersionProvider);

    final ffmpegProvisioning = ref.watch(ffmpegProvisioningProvider);
    final ytdlpProvisioning = ref.watch(ytdlpProvisioningProvider);
    final pythonProvisioning = ref.watch(pythonProvisioningProvider);

    final allInstalled = ffmpegVersion.valueOrNull != null &&
        ytdlpVersion.valueOrNull != null &&
        pythonVersion.valueOrNull != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Dependency Setup', style: AppTextStyles.headingLarge),
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: allInstalled
                              ? AppColors.success.withValues(alpha: 0.15)
                              : AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          allInstalled
                              ? Icons.check_circle_outline
                              : Icons.build_circle_outlined,
                          color: allInstalled ? AppColors.success : AppColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              allInstalled
                                  ? 'All dependencies installed'
                                  : 'Missing dependencies',
                              style: AppTextStyles.headingMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              allInstalled
                                  ? 'CreatorForge is ready to use all features.'
                                  : 'Some features require external tools. Install them below.',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!allInstalled) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () {
                        ref.read(ffmpegProvisioningProvider.notifier).provision();
                        ref.read(ytdlpProvisioningProvider.notifier).provision();
                        if (Platform.isWindows) {
                          ref.read(pythonProvisioningProvider.notifier).provision();
                        }
                      },
                      icon: const Icon(Icons.download_for_offline, size: 18),
                      label: const Text('Install All Missing'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ).animate().fadeIn(duration: 300.ms),

            const SizedBox(height: 24),

            // Dependency cards
            _DependencyCard(
              title: 'FFmpeg',
              subtitle: 'Video/audio processing engine',
              description:
                  'Required for: HD/4K video merging, audio extraction, format conversion, AI features.',
              icon: Icons.settings_applications_outlined,
              versionAsync: ffmpegVersion,
              provisioningState: ffmpegProvisioning,
              supportsAutoInstall: Platform.isWindows || Platform.isMacOS,
              installHint: Platform.isWindows
                  ? null
                  : 'Install via: brew install ffmpeg',
              onInstall: () => ref.read(ffmpegProvisioningProvider.notifier).provision(),
            ).animate().fadeIn(delay: 100.ms, duration: 300.ms),

            const SizedBox(height: 16),

            _DependencyCard(
              title: 'yt-dlp',
              subtitle: 'Video downloader',
              description:
                  'Required for: Downloading from YouTube, Twitter, Instagram, TikTok, and 1000+ sites.',
              icon: Icons.download_for_offline_outlined,
              versionAsync: ytdlpVersion,
              provisioningState: ytdlpProvisioning,
              supportsAutoInstall: Platform.isWindows || Platform.isMacOS,
              installHint: null,
              onInstall: () => ref.read(ytdlpProvisioningProvider.notifier).provision(),
            ).animate().fadeIn(delay: 200.ms, duration: 300.ms),

            const SizedBox(height: 16),

            _DependencyCard(
              title: 'Python 3.10+',
              subtitle: 'AI & integration runtime',
              description:
                  'Required for: AI vocal separation, AI background removal, browser extension integration.',
              icon: Icons.code_outlined,
              versionAsync: pythonVersion,
              provisioningState: pythonProvisioning,
              supportsAutoInstall: Platform.isWindows,
              installHint: Platform.isWindows
                  ? null
                  : 'Install from python.org or your package manager',
              onInstall: () => ref.read(pythonProvisioningProvider.notifier).provision(),
            ).animate().fadeIn(delay: 300.ms, duration: 300.ms),

            const SizedBox(height: 24),

            // Manual install links
            if (!allInstalled) ...[
              Text('Manual Installation', style: AppTextStyles.headingMedium),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'If automatic installation fails, you can install manually:',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMedium,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ManualInstallLink(
                      name: 'FFmpeg',
                      url: 'https://ffmpeg.org/download.html',
                      description: 'Download the "ffmpeg-git-full.7z" or "ffmpeg-master-latest-win64-gpl-shared.zip"',
                    ),
                    const SizedBox(height: 8),
                    _ManualInstallLink(
                      name: 'yt-dlp',
                      url: 'https://github.com/yt-dlp/yt-dlp/releases/latest',
                      description: 'Download yt-dlp.exe (Windows) or yt-dlp_macos (macOS)',
                    ),
                    const SizedBox(height: 8),
                    _ManualInstallLink(
                      name: 'Python',
                      url: 'https://www.python.org/downloads/',
                      description: 'Download Python 3.10+ installer. Check "Add Python to PATH"',
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 400.ms, duration: 300.ms),
            ],

            const SizedBox(height: 24),

            // After install note
            if (allInstalled) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.success, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'All dependencies are installed! You may need to restart CreatorForge for changes to take effect.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 400.ms, duration: 300.ms),
            ],
          ],
        ),
      ),
    );
  }
}

class _DependencyCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final AsyncValue<String?> versionAsync;
  final ProvisioningState provisioningState;
  final bool supportsAutoInstall;
  final String? installHint;
  final VoidCallback onInstall;

  const _DependencyCard({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.versionAsync,
    required this.provisioningState,
    required this.supportsAutoInstall,
    this.installHint,
    required this.onInstall,
  });

  @override
  Widget build(BuildContext context) {
    final isInstalled = versionAsync.valueOrNull != null;
    final isInstalling = provisioningState.status == ProvisioningStatus.downloading;
    final hasError = provisioningState.status == ProvisioningStatus.error;
    final isDone = provisioningState.status == ProvisioningStatus.done && !isInstalled;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (isInstalled) {
      statusColor = AppColors.success;
      statusText = 'v${versionAsync.value} — Installed';
      statusIcon = Icons.check_circle;
    } else if (isInstalling) {
      statusColor = AppColors.primary;
      statusText = 'Installing…';
      statusIcon = Icons.hourglass_top;
    } else if (hasError) {
      statusColor = AppColors.error;
      statusText = 'Install failed';
      statusIcon = Icons.error_outline;
    } else if (isDone) {
      statusColor = AppColors.success;
      statusText = 'Installed — restart may be required';
      statusIcon = Icons.check_circle;
    } else {
      statusColor = AppColors.error;
      statusText = 'Not installed';
      statusIcon = Icons.cancel_outlined;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isInstalled
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          // Main row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: statusColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(title, style: AppTextStyles.headingSmall),
                          const SizedBox(width: 8),
                          Icon(statusIcon, color: statusColor, size: 16),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      statusText,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (!isInstalled && supportsAutoInstall && !isInstalling && !hasError) ...[
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: onInstall,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          minimumSize: Size.zero,
                        ),
                        child: Text('Install', style: AppTextStyles.labelSmall),
                      ),
                    ],
                    if (hasError) ...[
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () {
                          // Reset error state - we'd need a way to do this
                          // For now just show the error
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                        ),
                        child: Text('Retry', style: AppTextStyles.labelSmall),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Description
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                const SizedBox(width: 52), // Align with content
                Expanded(
                  child: Text(
                    description,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textMedium,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Progress bar
          if (isInstalling) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: provisioningState.progress > 0
                          ? provisioningState.progress
                          : null,
                      minHeight: 4,
                      backgroundColor: statusColor.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    provisioningState.progress > 0
                        ? 'Downloading… ${(provisioningState.progress * 100).toStringAsFixed(0)}%'
                        : 'Downloading…',
                    style: AppTextStyles.caption.copyWith(color: statusColor),
                  ),
                ],
              ),
            ),
          ],

          // Error message
          if (hasError && provisioningState.errorMessage != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  const SizedBox(width: 52),
                  Expanded(
                    child: Text(
                      'Error: ${provisioningState.errorMessage}',
                      style: AppTextStyles.caption.copyWith(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Install hint for unsupported platforms
          if (!isInstalled && !supportsAutoInstall && installHint != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  const SizedBox(width: 52),
                  Expanded(
                    child: Text(
                      installHint!,
                      style: AppTextStyles.caption.copyWith(color: AppColors.textMedium),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ManualInstallLink extends StatelessWidget {
  final String name;
  final String url;
  final String description;

  const _ManualInstallLink({
    required this.name,
    required this.url,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // In a real app, use url_launcher
        // await launchUrl(Uri.parse(url));
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(Icons.open_in_new, size: 16, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  Text(
                    description,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, size: 16, color: AppColors.textLow),
          ],
        ),
      ),
    );
  }
}