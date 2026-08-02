import 'package:flutter/material.dart';

/// 5 shadow levels + 2 glow variants for the luxury dark theme.
/// All shadows use black with varying alpha for consistency on dark surfaces.
class GLuxuryShadows {
  GLuxuryShadows._();

  // ── Standard Shadows ──

  /// Level 1: Subtle lift (cards at rest)
  static List<BoxShadow> get level1 => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.2),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  /// Level 2: Card hover / elevated element
  static List<BoxShadow> get level2 => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.25),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      blurRadius: 16,
      offset: const Offset(0, 2),
    ),
  ];

  /// Level 3: Modal / floating panel
  static List<BoxShadow> get level3 => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.3),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.15),
      blurRadius: 32,
      offset: const Offset(0, 4),
    ),
  ];

  /// Level 4: Dialog / popover
  static List<BoxShadow> get level4 => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.35),
      blurRadius: 24,
      offset: const Offset(0, 12),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.2),
      blurRadius: 48,
      offset: const Offset(0, 6),
    ),
  ];

  /// Level 5: Full-screen overlay / dramatic
  static List<BoxShadow> get level5 => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.4),
      blurRadius: 32,
      offset: const Offset(0, 16),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.25),
      blurRadius: 64,
      offset: const Offset(0, 8),
    ),
  ];

  // ── Glow Shadows ──

  /// Gold glow — for primary CTAs and highlights
  static List<BoxShadow> get goldGlow => [
    BoxShadow(
      color: const Color(0xFFC9A96E).withValues(alpha: 0.3),
      blurRadius: 20,
      spreadRadius: -2,
    ),
    BoxShadow(
      color: const Color(0xFFC9A96E).withValues(alpha: 0.15),
      blurRadius: 40,
      spreadRadius: -4,
    ),
  ];

  /// Subtle gold glow — for secondary elements
  static List<BoxShadow> get goldGlowSubtle => [
    BoxShadow(
      color: const Color(0xFFC9A96E).withValues(alpha: 0.15),
      blurRadius: 16,
      spreadRadius: -2,
    ),
  ];

  // ── Inset Shadows ──

  /// Inner shadow for pressed/sunken elements
  static List<BoxShadow> get inset => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.3),
      blurRadius: 4,
      offset: const Offset(0, 2),
      spreadRadius: -1,
    ),
  ];

  /// Inner shadow with highlight for glass pressed state
  static List<BoxShadow> get insetGlass => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.2),
      blurRadius: 6,
      offset: const Offset(0, 3),
    ),
    BoxShadow(
      color: Colors.white.withValues(alpha: 0.05),
      blurRadius: 2,
      offset: const Offset(0, -1),
    ),
  ];
}
