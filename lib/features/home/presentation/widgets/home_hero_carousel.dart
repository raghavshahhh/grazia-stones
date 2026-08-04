import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/typography.dart';
import 'package:grazia_stones/shared/theme/tokens.dart';
import 'package:grazia_stones/shared/widgets/smart_stone_image.dart';

class HomeHeroCarousel extends StatefulWidget {
  final List<Stone> stones;
  final ValueChanged<Stone>? onStoneTap;

  const HomeHeroCarousel({
    super.key,
    required this.stones,
    this.onStoneTap,
  });

  @override
  State<HomeHeroCarousel> createState() => _HomeHeroCarouselState();
}

class _HomeHeroCarouselState extends State<HomeHeroCarousel> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stones.isEmpty) return const SizedBox.shrink();

    final palette = GLuxuryPalettes.gold;

    return SizedBox(
      height: 280,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.stones.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, index) => _buildSlide(index),
          ),
          // Page indicators
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.stones.length, (i) {
                final isActive = i == _currentPage;
                return AnimatedContainer(
                  duration: GTokens.durationNormal,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 24 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: isActive ? palette.primaryGradient : null,
                    color: isActive ? null : Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: palette.primary.withValues(alpha: 0.3),
                              blurRadius: 6,
                            ),
                          ]
                        : null,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlide(int index) {
    final stone = widget.stones[index];
    final imageUrl = stone.imageUrl ?? '';
    final hasImage = imageUrl.isNotEmpty;
    final palette = GLuxuryPalettes.gold;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: GestureDetector(
        onTap: () => widget.onStoneTap?.call(stone),
        child: AnimatedContainer(
          duration: GTokens.durationSlow,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GTokens.radius2xl),
            boxShadow: [
              BoxShadow(
                color: palette.primary.withValues(alpha: 0.08),
                blurRadius: 30,
                spreadRadius: -6,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(GTokens.radius2xl),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background image
                SmartStoneImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  palette: palette,
                ),

                // Glass gradient overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.3),
                          Colors.black.withValues(alpha: 0.7),
                        ],
                        stops: const [0.0, 0.5, 0.8, 1.0],
                      ),
                    ),
                  ),
                ),

                // Glass text overlay at bottom
                Positioned(
                  bottom: 48,
                  left: 20,
                  right: 20,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(GTokens.radiusLg),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(GTokens.radiusLg),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                            width: 0.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              stone.name,
                              style: GLuxuryTypography.h2.copyWith(
                                color: Colors.white,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  stone.collection,
                                  style: GLuxuryTypography.bodySmall.copyWith(
                                    color: palette.primary.withValues(alpha: 0.8),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '₹${stone.pricePerSqFt.toInt()}/sq ft',
                                  style: GLuxuryTypography.bodyMedium.copyWith(
                                    color: palette.primary,
                                    fontWeight: FontWeight.w700,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
