import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/tokens.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/models/collection.dart';
import 'package:grazia_stones/shared/widgets/smart_stone_image.dart';

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
            expandedHeight: 140,
            pinned: true,
            elevation: 0,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: palette.background,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
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
                          error: (_, __) => '',
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
            loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
            error: (e, _) => SliverFillRemaining(child: Center(child: Text('Error loading collections'))),
            data: (collections) => SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final collection = collections[index];
                    return _CollectionCard(collection: collection, palette: palette);
                  },
                  childCount: collections.length,
                ),
              ),
            ),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/collections/${collection.id}');
          },
          borderRadius: BorderRadius.circular(GTokens.radiusLg),
          child: Container(
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(GTokens.radiusLg),
              border: Border.all(color: palette.border, width: 0.5),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
                  child: SmartStoneImage(localAsset: _getCollectionImage(), width: 110, height: 110, fit: BoxFit.cover, fallbackColor: palette.surfaceDark),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          collection.name,
                          style: GoogleFonts.playfairDisplay(
                            color: palette.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          collection.description,
                          style: GoogleFonts.inter(
                            color: palette.textSecondary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: palette.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${collection.stoneCount} Surfaces',
                            style: GoogleFonts.inter(
                              color: palette.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(padding: const EdgeInsets.only(right: 12), child: Icon(Icons.chevron_right, color: palette.textTertiary, size: 22)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
