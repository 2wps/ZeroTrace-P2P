import 'package:flutter/material.dart';

enum CyberTheme {
  emerald, // Green & Slate
  cyan,    // Neon Cyan & Obsidian
  purple,  // Midnight Purple & Indigo
  amber,   // Tactical Gold & Dark Amber
}

class ThemeColors {
  final Color primary;
  final Color secondary;
  final Color background;
  final Color cardBg;
  final Color bubbleSelf;
  final Color bubblePeer;

  const ThemeColors({
    required this.primary,
    required this.secondary,
    required this.background,
    required this.cardBg,
    required this.bubbleSelf,
    required this.bubblePeer,
  });

  static ThemeColors getTheme(CyberTheme theme) {
    switch (theme) {
      case CyberTheme.cyan:
        return const ThemeColors(
          primary: Color(0xFF06B6D4),
          secondary: Color(0xFF3B82F6),
          background: Color(0xFF050B14),
          cardBg: Color(0xFF0B1728),
          bubbleSelf: Color(0xFF0284C7),
          bubblePeer: Color(0xFF13233A),
        );
      case CyberTheme.purple:
        return const ThemeColors(
          primary: Color(0xFFA855F7),
          secondary: Color(0xFFEC4899),
          background: Color(0xFF090514),
          cardBg: Color(0xFF160E2E),
          bubbleSelf: Color(0xFF7E22CE),
          bubblePeer: Color(0xFF1E133D),
        );
      case CyberTheme.amber:
        return const ThemeColors(
          primary: Color(0xFFF59E0B),
          secondary: Color(0xFFE11D48),
          background: Color(0xFF0E0A05),
          cardBg: Color(0xFF22170B),
          bubbleSelf: Color(0xFFD97706),
          bubblePeer: Color(0xFF2A1C0E),
        );
      case CyberTheme.emerald:
        return const ThemeColors(
          primary: Color(0xFF10B981),
          secondary: Color(0xFF06B6D4),
          background: Color(0xFF07090E),
          cardBg: Color(0xFF0D131F),
          bubbleSelf: Color(0xFF059669),
          bubblePeer: Color(0xFF162032),
        );
    }
  }
}
