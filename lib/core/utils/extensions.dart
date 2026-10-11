import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

extension FileSizeX on int {
  String get humanReadableSize {
    if (this < 1024) return '${this}B';
    if (this < 1024 * 1024) return '${(this / 1024).toStringAsFixed(1)}KB';
    if (this < 1024 * 1024 * 1024) {
      return '${(this / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(this / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB';
  }

  String get humanReadableSpeed => '$humanReadableSize/s';
}

extension DurationSecondsX on int {
  String get humanReadableDuration {
    final d = Duration(seconds: this);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}

extension DateTimeX on DateTime {
  String get formattedDate => DateFormat('MMM d, yyyy').format(this);
  String get formattedDateTime => DateFormat('MMM d, yyyy HH:mm').format(this);
  String get formattedTime => DateFormat('HH:mm:ss').format(this);
}

extension StringX on String {
  String get sanitizedFilename {
    return replaceAll(
      RegExp(r'[<>:"/\\|?*]'),
      '_',
    ).replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  bool get isValidUrl {
    try {
      final uri = Uri.parse(this);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (_) {
      return false;
    }
  }
}

extension ContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  Size get screenSize => MediaQuery.sizeOf(this);
  bool get isSmall => screenSize.width < 900;
}
