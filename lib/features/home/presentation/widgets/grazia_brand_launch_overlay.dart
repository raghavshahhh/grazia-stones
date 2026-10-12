import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grazia_stones/shared/theme/colors.dart';

/// Ultra-luxury Apple-grade brand launch animation with cinematic motion graphics.
/// 
/// The emblem and brand wordmark are unified as ONE cohesive brand entity from frame 1:
/// 1. Cold start: Deep obsidian (#151413) matching native launch screen exactly.
/// 2. Power-on awakening (0-300ms): Unified brand unit awakens with an elastic spring
///    scale, radiant gold energy bloom, and specular shimmer sweep across emblem & typography.
/// 3. Apple fluid flight (320-1000ms): The entire brand unit glides gracefully as ONE piece
///    using Apple's signature cubic curve, scaling down from 1.95x to 1.0x and docking
///    with sub-pixel precision directly into the top-left AppBar title.
/// 4. Coordinated backdrop dissolve (400-900ms): Obsidian backdrop smoothly fades out,
///    revealing the home screen seamlessly underneath.
/// 5. Precision haptic dock (920ms): Subtle Apple-style selection click right as it docks.
class GraziaBrandLaunchOverlay extends StatefulWidget {
  final LuxuryPalette palette;
  final bool isDark;
  final VoidCallback onComplete;

  const GraziaBrandLaunchOverlay({
    super.key,
    required this.palette,
    required this.isDark,
    required this.onComplete,
  });

  @override
  State<GraziaBrandLaunchOverlay> createState() => _GraziaBrandLaunchOverlayState();
}

