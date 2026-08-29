import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/typography.dart';
import 'package:grazia_stones/shared/theme/spacing.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late AnimationController _iconAnimationController;
  late Animation<double> _iconScaleAnimation;
  late Animation<double> _iconRotationAnimation;

  final List<_OnboardingPage> _pages = const [
    _OnboardingPage(
      title: 'The Architecture\nof Nature',
      subtitle:
          'Explore our curated quarry collections of handcrafted Italian & global architectural stone surfaces.',
      imagePath: 'assets/images/onboarding_1.png',
      icon: Icons.diamond_outlined,
    ),
    _OnboardingPage(
      title: 'Precision AI\nRoom Studio',
      subtitle:
          'Transform your living walls in seconds. Upload any space to visualize realistic stone cladding.',
      imagePath: 'assets/images/onboarding_2.png',
      icon: Icons.auto_awesome_outlined,
    ),
    _OnboardingPage(
      title: 'Real-Time AR\nWall Visualization',
      subtitle:
          'Detect walls, project real-scale stone textures, measure square footage, and order samples directly.',
      imagePath: 'assets/images/onboarding_3.png',
      icon: Icons.view_in_ar_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _iconAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _iconScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _iconAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _iconRotationAnimation = Tween<double>(begin: -0.2, end: 0.0).animate(
      CurvedAnimation(
        parent: _iconAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _iconAnimationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _iconAnimationController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    _iconAnimationController.reset();
    _iconAnimationController.forward();
    HapticFeedback.lightImpact();
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skip() {
    _completeOnboarding();
  }

  void _completeOnboarding() {
    HapticFeedback.mediumImpact();
    ref.read(authRiverpodProvider.notifier).completeOnboarding();
    context.go('/login');
  }



  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header: Skip button
            Padding(
              padding: GLuxurySpacing.paddingBase,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_currentPage < _pages.length - 1)
                    TextButton(
                      onPressed: _skip,
                      style: TextButton.styleFrom(
                        foregroundColor: palette.textTertiary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: GLuxurySpacing.base,
                          vertical: GLuxurySpacing.sm,
                        ),
                      ),
                      child: Text(
                        'Skip',
                        style: GLuxuryTypography.labelMedium.copyWith(
                          color: palette.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Page View
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: _onPageChanged,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return _buildPage(page, palette);
                },
              ),
            ),

            // Footer: Indicators + CTA
            Padding(
              padding: GLuxurySpacing.paddingXl,
              child: Column(
                children: [
                  // Page Indicators
                  _buildPageIndicators(palette),
                  GLuxurySpacing.gapXl,

                  // CTA Button
                  _buildCTAButton(palette),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardingPage page, LuxuryPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Architectural Image with Luxury Frame & Floating Icon
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                height: 280,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: palette.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(23),
                  child: Image.asset(
                    page.imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: palette.surfaceDark,
                      child: Icon(page.icon, size: 64, color: palette.primary),
                    ),
                  ),
                ),
              ),
              // Floating Accent Badge
              Transform.translate(
                offset: const Offset(-16, 18),
                child: AnimatedBuilder(
                  animation: _iconAnimationController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _iconRotationAnimation.value,
                      child: Transform.scale(
                        scale: _iconScaleAnimation.value,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: palette.border),
                      boxShadow: [
                        BoxShadow(
                          color: palette.primary.withValues(alpha: 0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(page.icon, size: 28, color: palette.primary),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 38),

          // Title
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: GLuxuryTypography.h1.copyWith(
              color: palette.textPrimary,
              height: 1.15,
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),

          // Subtitle
          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: GLuxuryTypography.bodyLarge.copyWith(
              color: palette.textSecondary,
              height: 1.5,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicators(LuxuryPalette palette) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _pages.length,
        (index) {
          final isActive = _currentPage == index;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 32 : 8,
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              gradient: isActive ? palette.primaryGradient : null,
              color: isActive ? null : palette.border,
            ),
          );
        },
      ),
    );
  }

  Widget _buildCTAButton(LuxuryPalette palette) {
    final isLastPage = _currentPage == _pages.length - 1;

    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        gradient: palette.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: palette.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _next,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isLastPage ? 'Explore Showroom' : 'Continue',
                  style: GLuxuryTypography.labelLarge.copyWith(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage {
  final String title;
  final String subtitle;
  final String imagePath;
  final IconData icon;

  const _OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.icon,
  });
}

