import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/tokens.dart';
import '../theme/colors.dart';
import 'luxury_card.dart';

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

    return GLuxuryCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image area
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imageUrl != null)
                  Image.asset(
                    imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholder(palette),
                  )
                else
                  _buildPlaceholder(palette),

                // Gradient overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        palette.surfaceDark.withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.5, 1.0],
                    ),
                  ),
                ),

                // Favorite button
                if (onFavoriteToggle != null)
                  Positioned(
                    top: GTokens.space2,
                    right: GTokens.space2,
                    child: GestureDetector(
                      onTap: onFavoriteToggle,
                      child: Container(
                        padding: const EdgeInsets.all(GTokens.space1),
                        decoration: BoxDecoration(
                          color: palette.surfaceDark.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          size: 18,
                          color: isFavorite ? palette.primary : palette.textSecondary,
                        ),
                      ),
                    ),
                  ),

                // Stone name overlay
                Positioned(
                  bottom: GTokens.space3,
                  left: GTokens.space3,
                  right: GTokens.space3,
                  child: Text(
                    name.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Info area
          Padding(
            padding: const EdgeInsets.all(GTokens.space3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: palette.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (price != null) ...[
                  const SizedBox(height: GTokens.space1),
                  Row(
                    children: [
                      Text(
                        '₹$price',
                        style: GoogleFonts.inter(
                          fontSize: 16,
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
                              fontSize: 11,
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
    );
  }

  Widget _buildPlaceholder(LuxuryPalette palette) {
    return Container(
      color: palette.surfaceLight,
      child: Center(
        child: Icon(
          Icons.texture_rounded,
          size: 48,
          color: palette.textTertiary.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}
