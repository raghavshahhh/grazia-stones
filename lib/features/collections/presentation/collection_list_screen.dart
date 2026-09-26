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

/// Fetch collections from repository (Supabase with robust fallback to authentic PDF catalogue dataset)
final collectionsProvider = FutureProvider.autoDispose<List<Collection>>((ref) async {
  final repo = ref.watch(stoneRepositoryProvider);
  return repo.getCollections();
});

class CollectionListScreen extends ConsumerStatefulWidget {
  const CollectionListScreen({super.key});

  @override
  ConsumerState<CollectionListScreen> createState() => _CollectionListScreenState();
}

class _CollectionListScreenState extends ConsumerState<CollectionListScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = [
    'All',
    'Stone Series',
    'Brick Series',
    'Designer 3D',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);
    final collectionsAsync = ref.watch(collectionsProvider);

    return Scaffold(
      backgroundColor: palette.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App Bar with search and title
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
                  padding: const EdgeInsets.fromLTRB(20, 48, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                  data: (c) => '${c.length} Authentic Cultured Series',
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
                          IconButton(
                            onPressed: () => context.push('/catalogue'),
                            tooltip: 'Full Catalogue',
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: palette.surface,
                                shape: BoxShape.circle,
                                border: Border.all(color: palette.border),
                              ),
                              child: Icon(Icons.menu_book_rounded, color: palette.primary, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Search Field
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: palette.border),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                  style: GoogleFonts.inter(fontSize: 14, color: palette.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search 36+ collections (e.g. Mountain, Rustic, Hexa)...',
                    hintStyle: GoogleFonts.inter(fontSize: 13, color: palette.textTertiary),
                    prefixIcon: Icon(Icons.search_rounded, color: palette.primary, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear_rounded, color: palette.textTertiary, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),
          ),

          // Category Chips
          SliverToBoxAdapter(
            child: Container(
              height: 40,
              margin: const EdgeInsets.only(bottom: 12),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                itemBuilder: (context, i) {
                  final cat = _categories[i];
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedCategory = cat);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? palette.primary : palette.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? palette.primary : palette.border,
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            cat,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? Colors.black : palette.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Collections Content
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
              final nonTest = collections.where((c) {
                final name = c.name.toLowerCase();
                return !name.startsWith('test') && !name.contains('test collection');
              }).toList();

              final baseList = nonTest.isEmpty ? collections : nonTest;

              // Filter by category
              final categoryFiltered = baseList.where((c) {
                if (_selectedCategory == 'All') return true;
                final cat = c.categoryType;
                if (_selectedCategory == 'Stone Series') return cat.contains('Cultured Stone');
                if (_selectedCategory == 'Brick Series') return cat.contains('Brick');
                if (_selectedCategory == 'Designer 3D') return cat.contains('Designer 3D');
                return true;
              }).toList();

              // Filter by search query
              final displayList = categoryFiltered.where((c) {
                if (_searchQuery.isEmpty) return true;
                return c.name.toLowerCase().contains(_searchQuery) ||
                       c.description.toLowerCase().contains(_searchQuery) ||
                       c.dimensionSpec.toLowerCase().contains(_searchQuery);
              }).toList();

              if (displayList.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 48, color: palette.textTertiary),
                          const SizedBox(height: 16),
                          Text(
                            'No Collections Found',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: palette.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try changing your search term or category filter.',
                            style: GoogleFonts.inter(fontSize: 13, color: palette.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 140),
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

  @override
  Widget build(BuildContext context) {
    final image = collection.effectiveBannerImage;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      height: 184,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
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
                // Background material texture directly from extracted PDF catalogue banners
                SmartStoneImage(
                  imageUrl: image.startsWith('http') ? image : null,
                  localAsset: !image.startsWith('http') ? image : null,
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
                        Colors.black.withValues(alpha: 0.20),
                        Colors.black.withValues(alpha: 0.60),
                        Colors.black.withValues(alpha: 0.94),
                      ],
                      stops: const [0.0, 0.40, 1.0],
                    ),
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(16),
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
                                // Specs badges row from authentic PDF data
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.65),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: palette.primary.withValues(alpha: 0.8),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        '${collection.stoneCount > 0 ? collection.stoneCount : 6} SURFACES',
                                        style: GoogleFonts.inter(
                                          color: palette.primary,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.55),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.3),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        collection.thicknessSpec,
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.55),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.3),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        collection.coverageSpec,
                                        style: GoogleFonts.inter(
                                          color: Colors.white.withValues(alpha: 0.9),
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  collection.name,
                                  style: GoogleFonts.playfairDisplay(
                                    color: Colors.white,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w800,
                                    height: 1.15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Size: ${collection.dimensionSpec}',
                                  style: GoogleFonts.inter(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 38,
                            height: 38,
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
                              color: Colors.black,
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
