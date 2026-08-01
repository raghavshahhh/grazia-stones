import 'package:flutter/material.dart';
import 'package:grazia_stones/core/constants/app_colors.dart';
import 'package:grazia_stones/core/theme/text_styles.dart';
import 'package:grazia_stones/core/widgets/animated_widgets.dart';

class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = [
      {'icon': Icons.auto_awesome_outlined, 'label': 'AI Visualizer', 'color': AppColors.goldWarm},
      {'icon': Icons.view_in_ar_outlined, 'label': 'Live AR', 'color': AppColors.silverLight},
      {'icon': Icons.dashboard_outlined, 'label': 'Collections', 'color': AppColors.goldWarm},
      {'icon': Icons.store_outlined, 'label': 'Dealers', 'color': AppColors.silverLight},
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Row(
        children: actions.map((a) {
          final color = a['color'] as Color;
          return Expanded(
            child: HoverScale(
              scale: 1.06,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMedium,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: color.withOpacity(0.15),
                    width: 0.5,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      a['icon'] as IconData,
                      color: color,
                      size: 26,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      a['label'] as String,
                      style: GraziaTextStyles.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
