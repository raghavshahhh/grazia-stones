import 'package:flutter/material.dart';

/// 12 luxury gradient definitions for backgrounds, overlays, buttons, and cards.
class GLuxuryGradients {
  GLuxuryGradients._();

  // ── 1. Gold Horizontal ──
  static const LinearGradient goldHorizontal = LinearGradient(
    colors: [Color(0xFFB8944F), Color(0xFFC9A96E), Color(0xFFD4B97A)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // ── 2. Gold Vertical ──
  static const LinearGradient goldVertical = LinearGradient(
    colors: [Color(0xFFB8944F), Color(0xFFC9A96E), Color(0xFFD4B97A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── 3. Gold Diagonal ──
  static const LinearGradient goldDiagonal = LinearGradient(
    colors: [Color(0xFFB8944F), Color(0xFFD4B97A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── 4. Dark Surface ──
  static LinearGradient darkSurface = LinearGradient(
    colors: [
      const Color(0xFF0D0D0D),
      const Color(0xFF1A1A1A),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── 5. Hero Overlay (image → text) ──
  static LinearGradient heroOverlay = LinearGradient(
    colors: [
      Colors.transparent,
      Colors.black.withValues(alpha: 0.85),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: const [0.3, 1.0],
  );

  // ── 6. Card Overlay ──
  static LinearGradient cardOverlay = LinearGradient(
    colors: [
      Colors.transparent,
      Colors.black.withValues(alpha: 0.6),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── 7. Shimmer ──
  static LinearGradient shimmer = const LinearGradient(
    colors: [
      Color(0xFF1A1A1A),
      Color(0xFF2A2A2A),
      Color(0xFF1A1A1A),
    ],
    begin: Alignment(-1.0, -0.3),
    end: Alignment(1.0, 0.3),
  );

  // ── 8. Rose Gold ──
  static const LinearGradient roseGold = LinearGradient(
    colors: [Color(0xFF9A5460), Color(0xFFB76E79), Color(0xFFD4919A)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // ── 9. Midnight Blue ──
  static const LinearGradient midnight = LinearGradient(
    colors: [Color(0xFF0A1020), Color(0xFF1E3A5F)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── 10. Silver Chrome ──
  static const LinearGradient silverChrome = LinearGradient(
    colors: [Color(0xFF6B7280), Color(0xFF9CA3AF), Color(0xFFD1D5DB)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // ── 11. Glass Highlight ──
  static LinearGradient glassHighlight = LinearGradient(
    colors: [
      Colors.white.withValues(alpha: 0.1),
      Colors.white.withValues(alpha: 0.05),
      Colors.transparent,
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: const [0.0, 0.4, 1.0],
  );

  // ── 12. Radial Vignette ──
  static RadialGradient vignette = RadialGradient(
    colors: [
      Colors.transparent,
      Colors.black.withValues(alpha: 0.4),
    ],
    center: Alignment.center,
    radius: 1.2,
  );

  // ── Utility: Button Gradient on Press ──
  static LinearGradient buttonPressed = LinearGradient(
    colors: [
      const Color(0xFFB8944F).withValues(alpha: 0.8),
      const Color(0xFFC9A96E).withValues(alpha: 0.8),
    ],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}
