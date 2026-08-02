import 'package:flutter/material.dart';

/// Central design tokens for the Grazia luxury stone design system.
/// All visual decisions reference these constants — never hardcode values.
class GTokens {
  GTokens._();

  // ── Spacing (8-point grid) ──
  static const double space0 = 0;
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space7 = 28;
  static const double space8 = 32;
  static const double space10 = 40;
  static const double space12 = 48;
  static const double space16 = 64;
  static const double space20 = 80;
  static const double space24 = 96;

  // ── Border Radius ──
  static const double radiusNone = 0;
  static const double radiusXs = 4;
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radius2xl = 24;
  static const double radius3xl = 32;
  static const double radiusFull = 999;

  // ── Duration (animation) ──
  static const Duration durationInstant = Duration(milliseconds: 100);
  static const Duration durationFast = Duration(milliseconds: 200);
  static const Duration durationNormal = Duration(milliseconds: 300);
  static const Duration durationSlow = Duration(milliseconds: 500);
  static const Duration durationVerySlow = Duration(milliseconds: 800);
  static const Duration durationPage = Duration(milliseconds: 400);

  // ── Curves ──
  static const Curve curveEaseOut = Curves.easeOutCubic;
  static const Curve curveEaseIn = Curves.easeInCubic;
  static const Curve curveEaseInOut = Curves.easeInOutCubic;
  static const Curve curveSpring = Curves.elasticOut;
  static const Curve curveBounce = Curves.bounceOut;
  static const Curve curveSnap = Curves.fastOutSlowIn;

  // ── Blur ──
  static const double blurNone = 0;
  static const double blurXs = 2;
  static const double blurSm = 4;
  static const double blurMd = 8;
  static const double blurLg = 16;
  static const double blurXl = 24;
  static const double blur2xl = 40;

  // ── Opacity ──
  static const double opacityTransparent = 0;
  static const double opacityFaint = 0.05;
  static const double opacityLight = 0.1;
  static const double opacityMedium = 0.3;
  static const double opacityStrong = 0.6;
  static const double opacityOpaque = 1.0;

  // ── Icon Sizes ──
  static const double iconXs = 14;
  static const double iconSm = 18;
  static const double iconMd = 24;
  static const double iconLg = 32;
  static const double iconXl = 48;

  // ── Elevation (glass layers) ──
  static const double elevationNone = 0;
  static const double elevationXs = 1;
  static const double elevationSm = 2;
  static const double elevationMd = 4;
  static const double elevationLg = 8;
  static const double elevationXl = 16;

  // ── Safe Area / Notch Offsets ──
  static const double notchedTopPadding = 48;
  static const double bottomNavHeight = 72;
  static const double tabBarHeight = 52;
}
