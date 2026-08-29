import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/core/models/collection.dart';
import 'package:grazia_stones/core/widgets/error_handler_widget.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/shared/widgets/smart_stone_image.dart';
import 'package:grazia_stones/features/wishlist/providers/wishlist_provider.dart';

/// Catalogue screen with collection-based browsing
/// 
/// Features:
/// - Browse stones by collection
/// - Collection header with banner image
/// - Quick add to cart/wishlist
/// - Category filtering within collection
/// - Backend-driven content from Supabase
class CatalogueScreen extends ConsumerStatefulWidget {
  final String? collectionId;

  const CatalogueScreen({super.key, this.collectionId});

  @override
  ConsumerState<CatalogueScreen> createState() => _CatalogueScreenState();
}

class _CatalogueScreenState extends ConsumerState<CatalogueScreen> {
  List<Stone> _stones = [];
  List<Collection> _collections = [];
  Collection? _selectedCollection;
  String? _selectedCategory;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      final stoneRepo = ref.read(stoneRepositoryProvider);
      final collections = await stoneRepo.getCollections();

      Collection? selectedCollection;
      if (widget.collectionId != null) {
        selectedCollection = collections.firstWhere(
          (c) => c.id == widget.collectionId,
          orElse: () => collections.first,
        );
      } else {
        selectedCollection = collections.isNotEmpty ? collections.first : null;
      }

      final stones = await stoneRepo.getStonesByCollection(selectedCollection?.id ?? '');

      if (mounted) {
        setState(() {
          _collections = collections;
          _selectedCollection = selectedCollection;
          _stones = stones;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadStonesByCollection(Collection collection) async {
    try {
      setState(() {
        _selectedCollection = collection;
        _isLoading = true;
        _selectedCategory = null;
      });

      final stoneRepo = ref.read(stoneRepositoryProvider);
      final stones = await stoneRepo.getStonesByCollection(collection.id);

      if (mounted) {
        setState(() {
          _stones = stones;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
        showErrorSnackbar(context, e);
      }
    }
  }

  List<Stone> get _filteredStones {
    if (_selectedCategory == null || _selectedCategory == 'All') {
      return _stones;
    }
    return _stones.where((s) => s.category == _selectedCategory).toList();
  }

  Set<String> get _availableCategories {
    final categories = _stones.map((s) => s.category).toSet();
    return {'All', ...categories};
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);
    final wishlistState = ref.watch(wishlistProvider);

    return Scaffold(
      backgroundColor: palette.background,
      body: _error != null
          ? ErrorHandlerWidget(error: Exception(_error), onRetry: _loadData)
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // App bar
                SliverAppBar(
                  expandedHeight: 240,
                  pinned: true,
                  backgroundColor: palette.surface,
                  elevation: 0,
                  leading: IconButton(
                    onPressed: () => context.pop(),
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                  actions: [
                    IconButton(
                      onPressed: () => context.push('/search'),
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.search_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    title: _selectedCollection != null
                        ? Text(
                            _selectedCollection!.name,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.8),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                          )
                        : null,
                    background: _selectedCollection?.imageUrl != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                _selectedCollection!.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: palette.primary.withValues(alpha: 0.2),
                                  child: Icon(Icons.collections_outlined, size: 64, color: palette.primary),
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.3),
                                      Colors.black.withValues(alpha: 0.7),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Container(
                            color: palette.primary.withValues(alpha: 0.15),
                            child: Icon(Icons.collections_outlined, size: 64, color: palette.primary),
                          ),
                  ),
                ),

                // Collection tabs
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _CollectionTabsDelegate(
                    collections: _collections,
                    selectedCollection: _selectedCollection,
                    palette: palette,
                    onCollectionSelected: _loadStonesByCollection,
                  ),
                ),

                // Category chips
                if (_availableCategories.length > 1)
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _availableCategories.map((cat) {
                            final isSelected = _selectedCategory == cat || (_selectedCategory == null && cat == 'All');
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedCategory = cat),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? palette.primary : palette.surface,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: isSelected ? palette.primary : palette.border),
                                  ),
                                  child: Text(
                                    cat,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? Colors.white : palette.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),

                // Description
                if (_selectedCollection != null && _selectedCollection!.description.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        _selectedCollection!.description,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: palette.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),

                // Results count
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(
                      '${_filteredStones.length} Products',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                ),

                // Stones grid
                _isLoading
                    ? SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: CircularProgressIndicator(color: palette.primary),
                          ),
                        ),
                      )
                    : _filteredStones.isEmpty
                        ? SliverToBoxAdapter(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(40),
                                child: Column(
                                  children: [
                                    Icon(Icons.inventory_2_outlined, size: 64, color: palette.textTertiary),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No products in this collection',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: palette.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : SliverPadding(
                            padding: const EdgeInsets.all(16),
                            sliver: SliverGrid(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.7,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, i) => _buildStoneCard(_filteredStones[i], palette, wishlistState),
                                childCount: _filteredStones.length,
                              ),
                            ),
                          ),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
    );
  }

  Widget _buildStoneCard(Stone stone, LuxuryPalette palette, WishlistState wishlistState) {
    final isWishlisted = wishlistState.contains(stone.id);

    return GestureDetector(
      onTap: () => context.push('/stone/${stone.id}', extra: stone),
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                  child: SizedBox(
                    height: 160,
                    width: double.infinity,
                    child: SmartStoneImage(
                      localAsset: stone.images.isNotEmpty ? stone.images.first : null,
                      imageUrl: stone.imageUrl,
                      fit: BoxFit.cover,
                      palette: palette,
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ref.read(wishlistProvider.notifier).toggleStone(stone.id);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isWishlisted ? Icons.favorite : Icons.favorite_border,
                        color: isWishlisted ? Colors.red.shade400 : Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                if (stone.isFeatured)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'FEATURED',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stone.name,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${stone.category} • ${stone.finish}',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: palette.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '₹${stone.pricePerSqFt.toInt()}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
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
    );
  }
}

class _CollectionTabsDelegate extends SliverPersistentHeaderDelegate {
  final List<Collection> collections;
  final Collection? selectedCollection;
  final LuxuryPalette palette;
  final Function(Collection) onCollectionSelected;

  _CollectionTabsDelegate({
    required this.collections,
    required this.selectedCollection,
    required this.palette,
    required this.onCollectionSelected,
  });

  @override
  double get minExtent => 60;

  @override
  double get maxExtent => 60;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: palette.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: collections.map((collection) {
            final isSelected = selectedCollection?.id == collection.id;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onCollectionSelected(collection),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? palette.primary : palette.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? palette.primary : palette.border,
                    ),
                  ),
                  child: Text(
                    collection.name,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : palette.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => true;
}
