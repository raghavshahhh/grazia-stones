import 'package:flutter/material.dart';

/// Six curated luxury palettes for white-label theming.
/// Each palette provides primary, secondary, accent, surface, text, and gradient sets.
class GLuxuryPalettes {
  GLuxuryPalettes._();

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  1. GOLD — Warm light luxury (Grazia default)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static const GoldPalette gold = GoldPalette();
  static const GoldDarkPalette goldDark = GoldDarkPalette();

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  2. MARBLE — Cool white & silver
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static const MarblePalette marble = MarblePalette();

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  3. OBSIDIAN — Deep black & chrome
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static const ObsidianPalette obsidian = ObsidianPalette();

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  4. PEARL — Soft cream & blush
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static const PearlPalette pearl = PearlPalette();

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  5. ROSE GOLD — Feminine warmth
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static const RoseGoldPalette roseGold = RoseGoldPalette();

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  6. MIDNIGHT — Navy & gold
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static const MidnightPalette midnight = MidnightPalette();
}

// ─── Abstract interface for all palettes ───
abstract class LuxuryPalette {
  const LuxuryPalette();

  Color get primary;
  Color get primaryLight;
  Color get primaryDark;
  Color get secondary;
  Color get accent;
  Color get surface;
  Color get surfaceLight;
  Color get surfaceDark;
  Color get background;
  Color get textPrimary;
  Color get textSecondary;
  Color get textTertiary;
  Color get border;
  Color get borderLight;
  Color get error;
  Color get success;
  Color get warning;

  LinearGradient get primaryGradient;
  LinearGradient get surfaceGradient;
  LinearGradient get heroGradient;
  LinearGradient get shimmerGradient;
}

// ─── 1. GOLD (Light Luxury — Grazia Default) ───
class GoldPalette extends LuxuryPalette {
  const GoldPalette();

  @override Color get primary => const Color(0xFFB99A5B);
  @override Color get primaryLight => const Color(0xFFC8A96E);
  @override Color get primaryDark => const Color(0xFFA68542);
  @override Color get secondary => const Color(0xFF6B6B67);
  @override Color get accent => const Color(0xFFB99A5B);
  @override Color get surface => const Color(0xFFFFFFFF);
  @override Color get surfaceLight => const Color(0xFFFFFFFF);
  @override Color get surfaceDark => const Color(0xFFF4F3EF);
  @override Color get background => const Color(0xFFFAFAF8);
  @override Color get textPrimary => const Color(0xFF171717);
  @override Color get textSecondary => const Color(0xFF6B6B67);
  @override Color get textTertiary => const Color(0xFF9A9A94);
  @override Color get border => const Color(0xFFE8E6E1);
  @override Color get borderLight => const Color(0xFFF0EFEB);
  @override Color get error => const Color(0xFFDC2626);
  @override Color get success => const Color(0xFF16A34A);
  @override Color get warning => const Color(0xFFD97706);

