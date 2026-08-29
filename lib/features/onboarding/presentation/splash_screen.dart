import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/services/storage_service.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/shared/widgets/grazia_logo.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key, this.skipDelay = false});
  final bool skipDelay;

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    if (!widget.skipDelay) {
      await Future.delayed(const Duration(milliseconds: 2300));
    }
    _navigateNext();
  }

  void _navigateNext() {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;

    final onboardingComplete = StorageService.instance.getOnboardingCompleted() ||
        ref.read(authRiverpodProvider).onboardingComplete;
    final authState = ref.read(authRiverpodProvider);

    if (!onboardingComplete) {
      context.go('/onboarding');
    } else if (authState.isLoggedIn) {
      context.go('/home');
    } else {
      context.go('/login');
    }
  }


  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);

    return Scaffold(
      backgroundColor: palette.background,
      body: GestureDetector(
        onTap: _navigateNext,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: GraziaAnimatedSplashLogo(
            onAnimationComplete: _navigateNext,
          ),
        ),
      ),
    );
  }
}

