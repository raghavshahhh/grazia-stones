import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/typography.dart';
import 'package:grazia_stones/shared/theme/spacing.dart';
import 'package:grazia_stones/shared/widgets/smart_stone_image.dart';
import 'package:grazia_stones/shared/theme/tokens.dart';
import 'package:grazia_stones/core/services/mock_data_service.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/shared/widgets/grazia_app_bar.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
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
    'Brushed',
    'Under ₹200',
    '₹200-₹300',
    'Over ₹300',
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
            (stone.origin?.toLowerCase().contains(query) ?? false);

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

  @override
  Widget build(BuildContext context) {
    final palette = GLuxuryPalettes.gold;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: GraziaAppBar(
        title: 'SEARCH',
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: palette.textSecondary,
            size: 20,
          ),
        ),
      ),
      body: Column(
        children: [
          GLuxurySpacing.gapSm,
          
          // Search Field
          Padding(
            padding: GLuxurySpacing.horizontalBase,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(GTokens.radiusMd),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: palette.textPrimary.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(GTokens.radiusMd),
                    border: Border.all(color: palette.border, width: 0.5),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: GLuxuryTypography.bodyMedium.copyWith(
                      color: palette.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search stones, collections, materials...',
                      hintStyle: GLuxuryTypography.bodyMedium.copyWith(
                        color: palette.textTertiary.withValues(alpha: 0.5),
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: palette.primary,
                        size: 22,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                color: palette.textTertiary,
                                size: 20,
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
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          GLuxurySpacing.gapBase,

          // Filter Chips
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: GLuxurySpacing.horizontalBase,
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
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? palette.primary.withValues(alpha: 0.2)
                          : palette.textPrimary.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isSelected
                            ? palette.primary.withValues(alpha: 0.5)
                            : palette.border,
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        filter,
                        style: GLuxuryTypography.bodySmall.copyWith(
                          color: isSelected ? palette.primary : palette.textSecondary,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          GLuxurySpacing.gapBase,

          // Results Count
          Padding(
            padding: GLuxurySpacing.horizontalBase,
            child: Row(
              children: [
                Text(
                  '${_filteredStones.length} stones found',
                  style: GLuxuryTypography.bodySmall.copyWith(
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
                      style: GLuxuryTypography.bodySmall.copyWith(
                        color: palette.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          GLuxurySpacing.gapBase,

          // Results List
          Expanded(
            child: _filteredStones.isEmpty
                ? _buildEmptyState(palette)
                : _buildResultsList(palette),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(LuxuryPalette palette) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.surface,
              border: Border.all(color: palette.border, width: 1),
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 36,
              color: palette.textTertiary,
            ),
          ),
          GLuxurySpacing.gapBase,
          Text(
            'No stones found',
            style: GLuxuryTypography.h3.copyWith(color: palette.textSecondary),
          ),
          GLuxurySpacing.gapXs,
          Text(
            'Try adjusting your search or filters',
            style: GLuxuryTypography.bodySmall.copyWith(
              color: palette.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList(LuxuryPalette palette) {
    return ListView.builder(
      padding: GLuxurySpacing.paddingBase,
      itemCount: _filteredStones.length,
      itemBuilder: (context, index) {
        final stone = _filteredStones[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildStoneCard(stone, palette),
        );
      },
    );
  }

  Widget _buildStoneCard(Stone stone, LuxuryPalette palette) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          context.push('/stones/${stone.id}');
        },
        borderRadius: BorderRadius.circular(GTokens.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(GTokens.radiusLg),
            border: Border.all(color: palette.border, width: 0.5),
          ),
          child: Row(
            children: [
              // Stone Image
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: SmartStoneImage(
                    imageUrl: stone.imageUrl,
                    width: 80,
                    height: 80,
                    palette: palette,
                  ),
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
                      style: GLuxuryTypography.h3.copyWith(
                        color: palette.textPrimary,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stone.collection,
                      style: GLuxuryTypography.bodySmall.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.star_rounded,
                          color: palette.primary,
                          size: 14,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          stone.rating.toString(),
                          style: GLuxuryTypography.bodySmall.copyWith(
                            color: palette.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: palette.textPrimary.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: palette.border, width: 0.5),
                          ),
                          child: Text(
                            stone.finish,
                            style: GLuxuryTypography.bodySmall.copyWith(
                              color: palette.textTertiary,
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
                    '₹${stone.pricePerSqFt.toStringAsFixed(0)}',
                    style: GLuxuryTypography.h3.copyWith(
                      color: palette.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    'per sq ft',
                    style: GLuxuryTypography.bodySmall.copyWith(
                      color: palette.textTertiary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
