import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/shared/widgets/grazia_logo.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingPage> _pages = const [
    _OnboardingPage(
      heading1: 'Design',
      heading2: 'Your Dream',
      heading3: 'Space',
      tagline: 'With the power of AI | AR | VR',
      subtitle:
          'Innovative stone panels, 3D relief surfaces & architectural textures.',
      imagePath: 'assets/images/onboarding_hero_room.jpg',
    ),
    _OnboardingPage(
      heading1: 'Precision AI',
      heading2: 'Wall Studio',
      heading3: 'Reimagined',
      tagline: 'Powered by NVIDIA NIM Neural Vision',
      subtitle:
          'Upload or capture any living space to visualize realistic stone cladding in seconds.',
      imagePath: 'assets/images/home_hero_living_room.jpg',
    ),
    _OnboardingPage(
      heading1: 'Virtual Reality',
      heading2: 'Interactive',
      heading3: 'Showroom',
      tagline: 'Step Inside 3D Luxury Spaces',
      subtitle:
          'Walk through virtual architectural villas, hotel lobbies and calculate BOQ estimates.',
      imagePath: 'assets/images/onboarding_3.png',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    HapticFeedback.lightImpact();
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 450),
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
    final currentPageData = _pages[_currentPage];

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0C),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Full-Bleed Architectural Backdrop PageView ──
          Positioned.fill(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _pages.length,
              onPageChanged: _onPageChanged,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final page = _pages[index];
                return Image.asset(
                  page.imagePath,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFF141312),
                  ),
                );
              },
            ),
          ),

          // ── 2. Cinematic Vignette Gradient Overlay ──
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.70),
                    Colors.black.withValues(alpha: 0.25),
                    Colors.black.withValues(alpha: 0.40),
                    Colors.black.withValues(alpha: 0.90),
                  ],
                  stops: const [0.0, 0.35, 0.65, 1.0],
                ),
              ),
            ),
          ),

          // ── 3. Top Header: Skip Button ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.20),
                            width: 0.8,
                          ),
                        ),
                        child: GestureDetector(
                          onTap: _skip,
                          child: Text(
                            'Skip',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── 4. Upper Architectural Headlines (Client Reference Screen 2) ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 24, right: 24, top: 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    currentPageData.heading1,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 38,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.08,
                      letterSpacing: 0.4,
                    ),
                  ),
                  Text(
                    currentPageData.heading2,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 38,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.08,
                      letterSpacing: 0.4,
                    ),
                  ),
                  Text(
                    currentPageData.heading3,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 38,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.08,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.50),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      currentPageData.tagline,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFF3E7C4),
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── 5. Bottom Client Reference Luxury Pill Card ──
          Positioned(
            left: 20,
            right: 20,
            bottom: 34,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBF9F5), // Ivory card like reference
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFFE5DDD0),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.40),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Brand Wordmark + Subtitle
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'GRAZIA STONES',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                              color: const Color(0xFF141210),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'UNIT OF BNK STONES',
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                              color: const Color(0xFF8C8275),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Indicators
                          Row(
                            children: List.generate(
                              _pages.length,
                              (i) => AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.only(right: 4),
                                width: _currentPage == i ? 18 : 6,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: _currentPage == i
                                      ? const Color(0xFF141210)
                                      : const Color(0xFFD5CBBF),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Circular Action Button with Arrow (Client Reference Screen 2)
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          _next();
                        },
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            color: Color(0xFF141210),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage {
  final String heading1;
  final String heading2;
  final String heading3;
  final String tagline;
  final String subtitle;
  final String imagePath;

  const _OnboardingPage({
    required this.heading1,
    required this.heading2,
    required this.heading3,
    required this.tagline,
    required this.subtitle,
    required this.imagePath,
  });
}
