import 'dart:ui';

import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// A frosted-glass surface, mirroring the `liquid-glass-navbar` aesthetic:
/// a translucent fill, a subtle inner highlight at the top edge, a soft
/// outer stroke, and a backdrop-filter blur behind it.
class GlassPane extends StatefulWidget {
  const GlassPane({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.blur = 16,
    this.borderOpacity = 0.22,
    this.color,
    this.shadow,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final BorderRadius borderRadius;
  final double blur;
  final double borderOpacity;
  final Color? color;
  final BoxShadow? shadow;

  @override
  State<GlassPane> createState() => _GlassPaneState();
}

class _GlassPaneState extends State<GlassPane> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final baseColor =
        widget.color ??
        (_hovered ? DesignTokens.glassHover : DesignTokens.glass);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        margin: widget.margin,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: widget.borderRadius,
          border: Border.all(
            color: DesignTokens.glassBorder.withValues(
              alpha: widget.borderOpacity,
            ),
            width: 1,
          ),
          boxShadow: widget.shadow != null
              ? [widget.shadow!]
              : [
                  BoxShadow(
                    color: DesignTokens.accentCyanGlow.withValues(alpha: 0.10),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: widget.borderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: widget.blur, sigmaY: widget.blur),
            child: Stack(
              children: [
                // Inner top highlight — the "glass sheen"
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.10),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.white.withValues(alpha: 0.02),
                        ],
                        stops: const [0.0, 0.35, 0.75, 1.0],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
                Padding(padding: widget.padding, child: widget.child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
