// Design tokens — the "glass" visual language.
//
// Replaces the flat dark palette with a layered, translucent system:
// deep-space background, frosted-glass surfaces, cyan/violet accents.
// All values are plain constants so they can be referenced from any
// widget without a BuildContext.

import 'package:flutter/material.dart';

class DesignTokens {
  DesignTokens._();

  // ── Backgrounds ────────────────────────────────────────────────────────────
  /// Deepest layer — the app window behind everything.
  static const Color bgDeep = Color(0xFF070912);

  /// Main app background (slightly lighter than deep, subtle vertical gradient).
  static const Color bgApp = Color(0xFF0B0E1A);

  /// Glass surface — translucent, blurred.
  static const Color glass = Color(0x140E1A2E);
  static const Color glassHover = Color(0x1E14283E);
  static const Color glassBorder = Color(0x2AFFFFFF);
  static const Color glassBorderStrong = Color(0x40FFFFFF);

  // ── Accents ────────────────────────────────────────────────────────────────
  static const Color accentCyan = Color(0xFF22D3EE);
  static const Color accentCyanGlow = Color(0x4022D3EE);
  static const Color accentViolet = Color(0xFFA78BFA);
  static const Color accentVioletGlow = Color(0x40A78BFA);
  static const Color accentPink = Color(0xFFF472B6);

  // ── Semantic ───────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF34D399);
  static const Color warning = Color(0xFFFBBF24);
  static const Color error = Color(0xFFF87171);
  static const Color info = Color(0xFF38BDF8);

  // ── Text ───────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textTertiary = Color(0xFF64748B);
  static const Color textDisabled = Color(0xFF475569);

  // ── Gradients ──────────────────────────────────────────────────────────────
  static const LinearGradient bgGradient = LinearGradient(
    colors: [bgDeep, Color(0xFF0F1428), Color(0xFF1A1040)],
    stops: [0.0, 0.55, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [Color(0x26FFFFFF), Color(0x0DFFFFFF)],
    stops: [0.0, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accentCyan, accentViolet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient shinyBorderGradient = LinearGradient(
    colors: [
      Color(0x00FFFFFF),
      Color(0x66FFFFFF),
      Color(0x22FFD7FF),
      Color(0x00FFFFFF),
    ],
    stops: [0.0, 0.35, 0.5, 1.0],
    begin: Alignment(-1.0, -1.0),
    end: Alignment(1.0, 1.0),
  );
}
