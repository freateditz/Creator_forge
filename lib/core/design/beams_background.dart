import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A background of drifting diagonal light beams, inspired by the
/// `beams-background` React component. Each beam is a soft radial gradient
/// that fades at both ends and slowly drifts across the canvas.
class BeamsBackground extends StatefulWidget {
  const BeamsBackground({
    super.key,
    this.beamCount = 6,
    this.speed = 0.4,
    this.opacity = 0.55,
  });

  final int beamCount;
  final double speed;
  final double opacity;

  @override
  State<BeamsBackground> createState() => _BeamsBackgroundState();
}

class _BeamsBackgroundState extends State<BeamsBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final _BeamsPainter _painter;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();
    _painter = _BeamsPainter(
      seed: math.Random(7),
      beamCount: widget.beamCount,
      speed: widget.speed,
      opacity: widget.opacity,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _BeamsPainter(
          seed: _painter.seed,
          beamCount: widget.beamCount,
          speed: widget.speed,
          opacity: widget.opacity,
        ),
        child: _BeamsAnimListener(
          controller: _controller,
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// A tiny invisible widget that listens to an [AnimationController] and
/// triggers [CustomPaint] repaints on every tick so the beams drift.
class _BeamsAnimListener extends StatefulWidget {
  const _BeamsAnimListener({required this.controller, required this.child});

  final AnimationController controller;
  final Widget child;

  @override
  State<_BeamsAnimListener> createState() => _BeamsAnimListenerState();
}

class _BeamsAnimListenerState extends State<_BeamsAnimListener> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTick);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _BeamsPainter extends CustomPainter {
  _BeamsPainter({
    required this.seed,
    required this.beamCount,
    required this.speed,
    required this.opacity,
  });

  final math.Random seed;
  final int beamCount;
  final double speed;
  final double opacity;

  late final List<_Beam> _beams = List.generate(
    beamCount,
    (i) => _Beam(seed, i),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final t = DateTime.now().millisecondsSinceEpoch / 1000.0;

    for (final beam in _beams) {
      final phase = (t * speed * beam.frequency) % 1.0;
      final x = size.width * phase;
      final y = size.height * phase;
      final dx = size.width * beam.driftX;
      final dy = size.height * beam.driftY;

      final rect = Rect.fromLTWH(
        x - size.width * 0.35 + dx,
        y - size.height * 0.35 + dy,
        size.width * 0.7,
        size.height * 0.7,
      );

      final gradient = RadialGradient(
        colors: [
          Colors.transparent,
          beam.color.withValues(alpha: opacity * beam.intensity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
        center: Alignment.center,
        radius: 0.7,
      );

      final paint = Paint()
        ..blendMode = BlendMode.screen
        ..shader = gradient.createShader(rect);

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(40)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BeamsPainter oldDelegate) => true;
}

class _Beam {
  _Beam(this.seed, this.index) {
    final r = seed.nextDouble();
    final g = seed.nextDouble();
    final b = seed.nextDouble();
    color = Color.fromARGB(
      255,
      (120 + r * 120).round(),
      (120 + g * 100).round(),
      (160 + b * 120).round(),
    );
    intensity = 0.3 + seed.nextDouble() * 0.7;
    frequency = 0.6 + seed.nextDouble() * 0.8;
    driftX = -0.5 + seed.nextDouble();
    driftY = -0.5 + seed.nextDouble();
  }

  final int index;
  final math.Random seed;
  late final Color color;
  late final double intensity;
  late final double frequency;
  late final double driftX;
  late final double driftY;
}
