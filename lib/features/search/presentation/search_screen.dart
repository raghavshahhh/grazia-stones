import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:grazia_stones/core/constants/app_colors.dart';
import 'package:grazia_stones/core/constants/app_dimensions.dart';
import 'package:grazia_stones/core/theme/glass_theme.dart';
import 'package:grazia_stones/core/theme/text_styles.dart';
import 'package:grazia_stones/core/services/mock_data_service.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/shared/widgets/grazia_app_bar.dart';
import 'package:grazia_stones/features/stone_detail/presentation/stone_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _selectedFilters = [];
  List<Stone> _filteredStones = [];

  final List<String> _allFilters = [
    'All',
    'Marble',
    'Travertine',
    'Polished',
    'Honed',
    'Leathered',
    'Brushed',
    'Under \$200',
    '\$200-\$300',
    'Over \$300',
  ];

  @override
  void initState() {
    super.initState();
    _filteredStones = MockDataService.stones;
    _searchController.addListener(_filterStones);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterStones);
    _searchController.dispose();
    super.dispose();
  }

  void _filterStones() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredStones = MockDataService.stones.where((stone) {
        final matchesQuery = query.isEmpty ||
            stone.name.toLowerCase().contains(query) ||
            stone.collection.toLowerCase().contains(query) ||
            stone.description.toLowerCase().contains(query) ||
            stone.finish.toLowerCase().contains(query) ||
            stone.origin.toLowerCase().contains(query);

        bool matchesFilters = _selectedFilters.contains('All') || _selectedFilters.isEmpty;

        if (!matchesFilters) {
          for (final filter in _selectedFilters) {
            if (filter == 'Marble' && stone.description.toLowerCase().contains('marble')) {
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
            if (filter == 'Brushed' && stone.finish.toLowerCase() == 'brushed') {
              matchesFilters = true;
              break;
            }
            if (filter == 'Under \$200' && stone.pricePerSqFt < 200) {
              matchesFilters = true;
              break;
            }
            if (filter == '\$200-\$300' && stone.pricePerSqFt >= 200 && stone.pricePerSqFt <= 300) {
              matchesFilters = true;
              break;
            }
            if (filter == 'Over \$300' && stone.pricePerSqFt > 300) {
              matchesFilters = true;
              break;
            }
          }
        }

        return matchesQuery && matchesFilters;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      appBar: GraziaAppBar(
        title: 'SEARCH',
      ),
      body: Column(
        children: [
          // ── Glass Search Field ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: GlassTheme.blurLight, sigmaY: GlassTheme.blurLight),
                child: Container(
                  decoration: GlassTheme.glassLight.copyWith(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: GraziaTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search stones, collections, materials...',
                      hintStyle: GraziaTextStyles.bodyMedium.copyWith(color: AppColors.textTertiary),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.gold, size: 22),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, color: AppColors.textTertiary, size: 20),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Glass Filter Chips ──
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingM),
              scrollDirection: Axis.horizontal,
              itemCount: _allFilters.length,
              separatorBuilder: (context, index) => const SizedBox(width: AppDimensions.spacingXs),
              itemBuilder: (context, index) {
                final filter = _allFilters[index];
                final isSelected = _selectedFilters.contains(filter);

                return AnimatedContainer(
                  duration: GlassTheme.durationFast,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.gold.withOpacity(0.25)
                              : AppColors.white.withOpacity(GlassTheme.opacityLight),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.gold.withOpacity(0.6)
                                : AppColors.white.withOpacity(GlassTheme.borderThin),
                            width: GlassTheme.borderThin,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            filter,
                            style: GraziaTextStyles.bodySmall.copyWith(
                              color: isSelected ? AppColors.gold : AppColors.textSecondary,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // ── Results Count ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '${_filteredStones.length} stones found',
                  style: GraziaTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
                ),
                const Spacer(),
                if (_selectedFilters.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFilters = [];
                        _filterStones();
                      });
                    },
                    child: Text(
                      'Clear filters',
                      style: GraziaTextStyles.bodySmall.copyWith(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Glass Results List ──
          Expanded(
            child: _filteredStones.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: GlassTheme.glassMedium.copyWith(
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.search_off_rounded, size: 36, color: AppColors.textTertiary),
                        ),
                        const SizedBox(height: AppDimensions.spacingM),
                        Text(
                          'No stones found',
                          style: GraziaTextStyles.titleSmall.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: AppDimensions.spacingXxs),
                        Text(
                          'Try adjusting your search or filters',
                          style: GraziaTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredStones.length,
                    itemBuilder: (context, index) {
                      final stone = _filteredStones[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: Container(
                              decoration: GlassTheme.glassMedium.copyWith(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => StoneDetailScreen(stoneId: stone.id),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        // Stone image with glass overlay
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Stack(
                                            children: [
                                              Image.network(
                                                stone.imageUrl ?? '',
                                                width: 80,
                                                height: 80,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) {
                                                  return Container(
                                                    width: 80,
                                                    height: 80,
                                                    color: AppColors.surfaceLight,
                                                    child: const Icon(Icons.image, color: AppColors.textTertiary),
                                                  );
                                                },
                                              ),
                                              // Glass shimmer overlay
                                              Positioned.fill(
                                                child: DecoratedBox(
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      begin: Alignment.topLeft,
                                                      end: Alignment.bottomRight,
                                                      colors: [
                                                        Colors.white.withOpacity(0.1),
                                                        Colors.transparent,
                                                        Colors.white.withOpacity(0.05),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        // Info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                stone.name,
                                                style: GraziaTextStyles.titleSmall.copyWith(
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                stone.collection,
                                                style: GraziaTextStyles.bodySmall.copyWith(
                                                  color: AppColors.textSecondary,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  const Icon(Icons.star_rounded, color: AppColors.gold, size: 14),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    stone.rating.toString(),
                                                    style: GraziaTextStyles.bodySmall.copyWith(
                                                      color: AppColors.textSecondary,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.white.withOpacity(0.06),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(
                                                        color: AppColors.white.withOpacity(0.08),
                                                        width: 0.5,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      stone.finish,
                                                      style: GraziaTextStyles.bodySmall.copyWith(
                                                        color: AppColors.textTertiary,
                                                        fontSize: 10,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Price
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '\$${stone.pricePerSqFt.toStringAsFixed(0)}',
                                              style: GraziaTextStyles.titleSmall.copyWith(
                                                color: AppColors.gold,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              'per sq ft',
                                              style: GraziaTextStyles.bodySmall.copyWith(
                                                color: AppColors.textTertiary,
                                                fontSize: 10,
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
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