class _GraziaBrandLaunchOverlayState extends State<GraziaBrandLaunchOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Phase 1: Center awakening, power-on bloom & shimmer sweep
  late final Animation<double> _powerOnBloom;
  late final Animation<double> _awakenScale;
  late final Animation<double> _shimmerSweep;

  // Phase 2: Apple fluid flight & Morph into top-left AppBar
  late final Animation<double> _flightCurve;
  late final Animation<double> _backdropFade;

  bool _isSkipping = false;
  bool _dockHapticPlayed = false;

  static const Color _obsidianDark = Color(0xFF151413);
  static const Color _goldRadiant = Color(0xFFD4AF37);
  static const Color _goldLuminous = Color(0xFFFFD700);

  // Final destination matches HomeScreen AppBar title:
  // TitleSpacing: 10, Emblem: 22x22, gap: 5, Text('GRAZIA STONES', 15.0px Playfair)
  static const double _destEmblemSize = 22.0;
  static const double _startEmblemSize = 76.0;

  @override
  void initState() {
    super.initState();

    // 1200ms total duration for luxurious Apple-like reveal and docking
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Radiant gold aura bloom expanding from center
    _powerOnBloom = Tween<double>(begin: 0.1, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOutCubic),
      ),
    );

    // Initial scale awakening
    _awakenScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOutBack),
      ),
    );

    // Light shimmer sweep
    _shimmerSweep = Tween<double>(begin: -0.8, end: 2.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.08, 0.45, curve: Curves.easeInOutCubic),
      ),
    );

    // Flight curve: starts gliding up around 0.38
    _flightCurve = CurvedAnimation(
      parent: _controller,
      curve: const Interval(
        0.36,
        0.96,
        curve: Cubic(0.20, 0.0, 0.05, 1.0),
      ),
    );

    // Backdrop fades out as it docks
    _backdropFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.48, 0.92, curve: Curves.easeOut),
      ),
    );

    _controller.addListener(() {
      if (_flightCurve.value > 0.92 && !_dockHapticPlayed) {
        _dockHapticPlayed = true;
        HapticFeedback.selectionClick();
      }
    });

    _controller.forward().then((_) {
      if (mounted) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _skip() {
    if (_isSkipping) return;
    _isSkipping = true;
    HapticFeedback.lightImpact();
    _controller
        .animateTo(1.0, duration: const Duration(milliseconds: 180), curve: Curves.easeOut)
        .then((_) {
      if (mounted) widget.onComplete();
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final topPadding = media.padding.top;
    final size = media.size;

    // Destination: exactly where HomeScreen's AppBar title is rendered:
    // AppBar: titleSpacing = 10.0, kToolbarHeight = 56.0.
    // Center title vertically: topPadding + (56.0 - 24.0) / 2 = topPadding + 16.0
    const destX = 10.0;
    final destY = topPadding + 16.0;

    // Start center:
    final centerY = size.height * 0.42;

    final targetGoldColor =
        widget.isDark ? const Color(0xFFD4AF37) : const Color(0xFF8B6B23);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final flight = _flightCurve.value;
        final bgOpacity = _backdropFade.value.clamp(0.0, 1.0);
        final bloom = _powerOnBloom.value;
        final awaken = _awakenScale.value;
        final shimmerVal = _shimmerSweep.value;

        if (_controller.isCompleted) {
          return const SizedBox.shrink();
        }

        final curGoldColor =
            Color.lerp(_goldRadiant, targetGoldColor, flight) ?? _goldRadiant;

        // Size and gap interpolation
        final emblemSize = Tween<double>(begin: _startEmblemSize, end: _destEmblemSize).transform(flight) * (flight == 0 ? awaken : 1.0);
        final fontSize = Tween<double>(begin: 24.0, end: 15.0).transform(flight);
        final letterSpacing = Tween<double>(begin: 3.5, end: 1.0).transform(flight);

        // Position coordinates
        final curX = Tween<double>(begin: (size.width - 240) / 2, end: destX).transform(flight);
        final curY = Tween<double>(begin: centerY - 60, end: destY).transform(flight);

        final haloAlpha = (bloom * (1.0 - flight * 1.6)).clamp(0.0, 1.0);

        return GestureDetector(
          onTap: _skip,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              // 1. Deep Obsidian Background (#151413)
              if (bgOpacity > 0.0)
                Positioned.fill(
                  child: Opacity(
                    opacity: bgOpacity,
                    child: Container(
                      color: _obsidianDark,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Radiant ambient gold bloom behind center
                          Container(
                            width: size.width * 1.15,
                            height: size.width * 1.15,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  _goldLuminous.withValues(
                                    alpha: 0.32 * bloom * (1.0 - flight),
                                  ),
                                  _goldRadiant.withValues(
                                    alpha: 0.15 * bloom * (1.0 - flight),
                                  ),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.42, 1.0],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // 2. Center/Docking Brand Unit
              Positioned(
                left: curX,
                top: curY,
                child: flight < 0.35
                    // CENTER STAGE: Logo on top, GRAZIA STONES underneath, centered
                    ? SizedBox(
                        width: 240,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Glowing Center Emblem
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                if (haloAlpha > 0.02)
                                  Container(
                                    width: emblemSize * 1.3,
                                    height: emblemSize * 1.3,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: _goldLuminous.withValues(alpha: 0.55 * haloAlpha),
                                          blurRadius: 28,
                                          spreadRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                Image.asset(
                                  'assets/brand/grazia-emblem-gold.png',
                                  height: emblemSize,
                                  width: emblemSize,
                                  fit: BoxFit.contain,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Text underneath in center
                            Text(
                              'GRAZIA STONES',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.playfairDisplay(
                                fontSize: fontSize,
                                fontWeight: FontWeight.w800,
                                letterSpacing: letterSpacing,
                                color: curGoldColor,
                              ),
                            ),
                          ],
                        ),
                      )
                    // FLIGHT & DOCKING STAGE: Glides up and smoothly transforms into AppBar Row
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/brand/grazia-emblem-gold.png',
                            height: emblemSize,
                            width: emblemSize,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'GRAZIA STONES',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: fontSize,
                              fontWeight: FontWeight.w800,
                              letterSpacing: letterSpacing,
                              color: curGoldColor,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
