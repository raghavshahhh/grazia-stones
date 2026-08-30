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

/// Comprehensive search and filter screen with backend-driven queries
/// 
/// Features:
/// - Full-text search across stone name, category, collection, tags
/// - Multi-select filters: collections, categories, finishes, price range
/// - Sort options: price, name, newest, popularity
/// - Real-time results from Supabase
/// - Wishlist integration
/// - Grid/List view toggle
/// - Filter persistence
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  List<Stone> _stones = [];
  List<Collection> _collections = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String? _error;

  // Filters
  String _searchQuery = '';
  Set<String> _selectedCollections = {};
  Set<String> _selectedCategories = {};
  Set<String> _selectedFinishes = {};
  double _minPrice = 0;
  double _maxPrice = 10000;
  String _sortBy = 'name'; // name, price_asc, price_desc, newest, popular
  bool _isGridView = true;

  final List<String> _categories = [
    'Ledge Stone',
    'Cultured Stone',
    '3D Wall Panel',
    'Heritage Stone',
    'Modern Cladding',
    'Vintage Brick',
    'Granite Slab',
  ];

  final List<String> _finishes = [
    'Natural',
    'Polished',
    'Honed',
    'Brushed',
    'Flamed',
    'Leathered',
    'Textured',
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() => _isLoading = true);
      
      final stoneRepo = ref.read(stoneRepositoryProvider);
      final collections = await stoneRepo.getCollections();
      final stones = await stoneRepo.getAllStones();

      if (mounted) {
        setState(() {
          _collections = collections;
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

  Future<void> _performSearch() async {
    setState(() => _isSearching = true);

    try {
      final stoneRepo = ref.read(stoneRepositoryProvider);
      var results = await stoneRepo.getAllStones();

      // Apply filters
      results = results.where((stone) {
        // Text search
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          final matchesName = stone.name.toLowerCase().contains(query);
          final matchesCategory = stone.category.toLowerCase().contains(query);
          final matchesCollection = stone.collection.toLowerCase().contains(query);
          final matchesTags = stone.tags.any((tag) => tag.toLowerCase().contains(query));
          
          if (!matchesName && !matchesCategory && !matchesCollection && !matchesTags) {
            return false;
          }
        }

        // Collection filter
        if (_selectedCollections.isNotEmpty) {
          if (!_selectedCollections.contains(stone.collectionId ?? stone.collection)) {
            return false;
          }
        }

        // Category filter
        if (_selectedCategories.isNotEmpty) {
          if (!_selectedCategories.contains(stone.category)) {
            return false;
          }
        }

        // Finish filter
        if (_selectedFinishes.isNotEmpty) {
          if (!_selectedFinishes.contains(stone.finish)) {
            return false;
          }
        }

        // Price filter
        if (stone.pricePerSqFt < _minPrice || stone.pricePerSqFt > _maxPrice) {
          return false;
        }

        return true;
      }).toList();

      // Apply sorting
      switch (_sortBy) {
        case 'price_asc':
          results.sort((a, b) => a.pricePerSqFt.compareTo(b.pricePerSqFt));
          break;
        case 'price_desc':
          results.sort((a, b) => b.pricePerSqFt.compareTo(a.pricePerSqFt));
          break;
        case 'newest':
          results.sort((a, b) => b.id.compareTo(a.id)); // Assumes ID is chronological
          break;
        case 'popular':
          results.sort((a, b) => (b.isFeatured ? 1 : 0).compareTo(a.isFeatured ? 1 : 0));
          break;
        case 'name':
        default:
          results.sort((a, b) => a.name.compareTo(b.name));
      }

      if (mounted) {
        setState(() {
          _stones = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
        showErrorSnackbar(context, e);
      }
    }
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _selectedCollections.clear();
      _selectedCategories.clear();
      _selectedFinishes.clear();
      _minPrice = 0;
      _maxPrice = 10000;
      _sortBy = 'name';
    });
    _performSearch();
  }

  void _showFilterBottomSheet(LuxuryPalette palette) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: palette.border)),
                ),
                child: Row(
                  children: [
                    Text(
                      'Filters & Sort',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _clearFilters();
                      },
                      child: Text('Clear All', style: TextStyle(color: palette.primary)),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: Icon(Icons.close, color: palette.textSecondary),
                    ),
                  ],
                ),
              ),

              // Filter content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sort by
                      _buildFilterSection(
                        'Sort By',
                        palette,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildChip('Name', _sortBy == 'name', palette, () {
                              setModalState(() => _sortBy = 'name');
                              setState(() => _sortBy = 'name');
                            }),
                            _buildChip('Price: Low to High', _sortBy == 'price_asc', palette, () {
                              setModalState(() => _sortBy = 'price_asc');
                              setState(() => _sortBy = 'price_asc');
                            }),
                            _buildChip('Price: High to Low', _sortBy == 'price_desc', palette, () {
                              setModalState(() => _sortBy = 'price_desc');
                              setState(() => _sortBy = 'price_desc');
                            }),
                            _buildChip('Newest', _sortBy == 'newest', palette, () {
                              setModalState(() => _sortBy = 'newest');
                              setState(() => _sortBy = 'newest');
                            }),
                            _buildChip('Popular', _sortBy == 'popular', palette, () {
                              setModalState(() => _sortBy = 'popular');
                              setState(() => _sortBy = 'popular');
                            }),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Collections
                      _buildFilterSection(
                        'Collections',
                        palette,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _collections.map((c) {
                            final isSelected = _selectedCollections.contains(c.id);
                            return _buildChip(c.name, isSelected, palette, () {
                              setModalState(() {
                                if (isSelected) {
                                  _selectedCollections.remove(c.id);
                                } else {
                                  _selectedCollections.add(c.id);
                                }
                              });
                              setState(() {});
                            });
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Categories
                      _buildFilterSection(
                        'Categories',
                        palette,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _categories.map((cat) {
                            final isSelected = _selectedCategories.contains(cat);
                            return _buildChip(cat, isSelected, palette, () {
                              setModalState(() {
                                if (isSelected) {
                                  _selectedCategories.remove(cat);
                                } else {
                                  _selectedCategories.add(cat);
                                }
                              });
                              setState(() {});
                            });
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Finishes
                      _buildFilterSection(
                        'Surface Finish',
                        palette,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _finishes.map((finish) {
                            final isSelected = _selectedFinishes.contains(finish);
                            return _buildChip(finish, isSelected, palette, () {
                              setModalState(() {
                                if (isSelected) {
                                  _selectedFinishes.remove(finish);
                                } else {
                                  _selectedFinishes.add(finish);
                                }
                              });
                              setState(() {});
                            });
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Price range
                      _buildFilterSection(
                        'Price Range (₹/sq ft)',
                        palette,
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('₹${_minPrice.toInt()}', style: TextStyle(color: palette.textSecondary)),
                                Text('₹${_maxPrice.toInt()}', style: TextStyle(color: palette.textSecondary)),
                              ],
                            ),
                            RangeSlider(
                              values: RangeValues(_minPrice, _maxPrice),
                              min: 0,
                              max: 10000,
                              divisions: 100,
                              activeColor: palette.primary,
                              inactiveColor: palette.border,
                              onChanged: (values) {
                                setModalState(() {
                                  _minPrice = values.start;
                                  _maxPrice = values.end;
                                });
                                setState(() {
                                  _minPrice = values.start;
                                  _maxPrice = values.end;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Apply button
              Container(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 16,
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                ),
                decoration: BoxDecoration(
                  color: palette.surface,
                  border: Border(top: BorderSide(color: palette.border)),
                ),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _performSearch();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text(
                    'Apply Filters',
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection(String title, LuxuryPalette palette, {required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildChip(String label, bool isSelected, LuxuryPalette palette, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? palette.primary.withValues(alpha: 0.15) : palette.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? palette.primary : palette.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? palette.primary : palette.textSecondary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);
    final wishlistState = ref.watch(wishlistProvider);
    final activeFilterCount = _selectedCollections.length + 
                             _selectedCategories.length + 
                             _selectedFinishes.length +
                             (_sortBy != 'name' ? 1 : 0);

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
        title: TextField(
          controller: _searchController,
          autofocus: false,
          onChanged: (v) {
            setState(() => _searchQuery = v);
            Future.delayed(const Duration(milliseconds: 500), _performSearch);
          },
          onSubmitted: (_) => _performSearch(),
          style: GoogleFonts.inter(fontSize: 14, color: palette.textPrimary),
          decoration: InputDecoration(
            hintText: 'Search stones, collections...',
            hintStyle: GoogleFonts.inter(fontSize: 13, color: palette.textTertiary),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.clear, color: palette.textSecondary, size: 20),
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
                _performSearch();
              },
            ),
        ],
      ),
      body: _error != null
          ? ErrorHandlerWidget(error: Exception(_error), onRetry: _loadInitialData)
          : Column(
              children: [
                // Filter bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    border: Border(bottom: BorderSide(color: palette.border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showFilterBottomSheet(palette),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: palette.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: palette.border),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.tune_rounded, size: 18, color: palette.primary),
                                const SizedBox(width: 8),
                                Text(
                                  activeFilterCount > 0 ? 'Filters ($activeFilterCount)' : 'Filters',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: palette.textPrimary,
                                  ),
                                ),
                                const Spacer(),
                                Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: palette.textSecondary),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: () => setState(() => _isGridView = !_isGridView),
                        icon: Icon(
                          _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                          color: palette.textPrimary,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),

                // Results
                Expanded(
                  child: _isLoading || _isSearching
                      ? Center(child: CircularProgressIndicator(color: palette.primary))
                      : _stones.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off_rounded, size: 64, color: palette.textTertiary),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No stones found',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: palette.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Try adjusting your filters',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: palette.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : _isGridView
                              ? _buildGridView(palette, wishlistState)
                              : _buildListView(palette, wishlistState),
                ),
              ],
            ),
    );
  }

  Widget _buildGridView(LuxuryPalette palette, WishlistState wishlistState) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: _stones.length,
      itemBuilder: (context, i) => _buildStoneGridCard(_stones[i], palette, wishlistState),
    );
  }

  Widget _buildListView(LuxuryPalette palette, WishlistState wishlistState) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: _stones.length,
      itemBuilder: (context, i) => _buildStoneListCard(_stones[i], palette, wishlistState),
    );
  }

  Widget _buildStoneGridCard(Stone stone, LuxuryPalette palette, WishlistState wishlistState) {
    final isWishlisted = wishlistState.contains(stone.id);

    return GestureDetector(
      onTap: () => context.push('/stones/${stone.id}', extra: stone),
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
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
                    onTap: () => ref.read(wishlistProvider.notifier).toggleStone(stone.id),
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
              ],
            ),

            // Details
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
                    stone.collection,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '₹${stone.pricePerSqFt.toInt()}/sqft',
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
    );
  }

  Widget _buildStoneListCard(Stone stone, LuxuryPalette palette, WishlistState wishlistState) {
    final isWishlisted = wishlistState.contains(stone.id);

    return GestureDetector(
      onTap: () => context.push('/stones/${stone.id}', extra: stone),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 90,
                height: 90,
                child: SmartStoneImage(
                  localAsset: stone.images.isNotEmpty ? stone.images.first : null,
                  imageUrl: stone.imageUrl,
                  fit: BoxFit.cover,
                  palette: palette,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stone.name,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${stone.collection} • ${stone.finish}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '₹${stone.pricePerSqFt.toInt()}/sqft',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: palette.primary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => ref.read(wishlistProvider.notifier).toggleStone(stone.id),
              icon: Icon(
                isWishlisted ? Icons.favorite : Icons.favorite_border,
                color: isWishlisted ? Colors.red.shade400 : palette.textSecondary,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
