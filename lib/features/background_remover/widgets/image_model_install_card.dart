import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../providers/app_providers.dart';
import '../../../services/bg_removal/image_model_manager.dart';

class ImageModelInstallCard extends ConsumerWidget {
  const ImageModelInstallCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(imageModelManagerStateProvider);

    return stateAsync.when(
      loading: () => _buildCard(
        status: ImageModelInstallStatus.checking,
        detail: 'Checking…',
        onInstall: null,
        onUninstall: null,
        ref: ref,
      ),
      error: (e, _) => _buildCard(
        status: ImageModelInstallStatus.failed,
        detail: e.toString(),
        onInstall: () => ref.read(imageModelManagerProvider).install(),
        onUninstall: null,
        ref: ref,
      ),
      data: (state) => _buildCard(
        status: state.status,
        detail: state.statusDetail ?? state.errorMessage,
        runtimeLabel: state.runtimeInfo != null
            ? 'rembg ${state.runtimeInfo!.rembgVersion} · '
                  '${state.runtimeInfo!.acceleratorLabel}'
            : null,
        onInstall:
            (state.status == ImageModelInstallStatus.notInstalled ||
                state.status == ImageModelInstallStatus.failed)
            ? () => ref.read(imageModelManagerProvider).install()
            : null,
        onUninstall: state.status == ImageModelInstallStatus.installed
            ? () => ref.read(imageModelManagerProvider).uninstall()
            : null,
        ref: ref,
      ),
    );
  }

  Widget _buildCard({
    required ImageModelInstallStatus status,
    required String? detail,
    String? runtimeLabel,
    required VoidCallback? onInstall,
    required VoidCallback? onUninstall,
    required WidgetRef ref,
  }) {
    final color = _statusColor(status);
    final icon = _statusIcon(status);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text('AI Engine', style: AppTextStyles.labelMedium),
              const Spacer(),
              if (status == ImageModelInstallStatus.installed)
                _chip('Installed', AppColors.success),
              if (status == ImageModelInstallStatus.notInstalled)
                _chip('Not Installed', AppColors.textMedium),
              if (status == ImageModelInstallStatus.installing)
                _chip('Installing…', AppColors.info),
              if (status == ImageModelInstallStatus.failed)
                _chip('Error', AppColors.error),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'IS-Net General Use (isnet-general-use)',
            style: AppTextStyles.headingSmall,
          ),
          const SizedBox(height: 2),
          Text(
            'High-quality background removal for portraits, products, '
            'and general images.',
            style: AppTextStyles.bodySmall,
          ),
          if (runtimeLabel != null) ...[
            const SizedBox(height: 4),
            Text(runtimeLabel, style: AppTextStyles.caption),
          ],
          if (detail != null) ...[
            const SizedBox(height: 6),
            Text(
              detail,
              style: AppTextStyles.caption.copyWith(
                color: status == ImageModelInstallStatus.failed
                    ? AppColors.error
                    : AppColors.textMedium,
              ),
            ),
          ],
          if (status == ImageModelInstallStatus.installing) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(),
          ],
          // License notice shown when not yet installed
          if (status == ImageModelInstallStatus.notInstalled ||
              status == ImageModelInstallStatus.failed) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.infoSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: AppColors.info,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'License Notice',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.info,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'The IS-Net model weights are distributed under the '
                    'Apache 2.0 license. Processing occurs entirely on your '
                    'device — images are never uploaded to any server.',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Model: ~177 MB · Runtime: rembg (MIT) + ONNX Runtime (MIT)',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (onInstall != null)
                FilledButton.icon(
                  onPressed: status == ImageModelInstallStatus.installing
                      ? null
                      : onInstall,
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Install'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    textStyle: AppTextStyles.labelMedium,
                  ),
                ),
              if (onUninstall != null) ...[
                const Spacer(),
                TextButton.icon(
                  onPressed: onUninstall,
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Remove'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                    textStyle: AppTextStyles.labelMedium,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(label, style: AppTextStyles.labelSmall.copyWith(color: color)),
  );

  Color _statusColor(ImageModelInstallStatus s) => switch (s) {
    ImageModelInstallStatus.installed => AppColors.success,
    ImageModelInstallStatus.installing => AppColors.info,
    ImageModelInstallStatus.failed => AppColors.error,
    _ => AppColors.textMedium,
  };

  IconData _statusIcon(ImageModelInstallStatus s) => switch (s) {
    ImageModelInstallStatus.installed => Icons.check_circle_outline_rounded,
    ImageModelInstallStatus.installing => Icons.downloading_rounded,
    ImageModelInstallStatus.failed => Icons.error_outline_rounded,
    ImageModelInstallStatus.checking => Icons.search_rounded,
    _ => Icons.cloud_download_outlined,
  };
}
