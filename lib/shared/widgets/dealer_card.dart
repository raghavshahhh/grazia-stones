import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/tokens.dart';
import '../theme/colors.dart';
import 'luxury_card.dart';

/// Dealer info card with avatar, name, location, and action buttons.
class GDealerCard extends StatelessWidget {
  final String name;
  final String? location;
  final String? phone;
  final String? imageUrl;
  final bool isVerified;
  final VoidCallback? onTap;
  final VoidCallback? onCall;
  final VoidCallback? onDirections;

  const GDealerCard({
    super.key,
    required this.name,
    this.location,
    this.phone,
    this.imageUrl,
    this.isVerified = false,
    this.onTap,
    this.onCall,
    this.onDirections,
  });

  @override
  Widget build(BuildContext context) {
    final palette = GLuxuryPalettes.gold;

    return GLuxuryCard(
      onTap: onTap,
      showGoldBorder: isVerified,
      child: Row(
        children: [
          // Avatar
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isVerified ? palette.primary : palette.border,
                width: isVerified ? 2 : 1,
              ),
            ),
            child: ClipOval(
              child: imageUrl != null
                  ? Image.asset(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _buildAvatar(palette),
                    )
                  : _buildAvatar(palette),
            ),
          ),
          const SizedBox(width: GTokens.space3),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: palette.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isVerified) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.verified_rounded,
                        size: 16,
                        color: palette.primary,
                      ),
                    ],
                  ],
                ),
                if (location != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: palette.textTertiary,
                      ),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          location!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: palette.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onCall != null)
                _ActionCircle(
                  icon: Icons.phone_rounded,
                  onTap: onCall,
                  palette: palette,
                ),
              if (onCall != null && onDirections != null)
                const SizedBox(width: GTokens.space2),
              if (onDirections != null)
                _ActionCircle(
                  icon: Icons.directions_rounded,
                  onTap: onDirections,
                  palette: palette,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(LuxuryPalette palette) {
    return Container(
      color: palette.surfaceLight,
      child: Center(
        child: Icon(
          Icons.store_rounded,
          size: 28,
          color: palette.textTertiary.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

class _ActionCircle extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final LuxuryPalette palette;

  const _ActionCircle({
    required this.icon,
    required this.onTap,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: palette.primary.withValues(alpha: 0.1),
          border: Border.all(
            color: palette.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: palette.primary,
        ),
      ),
    );
  }
}
