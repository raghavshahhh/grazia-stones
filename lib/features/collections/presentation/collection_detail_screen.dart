import 'package:flutter/material.dart';
import 'package:grazia_stones/core/constants/app_colors.dart';
import 'package:grazia_stones/core/services/mock_data_service.dart';
import 'package:grazia_stones/core/theme/text_styles.dart';
import 'package:grazia_stones/shared/widgets/grazia_app_bar.dart';
import 'package:grazia_stones/shared/widgets/stone_grid_tile.dart';

class CollectionDetailScreen extends StatelessWidget {
  final String collectionId;

  const CollectionDetailScreen({super.key, required this.collectionId});

  static const _icons = {
    'royal-marble': '🏛️',
    'heritage': '🏺',
    'contemporary': '◼️',
  };

  @override
  Widget build(BuildContext context) {
    final stones = MockDataService.getStonesByCollection(collectionId);
    final collection = MockDataService.collections.firstWhere(
      (c) => c.id == collectionId,
      orElse: () => MockDataService.collections.first,
    );
    final icon = _icons[collectionId] ?? '🪨';

    return Scaffold(
      backgroundColor: AppColors.charcoal,
      appBar: GraziaAppBar(
        title: collection.name.toUpperCase(),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: AppColors.textSecondary),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: AppColors.goldGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(icon, style: const TextStyle(fontSize: 30)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        collection.name.toUpperCase(),
                        style: GraziaTextStyles.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        collection.description,
                        style: GraziaTextStyles.bodySmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: stones.isEmpty
                ? Center(
                    child: Text(
                      'No stones in this collection yet',
                      style: GraziaTextStyles.bodyMedium.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.68,
                    ),
                    itemCount: stones.length,
                    itemBuilder: (context, index) {
                      final s = stones[index];
                      return StoneGridTile(
                        name: s.name,
                        collection: s.collection,
                        pricePerSqFt: s.pricePerSqFt,
                        rating: s.rating,
                        imageUrl: s.imageUrl ?? '',
                        onTap: () {
                          Navigator.of(context).pushNamed(
                            '/stones/${s.id}',
                            arguments: s.id,
                          );
                        },
                        onWishlist: () {},
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
