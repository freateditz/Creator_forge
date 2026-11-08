import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// A button whose animated conic-gradient border sweeps around its edge —
/// the `shiny-button` look. The sweep is a single continuous rotation driven
/// by a [Ticker], independent of any tap.
class ShinyButton extends StatefulWidget {
  const ShinyButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.width,
    this.height,
    this.borderRadius = 12,
    this.duration = const Duration(seconds: 3),
    this.gradient,
    this.backgroundColor,
    this.foreground,
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
  final LinearGradient? gradient;
  final Color? backgroundColor;
  final Color? foreground;
  final Widget? icon;
  final bool iconBeforeLabel;
  final bool enabled;

  @override
  State<ShinyButton> createState() => _ShinyButtonState();
}

class _ShinyButtonState extends State<ShinyButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

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
    final fg = widget.foreground ?? Colors.white;
    final bg =
        widget.backgroundColor ?? DesignTokens.glass.withValues(alpha: 0.55);

    final child = _buildChild(fg);

    return IgnorePointer(
      ignoring: !widget.enabled,
      child: MouseRegion(
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
            child: _ShinyBorder(
              controller: _controller,
              borderRadius: widget.borderRadius,
              gradient: widget.gradient ?? DesignTokens.shinyBorderGradient,
              child: Container(
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChild(Color fg) {
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
      style: TextStyle(color: fg, fontWeight: FontWeight.w600),
      child: widget.child,
    );
  }
}

/// Paints a continuously-rotating conic gradient as a 1px stroke around
/// the child. This is the "shiny" animated border.
class _ShinyBorder extends AnimatedWidget {
  const _ShinyBorder({
    required this.controller,
    required this.borderRadius,
    required this.gradient,
    required this.child,
  }) : super(listenable: controller);

  final AnimationController controller;
  final double borderRadius;
  final LinearGradient gradient;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ShinyBorderPainter(
        borderRadius: borderRadius,
        gradient: gradient,
        angle: controller.value * math.pi * 2,
      ),
      child: child,
    );
  }
}

class _ShinyBorderPainter extends CustomPainter {
  _ShinyBorderPainter({
    required this.borderRadius,
    required this.gradient,
    required this.angle,
  });

  final double borderRadius;
  final LinearGradient gradient;
  final double angle;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    // Conic gradient rotated by `angle`, drawn as a 1px stroke.
    final sweep = SweepGradient(
      colors: gradient.colors,
      stops: gradient.stops,
      center: Alignment.center,
      startAngle: 0,
      endAngle: math.pi * 2,
      tileMode: TileMode.clamp,
    );
    final shader = sweep.createShader(rect);

    // Rotate the canvas so the sweep's "hot spot" spins.
    final center = rect.center;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.translate(-center.dx, -center.dy);

    final paint = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawRRect(rrect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShinyBorderPainter oldDelegate) =>
      oldDelegate.angle != angle;
}
