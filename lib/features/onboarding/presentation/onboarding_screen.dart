import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:grazia_stones/config/routes.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/typography.dart';
import 'package:grazia_stones/shared/widgets/grazia_button.dart';
import 'package:grazia_stones/core/constants/app_dimensions.dart';
import 'package:grazia_stones/features/auth/providers/auth_provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<_OnboardingPage> _pages = const [
    _OnboardingPage(
      title: 'Discover\nTimeless Stone',
      subtitle:
          'Browse our curated collection of premium natural stones — each with a unique story etched by nature over millennia.',
      lottieAsset: 'assets/lottie/onboarding_discover.json',
      icon: Icons.explore_outlined,
    ),
    _OnboardingPage(
      title: 'Visualize\nYour Vision',
      subtitle:
          'Use AI to see how any stone looks in your space. Tap once — the room transforms instantly.',
      lottieAsset: 'assets/lottie/onboarding_ar.json',
      icon: Icons.view_in_ar_outlined,
    ),
    _OnboardingPage(
      title: 'Request\nSamples',
      subtitle:
          'Feel the texture. See the finish. Order physical samples delivered to your doorstep — free for architects.',
      lottieAsset: 'assets/lottie/onboarding_sample.json',
      icon: Icons.inventory_2_outlined,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _goToLogin();
    }
  }

  void _goToLogin() {
    context.read<AuthProvider>().completeOnboarding();
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  void _skip() {
    _goToLogin();
  }

  @override
  Widget build(BuildContext context) {
    final palette = GLuxuryPalettes.gold;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.spacingL),
                child: TextButton(
                  onPressed: _skip,
                  child: Text(
                    'Skip',
                    style: GLuxuryTypography.bodyLarge.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ),
              ),
            ),

            // Page view
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spacingXL,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon / Lottie placeholder
                        Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: palette.primary.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              page.icon,
                              size: 80,
                              color: palette.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacingXXL),

                        // Title
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: GLuxuryTypography.h1.copyWith(
                            color: theme.colorScheme.onSurface,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacingL),

                        // Subtitle
                        Text(
                          page.subtitle,
                          textAlign: TextAlign.center,
                          style: GLuxuryTypography.bodyLarge.copyWith(
                            color: palette.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Dots + CTA
            Padding(
              padding: const EdgeInsets.all(AppDimensions.spacingXL),
              child: Column(
                children: [
                  // Page indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 32 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: _currentPage == index
                              ? palette.primary
                              : palette.accent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingXL),

                  // CTA button
                  GraziaButton(
                    label: _currentPage == _pages.length - 1
                        ? 'Get Started'
                        : 'Next',
                    icon: _currentPage == _pages.length - 1
                        ? Icons.arrow_forward_rounded
                        : Icons.arrow_forward_rounded,
                    onPressed: _next,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage {
  final String title;
  final String subtitle;
  final String lottieAsset;
  final IconData icon;

  const _OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.lottieAsset,
    required this.icon,
  });
}
