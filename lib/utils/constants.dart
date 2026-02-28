import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF1E3C72);
  static const Color secondary = Color(0xFF2A5298);
  static const Color background = Color(0xFFF5F7FA);
  static const Color accent = Colors.blue;
  static const Color error = Colors.redAccent;
  static const Color success = Colors.green;
}

class AppStyles {
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [AppColors.primary, AppColors.secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static final BorderRadius defaultRadius = BorderRadius.circular(12);
}
