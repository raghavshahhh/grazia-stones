import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:grazia_stones/features/auth/providers/auth_provider.dart';
import 'package:grazia_stones/shared/theme/colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeInOut),
      ),
    );

    _controller.forward();

    // Navigate after animation completes
    Timer(const Duration(milliseconds: 2800), () {
      if (mounted) {
        final auth = context.read<AuthProvider>();
        if (auth.onboardingComplete) {
          context.go('/home');
        } else {
          context.go('/onboarding');
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = GLuxuryPalettes.gold;
    
    return Scaffold(
      backgroundColor: palette.background,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: child,
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo circle with gradient border
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: palette.primaryGradient,
                      boxShadow: [
                        BoxShadow(
                          color: palette.primary.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: palette.background,
                      ),
                      child: Center(
                        child: ShaderMask(
                          shaderCallback: (bounds) =>
                              palette.primaryGradient.createShader(bounds),
                          child: const Text(
                            'G',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 48,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Brand name with gradient
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        palette.primaryGradient.createShader(bounds),
                    child: const Text(
                      'GRAZIA',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  
                  // Subtitle
                  Text(
                    'S T O N E S',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 10,
                      color: palette.textSecondary.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  
                  // Tagline
                  Text(
                    'Luxury Redefined',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 2,
                      color: palette.textTertiary.withValues(alpha: 0.5),
                    ),
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
