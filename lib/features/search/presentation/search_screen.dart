import 'package:flutter/material.dart';
import 'package:grazia_stones/core/constants/app_colors.dart';
import 'package:grazia_stones/core/constants/app_dimensions.dart';
import 'package:grazia_stones/core/theme/text_styles.dart';
import 'package:grazia_stones/core/services/mock_data_service.dart';
import 'package:grazia_stones/core/models/stone.dart';
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
      appBar: AppBar(
        backgroundColor: AppColors.charcoal,
        title: const Text('Search Stones', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingL),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search by name, collection, or material...',
                hintStyle: const TextStyle(color: AppColors.textTertiary),
                prefixIcon: const Icon(Icons.search, color: AppColors.textTertiary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.textTertiary),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: AppColors.charcoal,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  borderSide: const BorderSide(color: AppColors.borderSubtle),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  borderSide: const BorderSide(color: AppColors.borderSubtle),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  borderSide: const BorderSide(color: AppColors.gold, width: 2),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingM),
              scrollDirection: Axis.horizontal,
              itemCount: _allFilters.length,
              separatorBuilder: (context, index) => const SizedBox(width: AppDimensions.spacingXs),
              itemBuilder: (context, index) {
                final filter = _allFilters[index];
                final isSelected = _selectedFilters.contains(filter);
                return FilterChip(
                  label: Text(
                    filter,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontSize: 12,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.gold,
                  backgroundColor: AppColors.charcoal,
                  side: BorderSide(
                    color: isSelected ? AppColors.gold : AppColors.borderSubtle,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      if (filter == 'All') {
                        _selectedFilters = ['All'];
                      } else {
                        _selectedFilters.remove('All');
                        if (selected) {
                          _selectedFilters.add(filter);
                        } else {
                          _selectedFilters.remove(filter);
                        }
                      }
                      _filterStones();
                    });
                  },
                );
              },
            ),
          ),
          const SizedBox(height: AppDimensions.spacingM),
          Expanded(
            child: _filteredStones.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: AppColors.textTertiary.withOpacity(0.5),
                        ),
                        const SizedBox(height: AppDimensions.spacingM),
                        Text(
                          'No stones found',
                          style: AppTextStyles.headlineSmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacingS),
                        Text(
                          'Try adjusting your search or filters',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(AppDimensions.spacingM),
                    itemCount: _filteredStones.length,
                    itemBuilder: (context, index) {
                      final stone = _filteredStones[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: AppDimensions.spacingM),
                        color: AppColors.charcoal,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        ),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => StoneDetailScreen(stoneId: stone.id),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                          child: Padding(
                            padding: const EdgeInsets.all(AppDimensions.spacingM),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                                  child: Image.network(
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
                                ),
                                const SizedBox(width: AppDimensions.spacingM),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        stone.name,
                                        style: AppTextStyles.titleMedium.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: AppDimensions.spacingXxs),
                                      Text(
                                        stone.collection,
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: AppDimensions.spacingXxs),
                                      Row(
                                        children: [
                                          const Icon(Icons.star, color: AppColors.gold, size: 14),
                                          const SizedBox(width: 4),
                                          Text(
                                            stone.rating.toString(),
                                            style: AppTextStyles.bodySmall.copyWith(
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(width: AppDimensions.spacingS),
                                          Text(
                                            stone.finish,
                                            style: AppTextStyles.bodySmall.copyWith(
                                              color: AppColors.textTertiary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '\$${stone.pricePerSqFt.toStringAsFixed(0)}',
                                  style: AppTextStyles.titleMedium.copyWith(
                                    color: AppColors.gold,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
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
