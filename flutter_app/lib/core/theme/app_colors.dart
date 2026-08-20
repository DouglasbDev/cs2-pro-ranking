import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const background = Color(0xFF0D0D0D);
  static const surface = Color(0xFF161616);
  static const surfaceAlt = Color(0xFF1A1A1A);
  static const surfaceRowAlt = Color(0xFF141414);

  static const gold = Color(0xFFF2C94C);
  static const goldDim = Color(0x40F2C94C);

  /// Team crests are frequently monochrome art on a transparent background
  /// (built for light UIs) — this backs them so they stay visible against
  /// the dark theme instead of vanishing into it.
  static const logoBackground = Color(0xFFF2F2F2);

  static const textPrimary = Color(0xFFF5F5F5);
  static const textSecondary = Color(0xFF8A8A8A);
  static const divider = Color(0xFF262626);

  static const positive = Color(0xFF6FCF97);
  static const negative = Color(0xFFEB5757);
}
