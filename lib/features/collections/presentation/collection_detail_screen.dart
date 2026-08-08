import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/typography.dart';
import 'package:grazia_stones/shared/theme/spacing.dart';
import 'package:grazia_stones/shared/theme/tokens.dart';
import 'package:grazia_stones/core/providers/stone_providers.dart';
import 'package:grazia_stones/shared/widgets/grazia_app_bar.dart';
import 'package:grazia_stones/shared/widgets/smart_stone_image.dart';

class CollectionDetailScreen extends ConsumerWidget {
  final String collectionId;

  const CollectionDetailScreen({super.key, required this.collectionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = GLuxuryPalettes.gold;
    final collectionsAsync = ref.watch(allCollectionsProvider);
    final stonesAsync = ref.watch(allStonesProvider);

    return collectionsAsync.when(
      loading: () => Scaffold(
        backgroundColor: palette.background,
        body: Center(child: CircularProgressIndicator(color: palette.primary)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: palette.background,
        body: Center(child: Text('Failed to load collections', style: GLuxuryTypography.bodyLarge)),
      ),
      data: (collections) {
        final collection = collections.firstWhere(
          (c) => c.id == collectionId,
          orElse: () => collections.first,
        );
        return stonesAsync.when(
          loading: () => Scaffold(
            backgroundColor: palette.background,
            body: Center(child: CircularProgressIndicator(color: palette.primary)),
          ),
          error: (e, _) => Scaffold(
            backgroundColor: palette.background,
            body: Center(child: Text('Failed to load stones', style: GLuxuryTypography.bodyLarge)),
          ),
          data: (allStones) {
            final stones = allStones.where((s) =>
              s.collection.toLowerCase().replaceAll(' ', '-') == collectionId
            ).toList();
            return _buildScreen(context, palette, collection, stones);
          },
        );
      },
    );
  }

  Widget _buildScreen(BuildContext context, LuxuryPalette palette, dynamic collection, List stones) {
    return Scaffold(
      backgroundColor: palette.background,
      appBar: GraziaAppBar(
        title: collection.name.toUpperCase(),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: palette.textSecondary, size: 20),
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Collection Header
          SliverToBoxAdapter(
            child: Padding(
              padding: GLuxurySpacing.horizontalBase,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GLuxurySpacing.gapBase,
                  Text(
                    collection.description,
                    style: GLuxuryTypography.bodyLarge.copyWith(
                      color: palette.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  GLuxurySpacing.gapBase,
                  Row(
                    children: [
                      _buildStatCard(palette, '${stones.length}', 'Products'),
                      const SizedBox(width: 12),
                      _buildStatCard(palette, _calculatePriceRange(stones), 'Price Range'),
                    ],
                  ),
                  GLuxurySpacing.gapXl,
                ],
              ),
            ),
          ),
          
          // Products Grid
          SliverPadding(
            padding: GLuxurySpacing.horizontalBase,
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final stone = stones[index];
                  return _StoneCard(stone: stone);
                },
                childCount: stones.length,
              ),
            ),
          ),
          
          SliverToBoxAdapter(child: GLuxurySpacing.gapXxl),
        ],
      ),
    );
  }

  Widget _buildStatCard(LuxuryPalette palette, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: GLuxuryTypography.h2.copyWith(
                color: palette.primary,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GLuxuryTypography.bodySmall.copyWith(
                color: palette.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _calculatePriceRange(List stones) {
    if (stones.isEmpty) return '₹0';
    final prices = stones.map((s) => s.pricePerSqFt).toList()..sort();
    final min = prices.first.toInt();
    final max = prices.last.toInt();
    return min == max ? '₹$min' : '₹$min-₹$max';
  }
}

class _StoneCard extends StatelessWidget {
  final dynamic stone;
  
  const _StoneCard({required this.stone});

  @override
  Widget build(BuildContext context) {
    final palette = GLuxuryPalettes.gold;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          context.push('/stones/${stone.id}');
        },
        borderRadius: BorderRadius.circular(GTokens.radiusLg),
        child: Container(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(GTokens.radiusLg),
            border: Border.all(color: palette.border, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(GTokens.radiusLg)),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: SmartStoneImage(
                    imageUrl: stone.imageUrl,
                    fit: BoxFit.cover,
                    palette: palette,
                  ),
                ),
              ),
              
              // Info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stone.name,
                        style: GLuxuryTypography.h3.copyWith(
                          color: palette.textPrimary,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        stone.productCode,
                        style: GLuxuryTypography.bodySmall.copyWith(
                          color: palette.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '₹${stone.pricePerSqFt.toInt()}',
                            style: GLuxuryTypography.h3.copyWith(
                              color: palette.primary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios, size: 12, color: palette.textTertiary),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
