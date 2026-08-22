import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/core/providers/stone_providers.dart';
import 'package:grazia_stones/shared/widgets/smart_stone_image.dart';

class CollectionDetailScreen extends ConsumerWidget {
  final String collectionId;

  const CollectionDetailScreen({super.key, required this.collectionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(themePaletteProvider);
    final collectionsAsync = ref.watch(allCollectionsProvider);
    final stonesAsync = ref.watch(allStonesProvider);

    return collectionsAsync.when(
      loading: () => Scaffold(
        backgroundColor: palette.background,
        body: Center(child: CircularProgressIndicator(color: palette.primary)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: palette.background,
        body: Center(
          child: Text(
            'Failed to load collection',
            style: GoogleFonts.inter(color: palette.textSecondary),
          ),
        ),
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
            body: Center(
              child: Text(
                'Failed to load surfaces',
                style: GoogleFonts.inter(color: palette.textSecondary),
              ),
            ),
          ),
          data: (allStones) {
            final stones = allStones.where((s) =>
              s.collection.toLowerCase().replaceAll(' ', '-') == collectionId ||
              s.collection.toLowerCase() == collection.name.toLowerCase()
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
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: palette.textPrimary, size: 18),
        ),
        title: Text(
          collection.name,
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Header & Stats
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    collection.description,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: palette.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildStatCard(palette, '${stones.length}', 'Surfaces Available'),
                      const SizedBox(width: 12),
                      _buildStatCard(palette, _calculatePriceRange(stones), 'Price Range / sq ft'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'CURATED SELECTION',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.8,
                      color: palette.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // Stones Grid
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.72,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final stone = stones[index];
                  return _CollectionStoneCard(stone: stone, palette: palette);
                },
                childCount: stones.length,
              ),
            ),
          ),
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
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: palette.textSecondary,
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
    return min == max ? '₹$min' : '₹$min - ₹$max';
  }
}

class _CollectionStoneCard extends StatelessWidget {
  final dynamic stone;
  final LuxuryPalette palette;

  const _CollectionStoneCard({required this.stone, required this.palette});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push('/stones/${stone.id}');
      },
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.border),
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
              Expanded(
                flex: 3,
                child: SmartStoneImage(
                  imageUrl: stone.imageUrl,
                  fit: BoxFit.cover,
                  palette: palette,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stone.name,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: palette.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stone.finish ?? 'Polished',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '₹${stone.pricePerSqFt.toInt()} / sq ft',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: palette.primary,
                      ),
                    ),
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
