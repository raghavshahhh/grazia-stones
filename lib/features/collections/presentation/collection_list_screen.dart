import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/models/collection.dart';
import 'package:grazia_stones/shared/widgets/smart_stone_image.dart';
import 'package:grazia_stones/shared/widgets/loading_skeleton.dart';

/// Fetch collections from Supabase
final collectionsProvider = FutureProvider.autoDispose<List<Collection>>((ref) async {
  final repo = ref.watch(stoneRepositoryProvider);
  return repo.getCollections();
});

class CollectionListScreen extends ConsumerWidget {
  const CollectionListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(themePaletteProvider);
    final collectionsAsync = ref.watch(collectionsProvider);

    return Scaffold(
      backgroundColor: palette.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            backgroundColor: palette.background,
            expandedHeight: 120,
            pinned: true,
            elevation: 0,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: palette.background,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 48, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Collections',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        collectionsAsync.when(
                          data: (c) => '${c.length} Curated Series',
                          loading: () => 'Loading...',
                          error: (_, _) => '',
                        ),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: palette.primary,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          collectionsAsync.when(
            loading: () => const SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: SliverToBoxAdapter(
                child: CollectionListSkeleton(),
              ),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_off_rounded, size: 48, color: palette.textTertiary),
                      const SizedBox(height: 16),
                      Text(
                        'Unable to Load Collections',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please check your connection and try again.',
                        style: GoogleFonts.inter(fontSize: 13, color: palette.textSecondary),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () => ref.invalidate(collectionsProvider),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: palette.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            data: (collections) {
              final filteredCollections = collections.where((c) {
                final name = c.name.toLowerCase();
                return !name.startsWith('test') && !name.contains('test collection');
              }).toList();

              final displayList = filteredCollections.isEmpty ? collections : filteredCollections;

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final collection = displayList[index];
                      return _CollectionCard(collection: collection, palette: palette);
                    },
                    childCount: displayList.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  final Collection collection;
  final LuxuryPalette palette;

  const _CollectionCard({required this.collection, required this.palette});

  String? _getCollectionImage() {
    if (collection.imageUrl != null && collection.imageUrl!.isNotEmpty) {
      return collection.imageUrl;
    }
    final name = collection.name.toLowerCase();
    if (name.contains('grande')) return 'assets/images/grande_ledge_ta02.png';
    if (name.contains('classic')) return 'assets/images/classic_ledge_07.png';
    if (name.contains('opus')) return 'assets/images/opus_ledge_15.png';
    if (name.contains('verona')) return 'assets/images/verona_3d.png';
    if (name.contains('athena')) return 'assets/images/athena_3d.png';
    if (name.contains('vantage')) return 'assets/images/vantage_v12.png';
    if (name.contains('mountain')) return 'assets/images/mountain_ledge_m08.png';
    return 'assets/images/placeholder_stone.png';
  }

  @override
  Widget build(BuildContext context) {
    final image = _getCollectionImage();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      height: 170,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/collections/${collection.id}');
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background material texture
                SmartStoneImage(
                  imageUrl: image?.startsWith('http') == true ? image : null,
                  localAsset: image?.startsWith('http') == false ? image : null,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  fallbackColor: palette.surfaceDark,
                ),

                // Luxury dark gradient overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.25),
                        Colors.black.withValues(alpha: 0.65),
                        Colors.black.withValues(alpha: 0.92),
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Gold badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: palette.primary.withValues(alpha: 0.6),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    '${collection.stoneCount} SURFACES',
                                    style: GoogleFonts.inter(
                                      color: palette.primary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  collection.name,
                                  style: GoogleFonts.playfairDisplay(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    height: 1.15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (collection.description.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    collection.description,
                                    style: GoogleFonts.inter(
                                      color: Colors.white.withValues(alpha: 0.85),
                                      fontSize: 12,
                                      height: 1.35,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: palette.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: palette.primary.withValues(alpha: 0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 18,
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
      ),
    );
  }
}
