import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/constants/app_strings.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/shared/theme/typography.dart';
import 'package:grazia_stones/shared/widgets/stone_grid_tile.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/shared/widgets/loading_skeleton.dart';

class HomeTrendingGrid extends ConsumerStatefulWidget {
  const HomeTrendingGrid({super.key});

  @override
  ConsumerState<HomeTrendingGrid> createState() => _HomeTrendingGridState();
}

class _HomeTrendingGridState extends ConsumerState<HomeTrendingGrid> {
  List<Stone>? _stones;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStones();
  }

  Future<void> _loadStones() async {
    setState(() => _isLoading = true);

    try {
      final stoneRepo = ref.read(stoneRepositoryProvider);
      final stones = await stoneRepo.getTrendingStones(limit: 6);

      if (mounted) {
        setState(() {
          _stones = stones;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Trending grid error: $e');
      if (mounted) {
        setState(() {
          _stones = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);

    if (_isLoading) {
      return _buildLoading();
    }

    final stones = _stones ?? [];

    if (stones.isEmpty) {
      return _buildEmpty(palette);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section Header ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: palette.border, width: 0.8),
                ),
                child: Row(
                  children: [
                    // Gold glow dot
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: palette.primaryGradient,
                        boxShadow: [
                          BoxShadow(
                            color: palette.primary.withValues(alpha: 0.4),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      AppStrings.trendingStones,
                      style: GLuxuryTypography.h2.copyWith(color: palette.textPrimary),
                    ),
                    const Spacer(),
                    // "View All" link
                    GestureDetector(
                      onTap: () => context.push('/collections'),
                      child: Row(
                        children: [
                          Text(
                            'View All',
                            style: GLuxuryTypography.bodySmall.copyWith(
                              color: palette.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 12,
                            color: palette.primary,
                          ),
                        ],
                      ),
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

  Widget _buildLoading() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.68,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => const LoadingSkeleton(
          width: double.infinity,
          height: double.infinity,
          borderRadius: 16,
        ),
      ),
    );
  }

  Widget _buildEmpty(LuxuryPalette palette) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Text(
          'No trending stones available',
          style: GLuxuryTypography.bodyMedium.copyWith(
            color: palette.textSecondary,
          ),
        ),
      ),
    );
  }
}
