import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/core/models/collection.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/core/providers/stone_providers.dart';
import 'package:grazia_stones/shared/widgets/smart_stone_image.dart';
import 'package:grazia_stones/features/wishlist/providers/wishlist_provider.dart';
import 'package:grazia_stones/features/cart/presentation/cart_screen.dart';

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
        appBar: AppBar(
          backgroundColor: palette.background,
          elevation: 0,
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: palette.textPrimary, size: 18),
          ),
        ),
        body: Center(child: CircularProgressIndicator(color: palette.primary)),
      ),
      error: (e, _) => _buildNotFound(context, palette),
      data: (collections) {
        if (collections.isEmpty) {
          return _buildNotFound(context, palette);
        }

        final target = collectionId.toLowerCase().trim();
        final collection = collections.where((c) =>
          c.id.toLowerCase() == target ||
          c.name.toLowerCase().replaceAll(' ', '-') == target ||
          c.name.toLowerCase().contains(target) ||
          target.contains(c.id.toLowerCase())
        ).firstOrNull ?? collections.firstOrNull;

        if (collection == null) {
          return _buildNotFound(context, palette);
        }

        return stonesAsync.when(
          loading: () => Scaffold(
            backgroundColor: palette.background,
            appBar: AppBar(
              backgroundColor: palette.background,
              elevation: 0,
              leading: IconButton(
                onPressed: () => context.pop(),
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: palette.textPrimary, size: 18),
              ),
            ),
            body: Center(child: CircularProgressIndicator(color: palette.primary)),
          ),
          error: (e, _) => _buildScreen(context, ref, palette, collection, []),
          data: (allStones) {
            final colName = collection.name.toLowerCase();
            final stones = allStones.where((s) {
              final sc = s.collection.toLowerCase();
              final scSlug = sc.replaceAll(' ', '-');
              return scSlug == target ||
                     sc == colName ||
                     sc.contains(colName) ||
                     colName.contains(sc) ||
                     (target.length > 4 && (sc.contains(target.split('-').first) || target.contains(scSlug)));
            }).toList();

            final displayStones = stones.isNotEmpty ? stones : allStones.take(6).toList();
            return _buildScreen(context, ref, palette, collection, displayStones);
          },
        );
      },
    );
  }

  Widget _buildNotFound(BuildContext context, LuxuryPalette palette) {
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/collections');
            }
          },
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: palette.textPrimary, size: 18),
        ),
        title: Text(
          'Collection',
          style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.w700, color: palette.textPrimary),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: palette.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: palette.border),
                  ),
                  child: Icon(Icons.grid_off_rounded, color: palette.textTertiary, size: 32),
                ),
                const SizedBox(height: 24),
                Text(
                  'Collection Not Found',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This curated stone collection is currently being updated or has been archived in our seasonal catalogue.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: palette.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.go('/collections'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text('Browse All Collections', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => context.go('/home'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.textPrimary,
                      side: BorderSide(color: palette.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Back to Home', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScreen(
    BuildContext context,
    WidgetRef ref,
    LuxuryPalette palette,
    Collection collection,
    List<Stone> stones,
  ) {
    final image = collection.effectiveBannerImage;

    return Scaffold(
      backgroundColor: palette.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Hero Banner SliverAppBar
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: palette.background,
            elevation: 0,
            leading: IconButton(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/collections');
                }
              },
              icon: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
              ),
            ),
            actions: [
              IconButton(
                onPressed: () => context.push('/catalogue?collectionId=${collection.id}'),
                tooltip: 'Catalogue Filter',
                icon: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.tune_rounded, color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              title: Text(
                collection.name,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.8),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  SmartStoneImage(
                    imageUrl: image.startsWith('http') ? image : null,
                    localAsset: !image.startsWith('http') ? image : null,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    palette: palette,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.25),
                          Colors.black.withValues(alpha: 0.50),
                          Colors.black.withValues(alpha: 0.95),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Series Meta & Architectural Specifications
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Gold Series Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: palette.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: palette.primary.withValues(alpha: 0.6), width: 0.8),
                    ),
                    child: Text(
                      collection.categoryType.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: palette.primary,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    collection.description,
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      color: palette.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Architectural Specifications Card (Directly from PDF Catalogue)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.architecture_rounded, color: palette.primary, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'ARCHITECTURAL SPECIFICATIONS',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                                color: palette.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildSpecPill(palette, Icons.straighten_rounded, 'Dimensions / Sizes', collection.dimensionSpec),
                            const SizedBox(width: 12),
                            _buildSpecPill(palette, Icons.layers_outlined, 'Thickness', collection.thicknessSpec),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _buildSpecPill(palette, Icons.inventory_2_outlined, 'Box Coverage', collection.coverageSpec),
                            const SizedBox(width: 12),
                            _buildSpecPill(palette, Icons.grid_view_rounded, 'Total Surfaces', '${stones.length} Available'),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Quick Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            final targetStoneId = stones.isNotEmpty ? stones.first.id : null;
                            context.push(targetStoneId != null ? '/sample-order?stoneId=$targetStoneId' : '/sample-order');
                          },
                          icon: const Icon(Icons.markunread_mailbox_outlined, size: 16),
                          label: const Text('Sample Box'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: palette.textPrimary,
                            side: BorderSide(color: palette.border),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            final targetStoneId = stones.isNotEmpty ? stones.first.id : null;
                            context.push(targetStoneId != null ? '/quotes/new?stoneId=$targetStoneId' : '/quotes/new');
                          },
                          icon: const Icon(Icons.request_quote_outlined, size: 16),
                          label: const Text('Get Quote'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: palette.primary,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'CURATED SURFACES',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.8,
                          color: palette.textTertiary,
                        ),
                      ),
                      Text(
                        _calculatePriceRange(stones),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: palette.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // Stones Grid
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.of(context).size.width >= 640 ? 3 : 2,
                childAspectRatio: 0.68,
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

  Widget _buildSpecPill(LuxuryPalette palette, IconData icon, String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: palette.surfaceDark.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.border.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: palette.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: palette.textTertiary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _calculatePriceRange(List<Stone> stones) {
    if (stones.isEmpty) return '₹385/sqft';
    final prices = stones.map((s) => s.pricePerSqFt).toList()..sort();
    final min = prices.first.toInt();
    final max = prices.last.toInt();
    return min == max ? '₹$min/sqft' : '₹$min - ₹$max / sqft';
  }
}

class _CollectionStoneCard extends ConsumerWidget {
  final Stone stone;
  final LuxuryPalette palette;

  const _CollectionStoneCard({required this.stone, required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wishlist = ref.watch(wishlistProvider);
    final isWishlisted = wishlist.contains(stone.id);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push('/stones/${stone.id}', extra: stone);
      },
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.25),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image with AR & Cart overlay
              Expanded(
                flex: 4,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    SmartStoneImage(
                      localAsset: stone.images.isNotEmpty ? stone.images.first : null,
                      imageUrl: stone.imageUrl,
                      fit: BoxFit.cover,
                      palette: palette,
                    ),

                    // Top-Right: Wishlist Heart
                    Positioned(
                      top: 7,
                      right: 7,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          ref.read(wishlistProvider.notifier).toggleStone(stone.id);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isWishlisted ? Icons.favorite : Icons.favorite_border,
                            color: isWishlisted ? Colors.red.shade400 : Colors.white,
                            size: 15,
                          ),
                        ),
                      ),
                    ),

                    // Top-Left: Product Code tag
                    Positioned(
                      top: 7,
                      left: 7,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.8),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          stone.productCode,
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFD4AF37),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),

                    // Bottom-Right: 1-Tap Quick Add to Cart
                    Positioned(
                      bottom: 7,
                      right: 7,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          ref.read(cartProvider.notifier).addItem(stone);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${stone.name} added to cart'),
                              duration: const Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: palette.primary,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add_shopping_cart_rounded, size: 11, color: Colors.black),
                              const SizedBox(width: 3),
                              Text(
                                '+ Add',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Bottom-Left: AR badge
                    Positioned(
                      bottom: 7,
                      left: 7,
                      child: GestureDetector(
                        onTap: () => context.push('/live-ai?stoneId=${stone.id}'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.70),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFD4AF37).withValues(alpha: 0.6),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.view_in_ar_rounded, size: 10, color: Color(0xFFD4AF37)),
                              const SizedBox(width: 2.5),
                              Text(
                                'AR',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Product Info
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stone.name,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stone.finish.isNotEmpty ? stone.finish : 'Natural Architectural',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        color: palette.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '₹${stone.pricePerSqFt.toInt()}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: palette.primary,
                          ),
                        ),
                        Text(
                          '/sqft',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: palette.textSecondary,
                          ),
                        ),
                      ],
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
