// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData light([ColorScheme? _]) {
    final scheme =
        ColorScheme.fromSeed(seedColor: const Color(0xFFB2DBB9), brightness: Brightness.light);
    return _build(scheme);
  }

  static ThemeData dark([ColorScheme? _]) {
    final scheme =
        ColorScheme.fromSeed(seedColor: const Color(0xFFB2DBB9), brightness: Brightness.dark);
    return _build(scheme);
  }

  static ThemeData _build(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: GoogleFonts.interTextTheme(),
      navigationBarTheme: const NavigationBarThemeData(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }
}
