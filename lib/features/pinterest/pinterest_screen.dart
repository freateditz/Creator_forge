import 'package:flutter/material.dart';

import '../../widgets/placeholder_screen.dart';

class PinterestScreen extends StatelessWidget {
  const PinterestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Pinterest Downloader',
      subtitle: 'Download publicly accessible Pinterest media.',
      icon: Icons.push_pin_outlined,
    );
  }
}