  @override LinearGradient get primaryGradient => const LinearGradient(
    colors: [Color(0xFFC8A96E), Color(0xFFB99A5B)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  @override LinearGradient get surfaceGradient => const LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFFAFAF8)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  @override LinearGradient get heroGradient => LinearGradient(
    colors: [Colors.transparent, const Color(0xFFFAFAF8).withValues(alpha: 0.9)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: const [0.4, 1.0],
  );
  @override LinearGradient get shimmerGradient => LinearGradient(
    colors: [
      const Color(0xFFF4F3EF),
      const Color(0xFFE8E6E1),
      const Color(0xFFF4F3EF),
    ],
    begin: const Alignment(-1.0, -0.3),
    end: const Alignment(1.0, 0.3),
  );
}

// ─── 1B. GOLD DARK (Night Luxury) ───
class GoldDarkPalette extends LuxuryPalette {
  const GoldDarkPalette();

  @override Color get primary => const Color(0xFFC8A96E);
  @override Color get primaryLight => const Color(0xFFD4B97A);
  @override Color get primaryDark => const Color(0xFFB8944F);
  @override Color get secondary => const Color(0xFF8A8A8A);
  @override Color get accent => const Color(0xFFC8A96E);
  @override Color get surface => const Color(0xFF1A1A1A);
  @override Color get surfaceLight => const Color(0xFF222222);
  @override Color get surfaceDark => const Color(0xFF141414);
  @override Color get background => const Color(0xFF0D0D0D);
  @override Color get textPrimary => const Color(0xFFFFFFFF);
  @override Color get textSecondary => const Color(0xFFB0B0B0);
  @override Color get textTertiary => const Color(0xFF6B6B6B);
  @override Color get border => const Color(0xFF2A2A2A);
  @override Color get borderLight => const Color(0xFF3A3A3A);
  @override Color get error => const Color(0xFFEF5350);
  @override Color get success => const Color(0xFF4CAF50);
  @override Color get warning => const Color(0xFFFFA726);

  @override LinearGradient get primaryGradient => const LinearGradient(
    colors: [Color(0xFFB8944F), Color(0xFFC8A96E), Color(0xFFD4B97A)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  @override LinearGradient get surfaceGradient => const LinearGradient(
    colors: [Color(0xFF141414), Color(0xFF1A1A1A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  @override LinearGradient get heroGradient => LinearGradient(
    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: const [0.4, 1.0],
  );
  @override LinearGradient get shimmerGradient => LinearGradient(
    colors: [
      const Color(0xFF1A1A1A),
      const Color(0xFF2A2A2A),
      const Color(0xFF1A1A1A),
    ],
    begin: const Alignment(-1.0, -0.3),
    end: const Alignment(1.0, 0.3),
  );
}

// ─── 2. MARBLE ───
class MarblePalette extends LuxuryPalette {
  const MarblePalette();

  @override Color get primary => const Color(0xFF9CA3AF);
  @override Color get primaryLight => const Color(0xFFD1D5DB);
  @override Color get primaryDark => const Color(0xFF6B7280);
  @override Color get secondary => const Color(0xFFE5E7EB);
  @override Color get accent => const Color(0xFFD1D5DB);
  @override Color get surface => const Color(0xFFF9FAFB);
  @override Color get surfaceLight => const Color(0xFFFFFFFF);
  @override Color get surfaceDark => const Color(0xFFF3F4F6);
  @override Color get background => const Color(0xFFF9FAFB);
  @override Color get textPrimary => const Color(0xFF111827);
  @override Color get textSecondary => const Color(0xFF6B7280);
  @override Color get textTertiary => const Color(0xFF9CA3AF);
  @override Color get border => const Color(0xFFE5E7EB);
  @override Color get borderLight => const Color(0xFFF3F4F6);
  @override Color get error => const Color(0xFFDC2626);
  @override Color get success => const Color(0xFF16A34A);
  @override Color get warning => const Color(0xFFF59E0B);

  @override LinearGradient get primaryGradient => const LinearGradient(
    colors: [Color(0xFF6B7280), Color(0xFF9CA3AF), Color(0xFFD1D5DB)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  @override LinearGradient get surfaceGradient => const LinearGradient(
    colors: [Color(0xFFF9FAFB), Color(0xFFF3F4F6)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  @override LinearGradient get heroGradient => LinearGradient(
    colors: [Colors.transparent, Colors.white.withValues(alpha: 0.9)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: const [0.3, 1.0],
  );
  @override LinearGradient get shimmerGradient => LinearGradient(
    colors: [
      const Color(0xFFF3F4F6),
      const Color(0xFFE5E7EB),
      const Color(0xFFF3F4F6),
    ],
    begin: const Alignment(-1.0, -0.3),
    end: const Alignment(1.0, 0.3),
  );
}

// ─── 3. OBSIDIAN ───
class ObsidianPalette extends LuxuryPalette {
  const ObsidianPalette();

  @override Color get primary => const Color(0xFFE5E7EB);
  @override Color get primaryLight => const Color(0xFFF9FAFB);
  @override Color get primaryDark => const Color(0xFF9CA3AF);
  @override Color get secondary => const Color(0xFF374151);
  @override Color get accent => const Color(0xFF60A5FA);
  @override Color get surface => const Color(0xFF111827);
  @override Color get surfaceLight => const Color(0xFF1F2937);
  @override Color get surfaceDark => const Color(0xFF030712);
  @override Color get background => const Color(0xFF030712);
  @override Color get textPrimary => const Color(0xFFF9FAFB);
  @override Color get textSecondary => const Color(0xFF9CA3AF);
  @override Color get textTertiary => const Color(0xFF6B7280);
  @override Color get border => const Color(0xFF1F2937);
  @override Color get borderLight => const Color(0xFF374151);
  @override Color get error => const Color(0xFFEF4444);
  @override Color get success => const Color(0xFF22C55E);
  @override Color get warning => const Color(0xFFFBBF24);

  @override LinearGradient get primaryGradient => const LinearGradient(
    colors: [Color(0xFF374151), Color(0xFF6B7280), Color(0xFFD1D5DB)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  @override LinearGradient get surfaceGradient => const LinearGradient(
    colors: [Color(0xFF030712), Color(0xFF111827)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  @override LinearGradient get heroGradient => LinearGradient(
    colors: [Colors.transparent, const Color(0xFF030712).withValues(alpha: 0.95)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: const [0.3, 1.0],
  );
  @override LinearGradient get shimmerGradient => LinearGradient(
    colors: [
      const Color(0xFF111827),
      const Color(0xFF1F2937),
      const Color(0xFF111827),
    ],
    begin: const Alignment(-1.0, -0.3),
    end: const Alignment(1.0, 0.3),
  );
}

// ─── 4. PEARL ───
class PearlPalette extends LuxuryPalette {
  const PearlPalette();

  @override Color get primary => const Color(0xFFBE8C63);
  @override Color get primaryLight => const Color(0xFFD4A574);
  @override Color get primaryDark => const Color(0xFFA67B52);
  @override Color get secondary => const Color(0xFFF5E6D3);
  @override Color get accent => const Color(0xFFE8C9A0);
  @override Color get surface => const Color(0xFFFEFBF6);
  @override Color get surfaceLight => const Color(0xFFFFFFFF);
  @override Color get surfaceDark => const Color(0xFFF5EDE3);
  @override Color get background => const Color(0xFFFEFBF6);
  @override Color get textPrimary => const Color(0xFF2C1810);
  @override Color get textSecondary => const Color(0xFF7C5E48);
  @override Color get textTertiary => const Color(0xFFB89E8A);
  @override Color get border => const Color(0xFFE8DDD0);
  @override Color get borderLight => const Color(0xFFF0E8DD);
  @override Color get error => const Color(0xFFC0392B);
  @override Color get success => const Color(0xFF27AE60);
  @override Color get warning => const Color(0xFFF39C12);

  @override LinearGradient get primaryGradient => const LinearGradient(
    colors: [Color(0xFFA67B52), Color(0xFFBE8C63), Color(0xFFD4A574)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  @override LinearGradient get surfaceGradient => const LinearGradient(
    colors: [Color(0xFFFEFBF6), Color(0xFFF5EDE3)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  @override LinearGradient get heroGradient => LinearGradient(
    colors: [Colors.transparent, const Color(0xFFFEFBF6).withValues(alpha: 0.9)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: const [0.3, 1.0],
  );
  @override LinearGradient get shimmerGradient => LinearGradient(
    colors: [
      const Color(0xFFF5EDE3),
      const Color(0xFFE8DDD0),
      const Color(0xFFF5EDE3),
    ],
    begin: const Alignment(-1.0, -0.3),
    end: const Alignment(1.0, 0.3),
  );
}

// ─── 5. ROSE GOLD ───
class RoseGoldPalette extends LuxuryPalette {
  const RoseGoldPalette();

  @override Color get primary => const Color(0xFFB76E79);
  @override Color get primaryLight => const Color(0xFFD4919A);
  @override Color get primaryDark => const Color(0xFF9A5460);
  @override Color get secondary => const Color(0xFFEDCDC2);
  @override Color get accent => const Color(0xFFE8A0B0);
  @override Color get surface => const Color(0xFF1C1417);
  @override Color get surfaceLight => const Color(0xFF2A1E22);
  @override Color get surfaceDark => const Color(0xFF140E11);
  @override Color get background => const Color(0xFF140E11);
  @override Color get textPrimary => const Color(0xFFFDF2F4);
  @override Color get textSecondary => const Color(0xFFD4919A);
  @override Color get textTertiary => const Color(0xFF9A7078);
  @override Color get border => const Color(0xFF3D2A30);
  @override Color get borderLight => const Color(0xFF5A3D44);
  @override Color get error => const Color(0xFFE74C3C);
  @override Color get success => const Color(0xFF2ECC71);
  @override Color get warning => const Color(0xFFF1C40F);

  @override LinearGradient get primaryGradient => const LinearGradient(
    colors: [Color(0xFF9A5460), Color(0xFFB76E79), Color(0xFFD4919A)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  @override LinearGradient get surfaceGradient => const LinearGradient(
    colors: [Color(0xFF140E11), Color(0xFF1C1417)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  @override LinearGradient get heroGradient => LinearGradient(
    colors: [Colors.transparent, const Color(0xFF140E11).withValues(alpha: 0.9)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: const [0.3, 1.0],
  );
  @override LinearGradient get shimmerGradient => LinearGradient(
    colors: [
      const Color(0xFF1C1417),
      const Color(0xFF2A1E22),
      const Color(0xFF1C1417),
    ],
    begin: const Alignment(-1.0, -0.3),
    end: const Alignment(1.0, 0.3),
  );
}

// ─── 6. MIDNIGHT ───
class MidnightPalette extends LuxuryPalette {
  const MidnightPalette();

  @override Color get primary => const Color(0xFFC9A96E);
  @override Color get primaryLight => const Color(0xFFD4B97A);
  @override Color get primaryDark => const Color(0xFFB8944F);
  @override Color get secondary => const Color(0xFF1E3A5F);
  @override Color get accent => const Color(0xFF60A5FA);
  @override Color get surface => const Color(0xFF0F1A2E);
  @override Color get surfaceLight => const Color(0xFF162236);
  @override Color get surfaceDark => const Color(0xFF0A1020);
  @override Color get background => const Color(0xFF0A1020);
  @override Color get textPrimary => const Color(0xFFF0F4F8);
  @override Color get textSecondary => const Color(0xFF94A3B8);
  @override Color get textTertiary => const Color(0xFF64748B);
  @override Color get border => const Color(0xFF1E293B);
  @override Color get borderLight => const Color(0xFF334155);
  @override Color get error => const Color(0xFFEF4444);
  @override Color get success => const Color(0xFF22C55E);
  @override Color get warning => const Color(0xFFFBBF24);

  @override LinearGradient get primaryGradient => const LinearGradient(
    colors: [Color(0xFFB8944F), Color(0xFFC9A96E), Color(0xFFD4B97A)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  @override LinearGradient get surfaceGradient => const LinearGradient(
    colors: [Color(0xFF0A1020), Color(0xFF0F1A2E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  @override LinearGradient get heroGradient => LinearGradient(
    colors: [Colors.transparent, const Color(0xFF0A1020).withValues(alpha: 0.95)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: const [0.3, 1.0],
  );
  @override LinearGradient get shimmerGradient => LinearGradient(
    colors: [
      const Color(0xFF0F1A2E),
      const Color(0xFF162236),
      const Color(0xFF0F1A2E),
    ],
    begin: const Alignment(-1.0, -0.3),
    end: const Alignment(1.0, 0.3),
  );
}
