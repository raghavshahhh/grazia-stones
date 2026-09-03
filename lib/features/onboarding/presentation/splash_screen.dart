import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/services/storage_service.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/shared/widgets/grazia_logo.dart';

/// Brand animation shown on cold start. Plays [_splashAsset] once, then routes
/// on. If the video can't load or stalls, [_maxSplashDuration] still moves the
/// user along — the splash must never be able to trap the app.
const String _splashAsset = 'assets/video/splash_logo.mp4';
const Duration _maxSplashDuration = Duration(seconds: 6);

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
  VideoPlayerController? _controller;
  Timer? _failsafe;
  bool _videoReady = false;

  @override
  void initState() {
    super.initState();
    if (widget.skipDelay || _animationPlayedThisLaunch) {
      // Tests/deep links, or a re-mount after the animation already ran.
      WidgetsBinding.instance.addPostFrameCallback((_) => _navigateNext());
      return;
    }
    _animationPlayedThisLaunch = true;
    _failsafe = Timer(_maxSplashDuration, _navigateNext);
    _initVideo();
  }

  Future<void> _initVideo() async {
    final controller = VideoPlayerController.asset(_splashAsset);
    _controller = controller;
    controller.addListener(_onTick);
    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() => _videoReady = true);
      await controller.setVolume(0);
      await controller.play();
    } catch (_) {
      // Asset missing or codec unsupported — fall back to the static logo and
      // move on rather than showing a blank screen.
      if (mounted) _navigateNext();
    }
  }

  void _onTick() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.hasError) {
      _navigateNext();
      return;
    }
    final pos = c.value.position;
    final dur = c.value.duration;
    if (dur > Duration.zero && pos >= dur) _navigateNext();
  }

  void _navigateNext() {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;
    _failsafe?.cancel();

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
  void dispose() {
    _failsafe?.cancel();
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);
    final controller = _controller;

    return Scaffold(
      backgroundColor: palette.background,
      body: GestureDetector(
        onTap: _navigateNext,
        behavior: HitTestBehavior.opaque,
        child: _videoReady && controller != null
            ? SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller.value.size.width,
                    height: controller.value.size.height,
                    child: VideoPlayer(controller),
                  ),
                ),
              )
            : Center(
                child: GraziaAnimatedSplashLogo(
                  onAnimationComplete: _navigateNext,
                ),
              ),
      ),
    );
  }
}
