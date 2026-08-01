import 'package:flutter/material.dart';
import 'package:grazia_stones/core/constants/app_strings.dart';
import 'package:grazia_stones/core/services/mock_data_service.dart';
import 'package:grazia_stones/core/theme/text_styles.dart';
import 'package:grazia_stones/shared/widgets/stone_grid_tile.dart';

class HomeTrendingGrid extends StatelessWidget {
  const HomeTrendingGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final stones = MockDataService.getTrendingStones();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          child: Text(AppStrings.trendingStones, style: GraziaTextStyles.titleMedium),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
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
              stone: s,
              onTap: () => Navigator.of(context).pushNamed('/stones/${s.id}'),
              onWishlist: () {},
            );
          },
        ),
      ],
    );
  }
}
