import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/shared/widgets/grazia_logo.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key, this.skipDelay = false});
  final bool skipDelay;

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
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
          child: GraziaAnimatedSplashLogo(
            onAnimationComplete: () {
              // Nav handled by timer or callback
            },
          ),
        ),
      ),
    );
  }
}
