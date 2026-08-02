import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/constants/app_strings.dart';
import 'package:grazia_stones/core/services/mock_data_service.dart';
import 'package:grazia_stones/core/theme/glass_theme.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/typography.dart';
import 'package:grazia_stones/shared/widgets/stone_grid_tile.dart';

class HomeTrendingGrid extends StatelessWidget {
  const HomeTrendingGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final stones = MockDataService.getTrendingStones();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Glass Section Header ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: GlassTheme.blurLight,
                sigmaY: GlassTheme.blurLight,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: GlassTheme.glassLight,
                child: Row(
                  children: [
                    // Gold glow dot
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: GLuxuryPalettes.gold.primaryGradient,
                        boxShadow: [
                          BoxShadow(
                            color: GLuxuryPalettes.gold.primary.withValues(alpha: 0.4),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(AppStrings.trendingStones, style: GLuxuryTypography.h2),
                    const Spacer(),
                    // Subtle "View All" link
                    Text(
                      'View All',
                      style: GLuxuryTypography.bodySmall.copyWith(
                        color: GLuxuryPalettes.gold.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: GLuxuryPalettes.gold.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // ── Grid ──
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.68,
          ),
          itemCount: stones.length,
          itemBuilder: (context, index) {
            final s = stones[index];
            return StoneGridTile(
              stone: s,
              onTap: () {
                HapticFeedback.lightImpact();
                context.push('/stones/${s.id}');
              },
              onWishlist: () {},
            );
          },
        ),
      ],
    );
  }
}
