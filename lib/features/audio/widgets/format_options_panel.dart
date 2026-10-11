import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/audio_format.dart';
import '../providers/audio_provider.dart';

class FormatOptionsPanel extends ConsumerWidget {
  const FormatOptionsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioScreenProvider);
    final notifier = ref.read(audioScreenProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Output Format', style: AppTextStyles.labelMedium),
          const SizedBox(height: 12),

          // Format selector
          _FormatRow(
            selected: state.outputFormat,
            onChanged: notifier.setOutputFormat,
          ),
          const SizedBox(height: 16),

          // Preset selector
          _PresetRow(
            format: state.outputFormat,
            selectedPresetId: state.presetId,
            onChanged: notifier.setPreset,
          ),
          const SizedBox(height: 16),

          // Lossless note
          if (state.outputFormat.isLossless)
            _InfoNote(
              icon: Icons.info_outline,
              text: state.outputFormat == AudioOutputFormat.flac
                  ? 'FLAC preserves the original audio data exactly. It cannot restore quality lost in prior lossy encoding.'
                  : 'WAV is uncompressed PCM. It cannot restore quality lost in prior lossy encoding.',
            )
          else ...[
            // Bitrate (only for formats that support it)
            if (state.outputFormat.supportsBitRate)
              _BitRateRow(
                format: state.outputFormat,
                presetId: state.presetId,
                customKbps: state.customBitRateKbps,
                onChanged: notifier.setCustomBitRate,
              ),
            if (state.outputFormat.supportsBitRate) const SizedBox(height: 12),

            // Sample rate
            _SampleRateRow(
              format: state.outputFormat,
              presetId: state.presetId,
              customHz: state.customSampleRateHz,
              onChanged: notifier.setCustomSampleRate,
            ),
            const SizedBox(height: 12),

            // Channels
            _ChannelsRow(
              current: state.customChannels,
              onChanged: notifier.setCustomChannels,
            ),

            if (state.outputFormat == AudioOutputFormat.opus)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: _InfoNote(
                  icon: Icons.info_outline,
                  text: 'OPUS requires 48 kHz sample rate; it will be applied automatically.',
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _FormatRow extends StatelessWidget {
  final AudioOutputFormat selected;
  final void Function(AudioOutputFormat) onChanged;

  const _FormatRow({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AudioOutputFormat.values.map((fmt) {
        final isSelected = fmt == selected;
        return GestureDetector(
          onTap: () => onChanged(fmt),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primarySurface
                  : AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Text(
              fmt.label,
              style: AppTextStyles.labelSmall.copyWith(
                color: isSelected ? AppColors.primary : AppColors.textMedium,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PresetRow extends StatelessWidget {
  final AudioOutputFormat format;
  final String? selectedPresetId;
  final void Function(String?) onChanged;

  const _PresetRow({
    required this.format,
    required this.selectedPresetId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final presets = AudioPreset.forFormat(format);
    if (presets.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preset',
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMedium),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: selectedPresetId,
          decoration: _inputDeco(),
          dropdownColor: AppColors.surfaceElevated,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHigh),
          items: presets
              .map(
                (p) => DropdownMenuItem(
                  value: p.id,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(p.label, style: AppTextStyles.bodySmall),
                      Text(
                        p.description,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textLow,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (v) => onChanged(v),
        ),
      ],
    );
  }
}

class _BitRateRow extends StatelessWidget {
  final AudioOutputFormat format;
  final String? presetId;
  final int? customKbps;
  final void Function(int?) onChanged;

  const _BitRateRow({
    required this.format,
    required this.presetId,
    required this.customKbps,
    required this.onChanged,
  });

  static const _options = [64, 96, 128, 160, 192, 256, 320];

  @override
  Widget build(BuildContext context) {
    final effectiveKbps =
        customKbps ??
        (presetId != null
            ? AudioPreset.findById(presetId!)?.bitRateKbps
            : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bitrate',
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMedium),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<int>(
          initialValue: effectiveKbps,
          decoration: _inputDeco(),
          dropdownColor: AppColors.surfaceElevated,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHigh),
          hint: Text(
            'Auto',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textLow),
          ),
          items: _options
              .map((k) => DropdownMenuItem(value: k, child: Text('$k kbps')))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _SampleRateRow extends StatelessWidget {
  final AudioOutputFormat format;
  final String? presetId;
  final int? customHz;
  final void Function(int?) onChanged;

  const _SampleRateRow({
    required this.format,
    required this.presetId,
    required this.customHz,
    required this.onChanged,
  });

  static const _options = [22050, 32000, 44100, 48000, 96000];

  @override
  Widget build(BuildContext context) {
    final isFixed = format.requiresFixedSampleRate;
    final effectiveHz = isFixed
        ? 48000
        : customHz ??
              (presetId != null
                  ? AudioPreset.findById(presetId!)?.sampleRateHz
                  : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sample Rate',
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMedium),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<int>(
          initialValue: effectiveHz,
          decoration: _inputDeco(),
          dropdownColor: AppColors.surfaceElevated,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHigh),
          hint: Text(
            'Auto',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textLow),
          ),
          items: _options
              .map(
                (hz) => DropdownMenuItem(
                  value: hz,
                  enabled: !isFixed || hz == 48000,
                  child: Text(
                    '${(hz / 1000).toStringAsFixed(hz % 1000 == 0 ? 0 : 1)} kHz',
                  ),
                ),
              )
              .toList(),
          onChanged: isFixed ? null : onChanged,
        ),
      ],
    );
  }
}

class _ChannelsRow extends StatelessWidget {
  final String? current;
  final void Function(String?) onChanged;

  const _ChannelsRow({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Channels',
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMedium),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String?>(
          initialValue: current,
          decoration: _inputDeco(),
          dropdownColor: AppColors.surfaceElevated,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHigh),
          items: const [
            DropdownMenuItem(value: null, child: Text('Preserve original')),
            DropdownMenuItem(value: 'stereo', child: Text('Stereo (2ch)')),
            DropdownMenuItem(value: 'mono', child: Text('Mono (1ch)')),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _InfoNote extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoNote({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.infoSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppColors.info),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _inputDeco() => InputDecoration(
  isDense: true,
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  filled: true,
  fillColor: AppColors.surfaceElevated,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: AppColors.border),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: AppColors.border),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: AppColors.primary),
  ),
);
