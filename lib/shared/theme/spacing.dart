import 'package:flutter/material.dart';

/// 8-point grid spacing system.
/// Use these constants for all padding, margin, and gap values.
class GLuxurySpacing {
  GLuxurySpacing._();

  // ── Named Constants (8pt grid) ──
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double base = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
  static const double huge = 48;
  static const double massive = 64;
  static const double section = 80;
  static const double hero = 96;

  // ── EdgeInsets Shortcuts ──
  static const EdgeInsets paddingXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingBase = EdgeInsets.all(base);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);

  // ── Symmetric EdgeInsets ──
  static const EdgeInsets horizontalSm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets horizontalMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets horizontalBase = EdgeInsets.symmetric(horizontal: base);
  static const EdgeInsets horizontalLg = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets horizontalXl = EdgeInsets.symmetric(horizontal: xl);
  static const EdgeInsets horizontalXxl = EdgeInsets.symmetric(horizontal: xxl);

  static const EdgeInsets verticalSm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets verticalMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets verticalBase = EdgeInsets.symmetric(vertical: base);
  static const EdgeInsets verticalLg = EdgeInsets.symmetric(vertical: lg);
  static const EdgeInsets verticalXl = EdgeInsets.symmetric(vertical: xl);

  // ── Page-Level Padding ──
  static const EdgeInsets pageHorizontal = EdgeInsets.symmetric(horizontal: base);
  static const EdgeInsets pageHorizontalLg = EdgeInsets.symmetric(horizontal: xl);
  static const EdgeInsets pageAll = EdgeInsets.all(base);

  // ── List Item Spacing ──
  static const double listSpacing = sm;
  static const double gridSpacing = md;

  // ── Gap Utilities ──
  static SizedBox get gapXs => const SizedBox(height: xs);
  static SizedBox get gapSm => const SizedBox(height: sm);
  static SizedBox get gapMd => const SizedBox(height: md);
  static SizedBox get gapBase => const SizedBox(height: base);
  static SizedBox get gapLg => const SizedBox(height: lg);
  static SizedBox get gapXl => const SizedBox(height: xl);
  static SizedBox get gapXxl => const SizedBox(height: xxl);

  static SizedBox get gapHorizontalXs => const SizedBox(width: xs);
  static SizedBox get gapHorizontalSm => const SizedBox(width: sm);
  static SizedBox get gapHorizontalMd => const SizedBox(width: md);
  static SizedBox get gapHorizontalBase => const SizedBox(width: base);
  static SizedBox get gapHorizontalLg => const SizedBox(width: lg);
  static SizedBox get gapHorizontalXl => const SizedBox(width: xl);
}
