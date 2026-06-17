import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const primary = Color(0xFF245B46);
  static const onPrimary = Colors.white;
  static const secondary = Color(0xFFC8893A);
  static const onSecondary = Color(0xFF22170A);
  static const error = Color(0xFFB3261E);
  static const onError = Colors.white;
  static const surface = Color(0xFFF7F5EF);
  static const onSurface = Color(0xFF20231F);
  static const card = Colors.white;
  static const border = Color(0xFFE2DED3);
  static const splendorBlue = Color(0xFF5A5F8F);

  static Color withOpacity(Color color, double opacity) {
    return color.withValues(alpha: opacity);
  }
}
