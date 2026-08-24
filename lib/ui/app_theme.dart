import 'package:flutter/material.dart';

/// A warm, garden-inspired dark theme with a green accent.
class AppTheme {
  static const _seed = Color(0xFF4CAF50);
  static const _bg = Color(0xFF0E1512);
  static const _surface = Color(0xFF16211C);
  static const _card = Color(0xFF1C2A23);
  static const _text = Color(0xFFE8F1EC);
  static const _muted = Color(0xFF8FA79A);
  static const _accent = Color(0xFF6FBF87);
  static const _warn = Color(0xFFE0A458);

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
          surface: _surface,
          primary: _accent,
          secondary: _warn,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _bg,
          foregroundColor: _text,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: _card,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        chipTheme: const ChipThemeData(
          backgroundColor: _card,
          labelStyle: TextStyle(color: _text),
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: _accent,
          thumbColor: _accent,
        ),
      );

  static const surfaceColor = _surface;
  static const cardColor = _card;
  static const textColor = _text;
  static const mutedColor = _muted;
  static const accentColor = _accent;
  static const warnColor = _warn;
  static const bg = _bg;
}
