import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/shared/widgets/smart_stone_image.dart';
import 'package:grazia_stones/core/providers/stone_providers.dart';
import 'package:grazia_stones/core/models/stone.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _selectedFilters = ['All'];
  List<Stone> _filteredStones = [];

  final List<String> _allFilters = [
    'All',
    'Marble',
    'Travertine',
    'Polished',
    'Honed',
    'Leathered',
    'Under ₹200',
    '₹200-₹300',
    'Over ₹300',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterStones);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterStones);
    _searchController.dispose();
    super.dispose();
  }

  void _filterStones() {
    final stones = ref.read(allStonesProvider).valueOrNull ?? [];
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredStones = stones.where((stone) {
        final matchesQuery = query.isEmpty ||
            stone.name.toLowerCase().contains(query) ||
            stone.collection.toLowerCase().contains(query) ||
            stone.description.toLowerCase().contains(query) ||
            stone.finish.toLowerCase().contains(query) ||
            (stone.origin?.toLowerCase().contains(query) ?? false);

        bool matchesFilters = _selectedFilters.contains('All') || _selectedFilters.isEmpty;

        if (!matchesFilters) {
          for (final filter in _selectedFilters) {
            if (filter == 'Marble' && (stone.description.toLowerCase().contains('marble') || stone.name.toLowerCase().contains('marble'))) {
              matchesFilters = true;
              break;
            }
            if (filter == 'Travertine' && stone.name.toLowerCase().contains('travertine')) {
              matchesFilters = true;
              break;
            }
            if (filter == 'Polished' && stone.finish.toLowerCase() == 'polished') {
              matchesFilters = true;
              break;
            }
            if (filter == 'Honed' && stone.finish.toLowerCase() == 'honed') {
              matchesFilters = true;
              break;
            }
            if (filter == 'Leathered' && stone.finish.toLowerCase() == 'leathered') {
              matchesFilters = true;
              break;
            }
            if (filter == 'Under ₹200' && stone.pricePerSqFt < 200) {
              matchesFilters = true;
              break;
            }
            if (filter == '₹200-₹300' && stone.pricePerSqFt >= 200 && stone.pricePerSqFt <= 300) {
              matchesFilters = true;
              break;
            }
            if (filter == 'Over ₹300' && stone.pricePerSqFt > 300) {
              matchesFilters = true;
              break;
            }
          }
        }

        return matchesQuery && matchesFilters;
      }).toList();
    });
  }

  void _initFilteredStones(List<Stone> stones) {
    if (_filteredStones.isEmpty && stones.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _filteredStones = stones);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);
    final stonesAsync = ref.watch(allStonesProvider);

    return stonesAsync.when(
      loading: () => Scaffold(
        backgroundColor: palette.background,
        body: Center(child: CircularProgressIndicator(color: palette.primary)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: palette.background,
        body: Center(
          child: Text('Failed to load stones', style: GoogleFonts.inter(color: palette.textSecondary)),
        ),
      ),
      data: (stones) {
        _initFilteredStones(stones);
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
              'Search Surfaces',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
          ),
          body: Column(
            children: [
              // Search Input Field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: palette.border, width: 1.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: palette.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search by stone name, material, finish...',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 13,
                        color: palette.textTertiary,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: palette.primary,
                        size: 20,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                color: palette.textTertiary,
                                size: 18,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                HapticFeedback.lightImpact();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ),

              // Filter Chips Carousel
              SizedBox(
                height: 42,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: _allFilters.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final filter = _allFilters[index];
                    final isSelected = _selectedFilters.contains(filter);

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          if (filter == 'All') {
                            _selectedFilters = ['All'];
                          } else {
                            if (isSelected) {
                              _selectedFilters.remove(filter);
                            } else {
                              _selectedFilters.remove('All');
                              _selectedFilters.add(filter);
                            }
                            if (_selectedFilters.isEmpty) {
                              _selectedFilters = ['All'];
                            }
                          }
                          _filterStones();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? palette.primary.withValues(alpha: 0.12)
                              : palette.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? palette.primary : palette.border,
                            width: 1.0,
                          ),
                        ),
                        child: Text(
                          filter,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? palette.primary : palette.textSecondary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 10),

              // Results Count Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      '${_filteredStones.length} stones found',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: palette.textTertiary,
                      ),
                    ),
                    const Spacer(),
                    if (!_selectedFilters.contains('All'))
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _selectedFilters = ['All'];
                            _filterStones();
                          });
                        },
                        child: Text(
                          'Clear filters',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: palette.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 6),

              // Results in 2-Column Grid
              Expanded(
                child: _filteredStones.isEmpty
                    ? _buildEmptyState(palette)
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.72,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: _filteredStones.length,
                        itemBuilder: (context, index) {
                          final stone = _filteredStones[index];
                          return _buildGridStoneCard(stone, palette);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(LuxuryPalette palette) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.surface,
                border: Border.all(color: palette.border),
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 32,
                color: palette.textTertiary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No surfaces match your search',
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try adjusting your search keywords or explore all collections',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: palette.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_searchController.text.isNotEmpty || !_selectedFilters.contains('All'))
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: OutlinedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _searchController.clear();
                        setState(() {
                          _selectedFilters = ['All'];
                          _filterStones();
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.textPrimary,
                        side: BorderSide(color: palette.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      child: Text('Clear Filters', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ElevatedButton(
                  onPressed: () => context.go('/collections'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    elevation: 0,
                  ),
                  child: Text('Explore Collections', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridStoneCard(Stone stone, LuxuryPalette palette) {
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
              blurRadius: 8,
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
                      stone.collection,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: palette.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
