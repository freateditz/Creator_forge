import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../providers/app_providers.dart';
import '../../../services/separation/model_manager.dart';

class ModelInstallCard extends ConsumerWidget {
  const ModelInstallCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(modelManagerStateProvider);

    return stateAsync.when(
      loading: () => _buildCard(
        status: ModelInstallStatus.checking,
        detail: 'Checking…',
        onInstall: null,
        onUninstall: null,
        ref: ref,
      ),
      error: (e, _) => _buildCard(
        status: ModelInstallStatus.failed,
        detail: e.toString(),
        onInstall: () => ref.read(modelManagerProvider).install(),
        onUninstall: null,
        ref: ref,
      ),
      data: (state) => _buildCard(
        status: state.status,
        detail: state.statusDetail ?? state.errorMessage,
        hardwareLabel: state.hardwareInfo != null
            ? _hwLabel(state.hardwareInfo!)
            : null,
        onInstall:
            (state.status == ModelInstallStatus.notInstalled ||
                state.status == ModelInstallStatus.failed)
            ? () => ref.read(modelManagerProvider).install()
            : null,
        onUninstall: state.status == ModelInstallStatus.installed
            ? () => ref.read(modelManagerProvider).uninstall()
            : null,
        ref: ref,
      ),
    );
  }

  Widget _buildCard({
    required ModelInstallStatus status,
    required String? detail,
    String? hardwareLabel,
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
              if (status == ModelInstallStatus.installed)
                _chip('Installed', AppColors.success),
              if (status == ModelInstallStatus.notInstalled)
                _chip('Not installed', AppColors.error),
              if (status == ModelInstallStatus.installing)
                _chip('Installing…', AppColors.primary),
              if (status == ModelInstallStatus.checking)
                _chip('Checking…', AppColors.textMedium),
              if (status == ModelInstallStatus.failed)
                _chip('Error', AppColors.error),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'demucs 4.1.0 + htdemucs model',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMedium,
            ),
          ),
          if (hardwareLabel != null) ...[
            const SizedBox(height: 4),
            Text(
              'Accelerator: $hardwareLabel',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textMedium,
              ),
            ),
          ],
          if (detail != null && status != ModelInstallStatus.installed) ...[
            const SizedBox(height: 6),
            Text(
              detail,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textMedium,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (status == ModelInstallStatus.installing) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(),
          ],
          if (status == ModelInstallStatus.notInstalled) ...[
            const SizedBox(height: 10),
            _LicenseNotice(),
            const SizedBox(height: 10),
          ],
          if (onInstall != null || onUninstall != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (onInstall != null)
                  FilledButton.icon(
                    onPressed: onInstall,
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Install (~830 MB)'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      textStyle: AppTextStyles.labelMedium,
                    ),
                  ),
                if (onUninstall != null) ...[
                  const Spacer(),
                  TextButton(
                    onPressed: onUninstall,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textMedium,
                    ),
                    child: const Text('Remove'),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(color: color),
      ),
    );
  }

  Color _statusColor(ModelInstallStatus s) => switch (s) {
    ModelInstallStatus.installed => AppColors.success,
    ModelInstallStatus.failed => AppColors.error,
    ModelInstallStatus.installing ||
    ModelInstallStatus.checking => AppColors.primary,
    _ => AppColors.textMedium,
  };

  IconData _statusIcon(ModelInstallStatus s) => switch (s) {
    ModelInstallStatus.installed => Icons.check_circle_outline_rounded,
    ModelInstallStatus.failed => Icons.error_outline_rounded,
    ModelInstallStatus.installing => Icons.downloading_rounded,
    _ => Icons.info_outline_rounded,
  };

  String _hwLabel(dynamic hw) {
    if (hw.mpsAvailable) return 'Apple MPS (GPU)';
    if (hw.cudaAvailable) {
      final n = hw.cudaDeviceCount;
      return 'NVIDIA CUDA ($n device${n != 1 ? "s" : ""})';
    }
    return 'CPU';
  }
}

class _LicenseNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'License notice',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'The htdemucs model weights are licensed under CC BY-NC 4.0 '
            '(non-commercial use only). By installing, you agree to use '
            'this tool for non-commercial purposes only.',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textMedium,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
