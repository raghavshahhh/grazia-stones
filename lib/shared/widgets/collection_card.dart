import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/tokens.dart';
import '../theme/colors.dart';
import 'luxury_card.dart';

/// Premium collection card with hero image, gradient overlay, name, and count.
class GCollectionCard extends StatelessWidget {
  final String name;
  final String? description;
  final String? imageUrl;
  final int? stoneCount;
  final VoidCallback? onTap;
  final double? width;
  final double aspectRatio;

  const GCollectionCard({
    super.key,
    required this.name,
    this.description,
    this.imageUrl,
    this.stoneCount,
    this.onTap,
    this.width,
    this.aspectRatio = 16 / 9,
  });

  @override
  Widget build(BuildContext context) {
    final palette = GLuxuryPalettes.gold;

    return GLuxuryCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image
            if (imageUrl != null)
              Image.asset(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildPlaceholder(palette),
              )
            else
              _buildPlaceholder(palette),

            // Hero overlay gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    palette.surfaceDark.withValues(alpha: 0.7),
                    palette.surfaceDark.withValues(alpha: 0.95),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.3, 0.7, 1.0],
                ),
              ),
            ),

            // Content
            Positioned(
              bottom: GTokens.space4,
              left: GTokens.space4,
              right: GTokens.space4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name.toUpperCase(),
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (description != null) ...[
                    const SizedBox(height: GTokens.space1),
                    Text(
                      description!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (stoneCount != null) ...[
                    const SizedBox(height: GTokens.space2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: GTokens.space2,
                        vertical: GTokens.space1,
                      ),
                      decoration: BoxDecoration(
                        color: palette.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(GTokens.radiusFull),
                        border: Border.all(
                          color: palette.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '$stoneCount stones',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                          color: palette.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Gold accent line
            Positioned(
              bottom: 0,
              left: GTokens.space4,
              right: GTokens.space4,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: palette.primaryGradient,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(GTokens.radiusFull),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(LuxuryPalette palette) {
    return Container(
      color: palette.surfaceLight,
      child: Center(
        child: Icon(
          Icons.collections_bookmark_rounded,
          size: 48,
          color: palette.textTertiary.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}
