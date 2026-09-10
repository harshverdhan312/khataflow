import 'package:flutter/material.dart';

class AppColors {
  // Brand Primary & Accents (Vibrant Blue for High Contrast in Dark Mode)
  static const Color primary = Color(0xFF3B82F6); // Electric / Bright Blue
  static const Color primaryLight = Color(0xFF60A5FA);
  static const Color primaryDark = Color(0xFF1D4ED8);
  
  // Secondary / Accent (Teal / Emerald for Financial Trust)
  static const Color accent = Color(0xFF14B8A6);
  static const Color accentLight = Color(0xFF2DD4BF);

  // Status & Financial Indicators (High Contrast)
  static const Color outstandingRed = Color(0xFFEF4444);
  static const Color settledGreen = Color(0xFF22C55E);
  static const Color pendingAmber = Color(0xFFF59E0B);
  static const Color infoBlue = Color(0xFF3B82F6);

  // Neutral Scales (Dark Theme Tokens)
  static const Color surfaceDark = Color(0xFF0B0F17); // Slate 950 deep background
  static const Color cardDark = Color(0xFF161E2E); // Slate 900 card surface
  static const Color textPrimaryDark = Color(0xFFF8FAFC); // Slate 50 high contrast text
  static const Color textSecondaryDark = Color(0xFF94A3B8); // Slate 400 secondary text
  static const Color borderDark = Color(0xFF26334D); // Slate 800 borders
  static const Color dividerDark = Color(0xFF1E293B); // Slate 800 dividers

  // Semantic Aliases for Dark Theme
  static const Color background = surfaceDark;
  static const Color surface = cardDark;
  static const Color textPrimary = textPrimaryDark;
  static const Color textSecondary = textSecondaryDark;
  static const Color border = borderDark;
  static const Color divider = dividerDark;

  // Backward Compatibility Aliases (re-routed to Dark scales to eliminate light-theme color bugs)
  static const Color surfaceLight = surfaceDark;
  static const Color cardLight = cardDark;
  static const Color textPrimaryLight = textPrimaryDark;
  static const Color textSecondaryLight = textSecondaryDark;
  static const Color borderLight = borderDark;
  static const Color dividerLight = dividerDark;
}
