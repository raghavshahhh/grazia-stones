import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:grazia_stones/core/theme/glass_theme.dart';
import 'package:grazia_stones/core/widgets/animated_widgets.dart';
import 'package:grazia_stones/shared/theme/colors.dart';

class HomeQuickActions extends StatelessWidget {
  final List<Map<String, dynamic>> actions;
  final ValueChanged<int>? onActionTap;

  const HomeQuickActions({
    super.key,
    required this.actions,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final action = actions[index];
          return HoverScale(
            scale: 1.06,
            child: GestureDetector(
              onTap: () => onActionTap?.call(index),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: 72,
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: GlassTheme.opacityLight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 0.5,
                      ),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.06),
                              width: 0.5,
                            ),
                          ),
                          child: Icon(
                            action['icon'] as IconData,
                            size: 20,
                            color: GLuxuryPalettes.gold.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          action['label'] as String,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white54,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
