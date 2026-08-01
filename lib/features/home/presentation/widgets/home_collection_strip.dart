import 'package:flutter/material.dart';
import 'package:grazia_stones/core/constants/app_colors.dart';
import 'package:grazia_stones/core/constants/app_strings.dart';
import 'package:grazia_stones/core/theme/text_styles.dart';

class HomeCollectionStrip extends StatelessWidget {
  const HomeCollectionStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final collections = [
      {'name': 'Royal Marble', 'count': '48 stones', 'icon': '🏛️'},
      {'name': 'Slate Series', 'count': '32 stones', 'icon': '🪨'},
      {'name': 'Onyx Luxe', 'count': '24 stones', 'icon': '✨'},
      {'name': 'Travertine', 'count': '18 stones', 'icon': '🏔️'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.popularCollections,
                style: GraziaTextStyles.titleMedium,
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushNamed('/collections');
                },
                child: Text(
                  AppStrings.viewAll,
                  style: GraziaTextStyles.bodySmall.copyWith(
                    color: AppColors.goldWarm,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: collections.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final c = collections[index];
              return Container(
                width: 130,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.borderSubtle,
                    width: 0.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      c['icon'] as String,
                      style: const TextStyle(fontSize: 24),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c['name'] as String,
                          style: GraziaTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          c['count'] as String,
                          style: GraziaTextStyles.labelSmall.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
