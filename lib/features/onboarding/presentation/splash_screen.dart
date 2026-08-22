import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key, this.skipDelay = false});
  final bool skipDelay;

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _lineWidthAnimation;
  late Animation<double> _lineOpacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    // 0.0s - 0.5s: Logo + brand name fade in
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.5, curve: Curves.easeOutCubic),
      ),
    );

    // 0.1s - 0.5s: Very gentle scale from 0.95 to 1.0
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.5, curve: Curves.easeOutCubic),
      ),
    );

    // 0.5s - 0.9s: Razor-thin gold line expands
    _lineWidthAnimation = Tween<double>(begin: 0.0, end: 64.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.45, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    // 0.85s - 1.0s: Gold line gentle fade
    _lineOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.45, 0.7, curve: Curves.easeIn),
      ),
    );

    _controller.forward();

    // Navigate after check
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    if (!widget.skipDelay) {
      await Future.delayed(const Duration(milliseconds: 1900));
    }

    if (!mounted) return;

    final authState = ref.read(authRiverpodProvider);

    String route;
    if (!authState.onboardingComplete) {
      route = '/onboarding';
    } else if (!authState.isLoggedIn) {
      route = '/login';
    } else {
      route = '/home';
    }

    if (mounted) {
      context.go(route);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);

    return Scaffold(
      backgroundColor: palette.background,
      body: GestureDetector(
        onTap: () {
          final authState = ref.read(authRiverpodProvider);
          if (!authState.onboardingComplete) {
            context.go('/onboarding');
          } else if (!authState.isLoggedIn) {
            context.go('/login');
          } else {
            context.go('/home');
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Architectural emblem mark
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: palette.primaryGradient,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: palette.primary.withValues(alpha: 0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.diamond_outlined,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Brand name in Playfair Display
                  Text(
                    'GRAZIA',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 8,
                      color: palette.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    'NATURAL STONE',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 5,
                      color: palette.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Gold accent line
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      return Opacity(
                        opacity: _lineOpacityAnimation.value,
                        child: Container(
                          width: _lineWidthAnimation.value,
                          height: 1.5,
                          decoration: BoxDecoration(
                            gradient: palette.primaryGradient,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
