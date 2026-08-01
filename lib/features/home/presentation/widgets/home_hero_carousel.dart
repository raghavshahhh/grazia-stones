import 'package:flutter/material.dart';
import 'package:grazia_stones/core/constants/app_colors.dart';
import 'package:grazia_stones/core/theme/text_styles.dart';

class HomeHeroCarousel extends StatefulWidget {
  const HomeHeroCarousel({super.key});

  @override
  State<HomeHeroCarousel> createState() => _HomeHeroCarouselState();
}

class _HomeHeroCarouselState extends State<HomeHeroCarousel> {
  final _controller = PageController();
  int _currentIndex = 0;

  final _heroData = [
    {
      'title': '2026 Premium\nCollection',
      'subtitle': 'New luxury stone finishes',
      'gradient': AppColors.goldGradient,
    },
    {
      'title': 'AI\nVisualizer',
      'subtitle': 'See it on your wall',
      'gradient': AppColors.silverGradient,
    },
    {
      'title': 'Live AR\nExperience',
      'subtitle': 'Real-time visualization',
      'gradient': AppColors.goldGradient,
    },
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: _controller,
            itemCount: _heroData.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final hero = _heroData[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.surfaceLight,
                      AppColors.surfaceMedium,
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.borderSubtle,
                    width: 0.5,
                  ),
                ),
                child: Stack(
                  children: [
                    // ── Decorative circles ──
                    Positioned(
                      top: -30,
                      right: -30,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              hero['gradient'] as LinearGradient,
                            ].first.colors,
                          ),
                          color: AppColors.goldWarm.withOpacity(0.08),
                        ),
                      ),
                    ),
                    // ── Content ──
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) =>
                                (hero['gradient'] as LinearGradient)
                                    .createShader(bounds),
                            child: Text(
                              hero['title'] as String,
                              style: GraziaTextStyles.displaySmall.copyWith(
                                color: Colors.white,
                                height: 1.1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            hero['subtitle'] as String,
                            style: GraziaTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        // ── Dots Indicator ──
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _heroData.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == _currentIndex ? 24 : 6,
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: i == _currentIndex
                    ? AppColors.goldWarm
                    : AppColors.textTertiary.withOpacity(0.3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
