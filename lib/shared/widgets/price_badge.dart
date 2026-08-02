import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/tokens.dart';
import '../theme/colors.dart';
import '../theme/shadows.dart';

/// Premium price display badge with gold formatting.
/// Supports regular price, discounted price, and price ranges.
enum GPriceStyle { compact, standard, prominent }

class GPriceBadge extends StatelessWidget {
  final String price;
  final String? originalPrice;
  final String? unit;
  final String? currency;
  final GPriceStyle style;
  final bool showDiscount;

  const GPriceBadge({
    super.key,
    required this.price,
    this.originalPrice,
    this.unit,
    this.currency = '₹',
    this.style = GPriceStyle.standard,
    this.showDiscount = true,
  });

  @override
  Widget build(BuildContext context) {
    final palette = GLuxuryPalettes.gold;
    final hasDiscount = showDiscount && originalPrice != null && originalPrice != price;

    switch (style) {
      case GPriceStyle.compact:
        return _buildCompact(palette, hasDiscount);
      case GPriceStyle.standard:
        return _buildStandard(palette, hasDiscount);
      case GPriceStyle.prominent:
        return _buildProminent(palette, hasDiscount);
    }
  }

  Widget _buildCompact(LuxuryPalette palette, bool hasDiscount) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '$currency$price',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: palette.primary,
          ),
        ),
        if (unit != null)
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 1),
            child: Text(
              '/$unit',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: palette.textTertiary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStandard(LuxuryPalette palette, bool hasDiscount) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: GTokens.space3,
        vertical: GTokens.space2,
      ),
      decoration: BoxDecoration(
        color: palette.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(GTokens.radiusSm),
        border: Border.all(
          color: palette.primary.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$currency$price',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: palette.primary,
            ),
          ),
          if (unit != null)
            Padding(
              padding: const EdgeInsets.only(left: 3),
              child: Text(
                '/$unit',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: palette.textTertiary,
                ),
              ),
            ),
          if (hasDiscount) ...[
            const SizedBox(width: GTokens.space2),
            Text(
              '$currency$originalPrice',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: palette.textTertiary,
                decoration: TextDecoration.lineThrough,
                decorationColor: palette.textTertiary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(width: GTokens.space2),
            _DiscountTag(original: originalPrice!, discounted: price, palette: palette),
          ],
        ],
      ),
    );
  }

  Widget _buildProminent(LuxuryPalette palette, bool hasDiscount) {
    return Container(
      padding: const EdgeInsets.all(GTokens.space4),
      decoration: BoxDecoration(
        gradient: palette.primaryGradient,
        borderRadius: BorderRadius.circular(GTokens.radiusMd),
        boxShadow: GLuxuryShadows.goldGlowSubtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'PRICE',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: palette.background.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: GTokens.space1),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$currency$price',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: palette.background,
                ),
              ),
              if (unit != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 3),
                  child: Text(
                    '/$unit',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: palette.background.withValues(alpha: 0.6),
                    ),
                  ),
                ),
            ],
          ),
          if (hasDiscount)
            Padding(
              padding: const EdgeInsets.only(top: GTokens.space1),
              child: Row(
                children: [
                  Text(
                    '$currency$originalPrice',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      decoration: TextDecoration.lineThrough,
                      color: palette.background.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(width: GTokens.space2),
                  _DiscountTag(original: originalPrice!, discounted: price, palette: palette, dark: true),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DiscountTag extends StatelessWidget {
  final String original;
  final String discounted;
  final LuxuryPalette palette;
  final bool dark;

  const _DiscountTag({
    required this.original,
    required this.discounted,
    required this.palette,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    final origNum = double.tryParse(original.replaceAll(',', '')) ?? 0;
    final discNum = double.tryParse(discounted.replaceAll(',', '')) ?? 0;
    if (origNum <= 0) return const SizedBox.shrink();
    final pct = ((origNum - discNum) / origNum * 100).round();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: GTokens.space1,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: dark
            ? palette.background.withValues(alpha: 0.3)
            : palette.success.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(GTokens.radiusXs),
      ),
      child: Text(
        '$pct% OFF',
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: dark ? palette.background : palette.success,
        ),
      ),
    );
  }
}
