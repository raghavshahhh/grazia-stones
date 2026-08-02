import 'package:flutter/material.dart';
import 'tokens.dart';

/// Border radius tokens and pre-built border styles.
class GLuxuryBorders {
  GLuxuryBorders._();

  // ── Radius Tokens ──
  static const double none = GTokens.radiusNone;
  static const double xs = GTokens.radiusXs;
  static const double sm = GTokens.radiusSm;
  static const double md = GTokens.radiusMd;
  static const double lg = GTokens.radiusLg;
  static const double xl = GTokens.radiusXl;
  static const double xxl = GTokens.radius2xl;
  static const double xxxl = GTokens.radius3xl;
  static const double full = GTokens.radiusFull;

  // ── BorderRadius Shortcuts ──
  static const BorderRadius radiusNone = BorderRadius.zero;
  static const BorderRadius radiusXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius radiusSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius radiusMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius radiusLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius radiusXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius radiusXxl = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius radiusXxxl = BorderRadius.all(Radius.circular(xxxl));
  static const BorderRadius radiusFull = BorderRadius.all(Radius.circular(full));

  // ── Directional Radii ──
  static BorderRadius radiusTop = const BorderRadius.vertical(
    top: Radius.circular(lg),
  );

  static BorderRadius radiusBottom = const BorderRadius.vertical(
    bottom: Radius.circular(lg),
  );

  static BorderRadius radiusLeft = const BorderRadius.horizontal(
    left: Radius.circular(lg),
  );

  static BorderRadius radiusRight = const BorderRadius.horizontal(
    right: Radius.circular(lg),
  );

  // ── Pre-built Borders ──
  static BorderSide hairline({Color color = const Color(0xFF2A2A2A)}) =>
      BorderSide(color: color, width: 0.5);

  static BorderSide thin({Color color = const Color(0xFF3A3A3A)}) =>
      BorderSide(color: color, width: 1);

  static BorderSide medium({Color color = const Color(0xFF4A4A4A)}) =>
      BorderSide(color: color, width: 1.5);

  static BorderSide thick({Color color = const Color(0xFF5A5A5A)}) =>
      BorderSide(color: color, width: 2);

  // ── Gold Accent Border ──
  static BorderSide goldAccent = const BorderSide(
    color: Color(0xFFC9A96E),
    width: 1.5,
  );

  static BorderRadius get cardRadius => radiusLg;
  static BorderRadius get dialogRadius => radiusXl;
  static BorderRadius get bottomSheetRadius => const BorderRadius.vertical(
    top: Radius.circular(xxl),
  );
  static BorderRadius get chipRadius => radiusFull;
  static BorderRadius get buttonRadius => radiusFull;
  static BorderRadius get inputRadius => radiusMd;
  static BorderRadius get avatarRadius => radiusFull;
}
