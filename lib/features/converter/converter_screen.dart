import 'package:flutter/material.dart';

import '../../widgets/placeholder_screen.dart';

class ConverterScreen extends StatelessWidget {
  const ConverterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Media Converter',
      subtitle: 'Convert between video, audio, and image formats using FFmpeg.',
      icon: Icons.swap_horiz,
    );
  }
}
