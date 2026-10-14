import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grazia_stones/shared/theme/colors.dart';

/// Brand launch motion, shown on every cold start over the home screen.
///
/// One continuous timeline (no widget swaps, so nothing pops):
///   0.00-0.20  the gold emblem fades/scales in at the exact screen centre (same spot and backdrop as
///              the Android system splash, so the hand-over is invisible).
///   0.18-0.50  "GRAZIA STONES" writes in letter by letter under it; the emblem lifts slightly.
///   0.52-0.92  emblem and name glide together, shrinking, into the home AppBar title.
///   0.52-0.90  the dark backdrop dissolves to reveal the home screen.
/// Tap anywhere to skip.
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

  bool _isSkipping = false;
  bool _dockHapticPlayed = false;

  // Same value as the Android system-splash backdrop (ic_launcher_background).
  static const Color _backdrop = Color(0xFF14110D);
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _goldGlow = Color(0xFFFFD700);
  static const Color _cream = Color(0xFFF4E9D3);

  static const String _name = 'GRAZIA STONES';

  // Final destination = HomeScreen AppBar title: toolbar 64, titleSpacing 10, emblem 36, gap 8, 16px Playfair.
  static const double _destEmblem = 36.0;
  static const double _startEmblem = 88.0;
  static const double _destFont = 16.0;
  static const double _startFont = 24.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1700));
    _controller.addListener(() {
      if (_seg(_controller.value, 0.52, 0.92, Curves.linear) > 0.93 && !_dockHapticPlayed) {
        _dockHapticPlayed = true;
        HapticFeedback.selectionClick();
      }
    });
    _controller.forward().then((_) {
      if (mounted) widget.onComplete();
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

  /// Progress 0..1 of [v] inside [from, to], with [curve] applied.
  static double _seg(double v, double from, double to, [Curve curve = Curves.easeOutCubic]) =>
      curve.transform(((v - from) / (to - from)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final destGold = widget.isDark ? const Color(0xFFD4AF37) : const Color(0xFF8B6B23);
    final destX = 10.0;
    final destY = media.padding.top + 20.0; // emblem top: (64 - 36) / 2 = 14, name sits a little higher

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.isCompleted) return const SizedBox.shrink();
        final v = _controller.value;

        final appear = _seg(v, 0.0, 0.20);
        final pop = 0.84 + 0.16 * _seg(v, 0.0, 0.22, Curves.easeOutBack);
        final lift = _seg(v, 0.18, 0.50, Curves.easeInOutCubic);
        final flight = _seg(v, 0.52, 0.92, const Cubic(0.20, 0.0, 0.05, 1.0));
        final bg = 1.0 - _seg(v, 0.52, 0.90, Curves.easeOut);
        final glow = (0.9 * appear * (1.0 - flight * 1.6)).clamp(0.0, 1.0);
        final shimmer = _seg(v, 0.10, 0.42, Curves.easeInOutCubic);

        final emblem = (_startEmblem + (_destEmblem - _startEmblem) * flight) * (flight == 0 ? pop : 1.0);
        final font = _startFont + (_destFont - _startFont) * flight;
        final tracking = (3.5 - 2.5 * flight);
        final textColor = Color.lerp(_cream, destGold, flight) ?? _cream;

        // Emblem centre: exact screen centre -> a little higher while the name appears -> AppBar slot.
        final startCx = size.width / 2;
        final startCy = size.height / 2 - 30 * lift;
        final endCx = destX + _destEmblem / 2;
        final endCy = media.padding.top + 32.0; // emblem centre = middle of the 64 high toolbar
        final endTextCy = media.padding.top + 25.5; // name line sits above the 'Unit of BNK Stones' line
        final cx = startCx + (endCx - startCx) * flight;
        final cy = startCy + (endCy - startCy) * flight;

        // Name: centred under the emblem at first, then left-aligned beside it in the AppBar.
        final textStartCy = startCy + _startEmblem / 2 + 26;
        final textCy = textStartCy + (endTextCy - textStartCy) * flight;
        final textLeftEnd = destX + _destEmblem + 8;
        final textLeft = textLeftEnd * flight;
        final textWidth = size.width + (size.width - textLeftEnd - size.width) * flight; // width -> remaining width
        final textAlignX = -1.0 * flight; // 0 = centred, -1 = left

        return GestureDetector(
          onTap: _skip,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              if (bg > 0)
                Positioned.fill(
                  child: Opacity(
                    opacity: bg.clamp(0.0, 1.0),
                    child: Container(
                      color: _backdrop,
                      alignment: Alignment.center,
                      child: Container(
                        width: size.width * 1.1,
                        height: size.width * 1.1,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              _goldGlow.withValues(alpha: 0.20 * appear * (1.0 - flight)),
                              _gold.withValues(alpha: 0.08 * appear * (1.0 - flight)),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.42, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Emblem
              Positioned(
                left: cx - emblem / 2,
                top: cy - emblem / 2,
                width: emblem,
                height: emblem,
                child: Opacity(
                  opacity: flight > 0 ? 1.0 : appear,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      if (glow > 0.02)
                        Container(
                          width: emblem * 1.15,
                          height: emblem * 1.15,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: _goldGlow.withValues(alpha: 0.45 * glow), blurRadius: 30, spreadRadius: 3)],
                          ),
                        ),
                      Image.asset('assets/brand/grazia-emblem-gold.png', width: emblem, height: emblem, fit: BoxFit.contain),
                      if (shimmer > 0 && shimmer < 1)
                        ClipRect(
                          child: Transform.translate(
                            offset: Offset((shimmer - 0.5) * emblem * 1.8, 0),
                            child: Transform.rotate(
                              angle: 0.6,
                              child: Container(
                                width: emblem * 0.2,
                                height: emblem * 1.6,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [
                                    Colors.white.withValues(alpha: 0),
                                    Colors.white.withValues(alpha: 0.35),
                                    Colors.white.withValues(alpha: 0),
                                  ]),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Name, letter by letter
              Positioned(
                left: textLeft,
                top: textCy - 20,
                width: textWidth,
                height: 40,
                child: Align(
                  alignment: Alignment(textAlignX, 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < _name.length; i++)
                        Builder(builder: (_) {
                          final t = flight > 0 ? 1.0 : _seg(v, 0.18 + i * 0.016, 0.34 + i * 0.016);
                          return Opacity(
                            opacity: t,
                            child: Transform.translate(
                              offset: Offset(0, 12 * (1 - t) * (1 - flight)),
                              child: Padding(
                                padding: EdgeInsets.only(right: i == _name.length - 1 ? 0 : tracking),
                                child: Text(
                                  _name[i],
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: font,
                                    fontWeight: FontWeight.w800,
                                    color: textColor,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
