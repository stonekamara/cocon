import 'package:flutter/material.dart';

/// Palette « bleu ciel » : tons doux et apaisants.
class CoconColors {
  static const sky = Color(0xFFEAF6FF); // fond bleu très clair
  static const blue = Color(0xFF4A9ED8); // bleu ciel principal
  static const deepBlue = Color(0xFF1E6FA8); // bleu profond (boutons)
  static const ink = Color(0xFF1F2E3D); // texte principal
  static const cloud = Color(0xFFA8D4F0); // bleu nuage
  static const amber = Color(0xFFE8A25C); // accent chaud (avertissements)
}

ThemeData buildCoconTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: CoconColors.blue,
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme.copyWith(
      surface: CoconColors.sky,
      onSurface: CoconColors.ink,
    ),
    scaffoldBackgroundColor: CoconColors.sky,
    appBarTheme: const AppBarTheme(
      backgroundColor: CoconColors.sky,
      foregroundColor: CoconColors.ink,
      elevation: 0,
      centerTitle: true,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: CoconColors.deepBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}
