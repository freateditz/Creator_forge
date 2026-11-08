import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// A 3D-layered pill button with a metallic, shader-driven surface — the
/// `liquid-metal-button` look. The highlight layer is a slowly rotating
/// sheen that sits above the base metal.
class LiquidMetalButton extends StatefulWidget {
  const LiquidMetalButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.width,
    this.height,
    this.borderRadius = 100,
    this.duration = const Duration(seconds: 6),
    this.metalColor,
    this.accentColor,
    this.icon,
    this.iconBeforeLabel = false,
    this.enabled = true,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final double? width;
  final double? height;
  final double borderRadius;
  final Duration duration;
  final Color? metalColor;
  final Color? accentColor;
  final Widget? icon;
  final bool iconBeforeLabel;
  final bool enabled;

  @override
  State<LiquidMetalButton> createState() => _LiquidMetalButtonState();
}

class _LiquidMetalButtonState extends State<LiquidMetalButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final metal = widget.metalColor ?? const Color(0xFF2A2A36);
    final accent = widget.accentColor ?? DesignTokens.accentViolet;

    final child = _buildChild();

    return IgnorePointer(
      ignoring: !widget.enabled,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: widget.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: Listener(
          onPointerDown: (_) => _controller.stop(),
          onPointerUp: (_) => _controller.repeat(),
          onPointerCancel: (_) => _controller.repeat(),
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: _MetalSheen(
              controller: _controller,
              borderRadius: widget.borderRadius,
              metalColor: metal,
              accentColor: accent,
              hovered: _hovered,
              child: Container(
                decoration: BoxDecoration(
                  color: metal,
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: _hovered ? 28 : 18,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChild() {
    final fg = Colors.white;
    if (widget.icon != null) {
      return widget.iconBeforeLabel
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                widget.icon!,
                const SizedBox(width: 8),
                widget.child,
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                widget.child,
                const SizedBox(width: 8),
                widget.icon!,
              ],
            );
    }
    return DefaultTextStyle(
      style: TextStyle(color: fg, fontWeight: FontWeight.w700),
      child: widget.child,
    );
  }
}

/// A rotating metallic sheen painted on top of the base surface.
class _MetalSheen extends AnimatedWidget {
  const _MetalSheen({
    required this.controller,
    required this.borderRadius,
    required this.metalColor,
    required this.accentColor,
    required this.hovered,
    required this.child,
  }) : super(listenable: controller);

  final AnimationController controller;
  final double borderRadius;
  final Color metalColor;
  final Color accentColor;
  final bool hovered;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MetalSheenPainter(
        borderRadius: borderRadius,
        metalColor: metalColor,
        accentColor: accentColor,
        hovered: hovered,
        angle: controller.value * math.pi * 2,
      ),
      child: child,
    );
  }
}

class _MetalSheenPainter extends CustomPainter {
  _MetalSheenPainter({
    required this.borderRadius,
    required this.metalColor,
    required this.accentColor,
    required this.hovered,
    required this.angle,
  });

  final double borderRadius;
  final Color metalColor;
  final Color accentColor;
  final bool hovered;
  final double angle;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.translate(-center.dx, -center.dy);

    final sheen = LinearGradient(
      colors: [
        Colors.transparent,
        Colors.white.withValues(alpha: hovered ? 0.35 : 0.18),
        Colors.transparent,
      ],
      stops: const [0.0, 0.5, 1.0],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final paint = Paint()..shader = sheen.createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(borderRadius)),
      paint,
    );

    // Subtle accent rim
    final rim = LinearGradient(
      colors: [
        Colors.transparent,
        accentColor.withValues(alpha: hovered ? 0.6 : 0.3),
        Colors.transparent,
      ],
      stops: const [0.0, 0.5, 1.0],
      begin: Alignment.bottomRight,
      end: Alignment.topLeft,
    );
    paint.shader = rim.createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(borderRadius)),
      paint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_MetalSheenPainter oldDelegate) =>
      oldDelegate.angle != angle || oldDelegate.hovered != hovered;
}
