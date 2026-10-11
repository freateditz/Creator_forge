import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/separation_request.dart';

class SeparationSettingsPanel extends StatelessWidget {
  final SeparationRequest request;
  final ValueChanged<SeparationRequest> onChanged;
  final VoidCallback? onPickFile;
  final String? selectedFilePath;
  final bool canEnqueue;
  final VoidCallback? onEnqueue;

  const SeparationSettingsPanel({
    super.key,
    required this.request,
    required this.onChanged,
    this.onPickFile,
    this.selectedFilePath,
    required this.canEnqueue,
    this.onEnqueue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Source File', style: AppTextStyles.labelMedium),
          const SizedBox(height: 8),
          _FilePicker(path: selectedFilePath, onPick: onPickFile),
          const SizedBox(height: 16),
          Text('Output Mode', style: AppTextStyles.labelMedium),
          const SizedBox(height: 8),
          _ModeSelector(
            value: request.mode,
            onChanged: (m) => onChanged(request.copyWith(mode: m)),
          ),
          const SizedBox(height: 16),
          Text('Device', style: AppTextStyles.labelMedium),
          const SizedBox(height: 8),
          _DeviceSelector(
            value: request.device,
            onChanged: (d) => onChanged(request.copyWith(device: d)),
          ),
          const SizedBox(height: 16),
          _OutputDirRow(
            path: request.outputDirectory,
            onChanged: (dir) =>
                onChanged(request.copyWith(outputDirectory: dir)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: canEnqueue ? onEnqueue : null,
              icon: const Icon(Icons.graphic_eq_rounded, size: 18),
              label: const Text('Separate'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: AppTextStyles.labelMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilePicker extends StatelessWidget {
  final String? path;
  final VoidCallback? onPick;

  const _FilePicker({this.path, this.onPick});

  @override
  Widget build(BuildContext context) {
    final hasFile = path != null && path!.isNotEmpty;
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasFile
                ? AppColors.primary.withValues(alpha: 0.4)
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              hasFile ? Icons.audio_file_rounded : Icons.file_open_rounded,
              size: 18,
              color: hasFile ? AppColors.primary : AppColors.textMedium,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasFile ? _basename(path!) : 'Tap to pick audio or video file…',
                style: AppTextStyles.bodySmall.copyWith(
                  color: hasFile ? AppColors.textHigh : AppColors.textMedium,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasFile)
              const Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: AppColors.success,
              ),
          ],
        ),
      ),
    );
  }

  String _basename(String p) {
    final idx = p.lastIndexOf(RegExp(r'[/\\]'));
    return idx >= 0 ? p.substring(idx + 1) : p;
  }
}

class _ModeSelector extends StatelessWidget {
  final SeparationMode value;
  final ValueChanged<SeparationMode> onChanged;

  const _ModeSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: SeparationMode.values.map((m) {
        final selected = m == value;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _ToggleChip(
              label: m == SeparationMode.voicePlusInstrumental
                  ? 'Vocals + Instrumental'
                  : 'All Stems',
              selected: selected,
              onTap: () => onChanged(m),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _DeviceSelector extends StatelessWidget {
  final SeparationDevice value;
  final ValueChanged<SeparationDevice> onChanged;

  const _DeviceSelector({required this.value, required this.onChanged});

  static const _labels = {
    SeparationDevice.auto: 'Auto',
    SeparationDevice.cpu: 'CPU',
    SeparationDevice.mps: 'Apple MPS',
    SeparationDevice.cuda: 'CUDA',
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: SeparationDevice.values.map((d) {
        return _ToggleChip(
          label: _labels[d]!,
          selected: d == value,
          onTap: () => onChanged(d),
        );
      }).toList(),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: selected ? AppColors.primary : AppColors.textMedium,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _OutputDirRow extends StatelessWidget {
  final String path;
  final ValueChanged<String> onChanged;

  const _OutputDirRow({required this.path, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Output Folder', style: AppTextStyles.labelMedium),
              const SizedBox(height: 4),
              Text(
                path.isEmpty ? '(none selected)' : path,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textMedium,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: () async {
            final dir = await getDirectoryPath();
            if (dir != null) onChanged(dir);
          },
          icon: const Icon(Icons.folder_open_rounded, size: 16),
          label: const Text('Browse'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textMedium,
            side: const BorderSide(color: AppColors.border),
            textStyle: AppTextStyles.labelSmall,
          ),
        ),
      ],
    );
  }
}
