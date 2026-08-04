import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/constants/app_colors.dart';
import 'package:grazia_stones/core/services/mock_data_service.dart';
import 'package:grazia_stones/core/theme/text_styles.dart';
import 'package:grazia_stones/shared/widgets/grazia_app_bar.dart';

class CollectionListScreen extends StatelessWidget {
  const CollectionListScreen({super.key});

  static const _icons = {
    'royal-marble': '🏛️',
    'heritage': '🏺',
    'contemporary': '◼️',
  };

  @override
  Widget build(BuildContext context) {
    final collections = MockDataService.collections;

    return Scaffold(
      backgroundColor: AppColors.charcoal,
      appBar: const GraziaAppBar(title: 'Collections'),
      body: ListView.separated(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: collections.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final c = collections[index];
          final icon = _icons[c.id] ?? '🪨';
          return GestureDetector(
            onTap: () {
              context.push('/collections/${c.id}');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.borderSubtle,
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  Text(icon, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.name,
                          style: GraziaTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${c.stoneCount} stones',
                          style: GraziaTextStyles.bodySmall.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.textTertiary,
                    size: 20,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
