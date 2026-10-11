import 'package:flutter/material.dart';

import '../../widgets/placeholder_screen.dart';

class InstagramScreen extends StatelessWidget {
  const InstagramScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Instagram Downloader',
      subtitle: 'Download publicly accessible Instagram Reels and videos.',
      icon: Icons.camera_alt_outlined,
    );
  }
}
