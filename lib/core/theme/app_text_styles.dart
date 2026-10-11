import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static TextStyle get displayLarge => GoogleFonts.inter(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.textHigh,
    letterSpacing: -0.5,
    decoration: TextDecoration.none,
  );

  static TextStyle get displayMedium => GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.textHigh,
    letterSpacing: -0.3,
    decoration: TextDecoration.none,
  );

  static TextStyle get headingLarge => GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textHigh,
    letterSpacing: -0.2,
    decoration: TextDecoration.none,
  );

  static TextStyle get headingMedium => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textHigh,
    decoration: TextDecoration.none,
  );

  static TextStyle get headingSmall => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textHigh,
    decoration: TextDecoration.none,
  );

  static TextStyle get bodyLarge => GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textHigh,
    decoration: TextDecoration.none,
  );

  static TextStyle get bodyMedium => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textHigh,
    decoration: TextDecoration.none,
  );

  static TextStyle get bodySmall => GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textMedium,
    decoration: TextDecoration.none,
  );

  static TextStyle get labelLarge => GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textHigh,
    letterSpacing: 0.1,
    decoration: TextDecoration.none,
  );

  static TextStyle get labelMedium => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textMedium,
    letterSpacing: 0.2,
    decoration: TextDecoration.none,
  );

  static TextStyle get labelSmall => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textLow,
    letterSpacing: 0.3,
    decoration: TextDecoration.none,
  );

  static TextStyle get caption => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppColors.textLow,
    decoration: TextDecoration.none,
  );

  static TextStyle get mono => GoogleFonts.jetBrainsMono(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textMedium,
    decoration: TextDecoration.none,
  );
}
