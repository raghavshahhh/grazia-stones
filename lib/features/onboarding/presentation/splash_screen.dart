import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/services/storage_service.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/shared/widgets/grazia_logo.dart';

/// Brand animation shown on cold start, then routes on.
///
/// Was previously a bundled 720x1280 video stretched full-screen with
/// BoxFit.cover — on any screen taller than ~1280px (i.e. most phones) that's
/// a 2x+ upscale of a fairly low-res source, which read as visibly blurry.
/// GraziaAnimatedSplashLogo reproduces the same reveal (emblem scale/fade,
/// wordmark, gold divider, slogan) from vector text + a 481x351 PNG emblem,
/// so it's crisp at any resolution and doesn't need a decoder warm-up.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key, this.skipDelay = false});
  final bool skipDelay;

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  /// The router is rebuilt whenever auth state changes and its initialLocation
  /// is '/', so this screen re-mounts several times per launch. The brand
  /// animation should only play on the first mount — every later one passes
  /// straight through. Process-level, so it resets on a real cold start.
  static bool _animationPlayedThisLaunch = false;

  bool _hasNavigated = false;
  late final bool _shouldPlayAnimation;

  @override
  void initState() {
    super.initState();
    _shouldPlayAnimation = !widget.skipDelay && !_animationPlayedThisLaunch;
    if (_shouldPlayAnimation) {
      _animationPlayedThisLaunch = true;
    } else {
      // Tests/deep links, or a re-mount after the animation already ran.
      WidgetsBinding.instance.addPostFrameCallback((_) => _navigateNext());
    }
  }

  void _navigateNext() {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;

    final onboardingComplete = StorageService.instance.getOnboardingCompleted() ||
        ref.read(authRiverpodProvider).onboardingComplete;
    final authState = ref.read(authRiverpodProvider);

    if (!onboardingComplete) {
      context.go('/onboarding');
    } else {
      context.go('/home');
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
          child: _shouldPlayAnimation
              ? GraziaAnimatedSplashLogo(onAnimationComplete: _navigateNext)
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}
