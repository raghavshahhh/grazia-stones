import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';

import 'smart_stone_image.dart';

/// Premium stone product card with image, name, price, and favorite toggle.
class GStoneCard extends StatelessWidget {
  final String name;
  final String? subtitle;
  final String? imageUrl;
  final String? price;
  final String? unit;
  final bool isFavorite;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteToggle;
  final double? width;
  final double? height;

  const GStoneCard({
    super.key,
    required this.name,
    this.subtitle,
    this.imageUrl,
    this.price,
    this.unit,
    this.isFavorite = false,
    this.onTap,
    this.onFavoriteToggle,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final palette = GLuxuryPalettes.gold;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: palette.border,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image area (Dominant hero)
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    SmartStoneImage(
                      imageUrl: imageUrl,
                      palette: palette,
                      fit: BoxFit.cover,
                    ),

                    // Heart wishlist button
                    if (onFavoriteToggle != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: onFavoriteToggle,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: palette.surface.withValues(alpha: 0.9),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: Icon(
                              isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              size: 16,
                              color: isFavorite ? const Color(0xFFDC2626) : palette.textSecondary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Info area
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: palette.textPrimary,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: palette.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (price != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            '₹$price',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: palette.primary,
                            ),
                          ),
                          if (unit != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Text(
                                unit!,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: palette.textTertiary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
