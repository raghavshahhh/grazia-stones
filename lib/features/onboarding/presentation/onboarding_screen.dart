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
      title: 'Discover\nTimeless Stone',
      subtitle:
          'Browse our curated collection of premium natural stones—each with a unique story etched by nature over millennia.',
      icon: Icons.diamond_outlined,
      gradient: [Color(0xFFC9A84C), Color(0xFFD4AF37)],
    ),
    _OnboardingPage(
      title: 'Visualize\nYour Vision',
      subtitle:
          'Use AI to see how any stone looks in your space. Tap once—the room transforms instantly.',
      icon: Icons.auto_awesome_outlined,
      gradient: [Color(0xFFD4AF37), Color(0xFFB8860B)],
    ),
    _OnboardingPage(
      title: 'Experience\nin Reality',
      subtitle:
          'See stones in your actual space with AR. Place, rotate, and feel the transformation before you buy.',
      icon: Icons.view_in_ar_outlined,
      gradient: [Color(0xFFB8860B), Color(0xFFC9A84C)],
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
        curve: Curves.elasticOut,
      ),
    );

    _iconRotationAnimation = Tween<double>(begin: -0.5, end: 0.0).animate(
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
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skip() {
    _completeOnboarding();
  }

  void _completeOnboarding() {
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
      padding: GLuxurySpacing.horizontalXxl,
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
          // Animated Icon with Gradient Circle
          AnimatedBuilder(
            animation: _iconAnimationController,
            builder: (context, child) {
              return Transform.scale(
                scale: _iconScaleAnimation.value,
                child: Transform.rotate(
                  angle: _iconRotationAnimation.value,
                  child: child,
                ),
              );
            },
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    page.gradient[0].withValues(alpha: 0.15),
                    page.gradient[1].withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  width: 1.5,
                  color: palette.primary.withValues(alpha: 0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: palette.primary.withValues(alpha: 0.1),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Center(
                child: ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: page.gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: Icon(
                    page.icon,
                    size: 90,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          GLuxurySpacing.gapXxl,
          GLuxurySpacing.gapLg,

          // Title
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: GLuxuryTypography.h1.copyWith(
              color: palette.textPrimary,
              height: 1.15,
              fontSize: 40,
              fontWeight: FontWeight.w700,
            ),
          ),
          GLuxurySpacing.gapLg,

          // Subtitle
          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: GLuxuryTypography.bodyLarge.copyWith(
              color: palette.textSecondary,
              height: 1.6,
              fontSize: 16,
            ),
          ),
        ],
          ),
        ),
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
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 5),
            width: isActive ? 40 : 10,
            height: 10,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              gradient: isActive
                  ? palette.primaryGradient
                  : null,
              color: isActive ? null : palette.border,
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: palette.primary.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
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
      height: 56,
      decoration: BoxDecoration(
        gradient: palette.primaryGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: palette.primary.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _next,
          borderRadius: BorderRadius.circular(28),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isLastPage ? 'Get Started' : 'Next',
                  style: GLuxuryTypography.labelLarge.copyWith(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 20,
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
  final IconData icon;
  final List<Color> gradient;

  const _OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
  });
}
