import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Primary Palette (Light Luxury) ──
  static const Color warmWhite = Color(0xFFFAFAF8);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF4F3EF);
  static const Color primaryText = Color(0xFF171717);
  static const Color secondaryText = Color(0xFF6B6B67);
  static const Color mutedText = Color(0xFF9A9A94);
  static const Color borderSubtleLight = Color(0xFFE8E6E1);
  static const Color borderLightVar = Color(0xFFF0EFEB);

  // ── Legacy Dark / Neutral ──
  static const Color black = Color(0xFF0D0D0D);
  static const Color charcoal = Color(0xFF1A1A1A);
  static const Color graphite = Color(0xFF2D2D2D);
  static const Color slate = Color(0xFF3D3D3D);

  // ── Silver / Neutral ──
  static const Color silverDark = Color(0xFF8A8A8A);
  static const Color silverMedium = Color(0xFFB0B0B0);
  static const Color silverLight = Color(0xFFD4D4D4);
  static const Color silverBright = Color(0xFFE8E8E8);
  static const Color white = Color(0xFFFFFFFF);

  // ── Gold Accent ──
  static const Color goldWarm = Color(0xFFB99A5B);
  static const Color goldLight = Color(0xFFC8A96E);
  static const Color goldDark = Color(0xFFA68542);

  // ── Walnut ──
  static const Color walnut = Color(0xFF5C4033);
  static const Color matteWhite = Color(0xFFF5F0EB);

  // ── Aliases (used across screens) ──
  static const Color gold = goldWarm;
  static const Color silver = silverMedium;
  static const Color surfaceElevated = pureWhite;

  // ── Surface / Background ──
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceMedium = Color(0xFFF4F3EF);
  static const Color surfaceDark = Color(0xFFE8E6E1);

  // ── Text ──
  static const Color textPrimary = Color(0xFF171717);
  static const Color textSecondary = Color(0xFF6B6B67);
  static const Color textTertiary = Color(0xFF9A9A94);

  // ── Border ──
  static const Color borderSubtle = Color(0xFFE8E6E1);
  static const Color borderLight = Color(0xFFF0EFEB);

  // ── Semantic ──
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFEF5350);
  static const Color warning = Color(0xFFFFA726);
  static const Color info = Color(0xFF42A5F5);

  // ── Gradients ──
  static const LinearGradient goldGradient = LinearGradient(
    colors: [goldDark, goldWarm, goldLight],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient goldGradientVertical = LinearGradient(
    colors: [goldDark, goldWarm, goldLight],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient silverGradient = LinearGradient(
    colors: [silverDark, silverMedium, silverLight],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static LinearGradient cardOverlay = LinearGradient(
    colors: [
      Colors.transparent,
      Colors.black.withValues(alpha: 0.6),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static LinearGradient heroOverlay = LinearGradient(
    colors: [
      Colors.transparent,
      Colors.black.withValues(alpha: 0.85),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: const [0.4, 1.0],
  );
}
