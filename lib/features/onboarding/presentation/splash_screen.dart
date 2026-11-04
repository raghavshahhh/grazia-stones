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
  bool _waitingForSignIn = false;
  late final bool _shouldPlayAnimation;

  @override
  void initState() {
    super.initState();
    final onboardingComplete = StorageService.instance.getOnboardingCompleted() ||
        ref.read(authRiverpodProvider).onboardingComplete;
    if (onboardingComplete) {
      _shouldPlayAnimation = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _navigateNext());
    } else {
      _shouldPlayAnimation = !widget.skipDelay && !_animationPlayedThisLaunch;
      if (_shouldPlayAnimation) {
        _animationPlayedThisLaunch = true;
      } else {
        // Tests/deep links, or a re-mount after the animation already ran.
        WidgetsBinding.instance.addPostFrameCallback((_) => _navigateNext());
      }
    }
  }

  void _navigateNext() {
    if (!mounted || _hasNavigated) return;
    // Wait for the saved session (at most ~10 s, see AuthRiverpodNotifier._start) so a signed-in user lands on
    // Home, not on Login while the session is still restoring.
    if (!ref.read(authRiverpodProvider).sessionChecked) {
      ref.listenManual(authRiverpodProvider, (_, next) {
        if (next.sessionChecked) _navigateNext();
      });
      return;
    }
    // Google / email-confirm links reopen the app at '/' (?code=...). Wait for that session (at most 15 s) instead
    // of bouncing through Login first, which looked like the sign-in had failed.
    final uri = GoRouterState.of(context).uri;
    final isAuthCallback = uri.queryParameters.containsKey('code') || uri.fragment.contains('access_token');
    if (isAuthCallback && !ref.read(authRiverpodProvider).isLoggedIn && !_waitingForSignIn) {
      setState(() => _waitingForSignIn = true);
      ref.listenManual(authRiverpodProvider, (_, next) {
        if (next.isLoggedIn) _navigateNext();
      });
      Future.delayed(const Duration(seconds: 15), _navigateNext);
      return;
    }
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
      backgroundColor: GraziaAnimatedSplashLogo.backdrop,
      body: GestureDetector(
        onTap: _navigateNext,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: _shouldPlayAnimation
              ? GraziaAnimatedSplashLogo(onAnimationComplete: _navigateNext)
              : _waitingForSignIn
                  ? Column(mainAxisSize: MainAxisSize.min, children: [
                      const SizedBox(width: 28, height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD6B26A))),
                      const SizedBox(height: 16),
                      Text('Signing you in…',
                          style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: Colors.white.withValues(alpha: 0.8))),
                    ])
                  : const SizedBox.shrink(),
        ),
      ),
    );
  }
}
