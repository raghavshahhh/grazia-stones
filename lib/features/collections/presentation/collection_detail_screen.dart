import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:grazia_stones/core/constants/app_colors.dart';
import 'package:grazia_stones/core/services/mock_data_service.dart';
import 'package:grazia_stones/core/theme/glass_theme.dart';
import 'package:grazia_stones/core/theme/text_styles.dart';
import 'package:grazia_stones/shared/widgets/grazia_app_bar.dart';
import 'package:grazia_stones/shared/widgets/stone_grid_tile.dart';

class CollectionDetailScreen extends StatelessWidget {
  final String collectionId;

  const CollectionDetailScreen({super.key, required this.collectionId});

  static const _icons = {
    'royal-marble': '🏛️',
    'heritage': '🏺',
    'contemporary': '◼️',
  };

  @override
  Widget build(BuildContext context) {
    final stones = MockDataService.getStonesByCollection(collectionId);
    final collection = MockDataService.collections.firstWhere(
      (c) => c.id == collectionId,
      orElse: () => MockDataService.collections.first,
    );
    final icon = _icons[collectionId] ?? '🪨';

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      appBar: GraziaAppBar(
        title: collection.name.toUpperCase(),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded, color: AppColors.textSecondary),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Glass Header Card ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: GlassTheme.blurMedium, sigmaY: GlassTheme.blurMedium),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: GlassTheme.glassHeavy.copyWith(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      // Gold gradient icon container with glow
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: AppColors.goldGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.gold.withOpacity(0.25),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(icon, style: const TextStyle(fontSize: 30)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              collection.name.toUpperCase(),
                              style: GraziaTextStyles.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              collection.description,
                              style: GraziaTextStyles.bodySmall.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Stone count badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.white.withOpacity(GlassTheme.opacityLight),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.white.withOpacity(GlassTheme.borderThin),
                                  width: GlassTheme.borderThin,
                                ),
                              ),
                              child: Text(
                                '${stones.length} stones',
                                style: GraziaTextStyles.bodySmall.copyWith(
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
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

          // ── Stone Grid ──
          Expanded(
            child: stones.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: GlassTheme.glassMedium.copyWith(shape: BoxShape.circle),
                          child: const Icon(Icons.collections_bookmark_outlined, size: 36, color: AppColors.textTertiary),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No stones in this collection yet',
                          style: GraziaTextStyles.titleSmall.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
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
                          Navigator.of(context).pushNamed(
                            '/stones/${s.id}',
                            arguments: s.id,
                          );
                        },
                        onWishlist: () {},
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
