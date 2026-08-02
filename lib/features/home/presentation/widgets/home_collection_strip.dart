import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:grazia_stones/core/models/collection.dart';
import 'package:grazia_stones/core/theme/glass_theme.dart';
import 'package:grazia_stones/core/widgets/animated_widgets.dart';
import 'package:grazia_stones/shared/theme/colors.dart';

class HomeCollectionStrip extends StatelessWidget {
  final List<Collection> collections;
  final ValueChanged<Collection>? onCollectionTap;

  const HomeCollectionStrip({
    super.key,
    required this.collections,
    this.onCollectionTap,
  });

  @override
  Widget build(BuildContext context) {
    if (collections.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: collections.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return HoverScale(
            scale: 1.04,
            child: GestureDetector(
              onTap: () => onCollectionTap?.call(collections[index]),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: 140,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: GlassTheme.opacityLight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 0.5,
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.06),
                          Colors.white.withValues(alpha: 0.02),
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 32,
                          height: 4,
                          decoration: BoxDecoration(
                            gradient: GLuxuryPalettes.gold.primaryGradient,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              collections[index].name,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${collections[index].stoneCount} stones',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Colors.white70.withValues(alpha: 0.6),
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
          );
        },
      ),
    );
  }
}
