import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';

/// Apple/iOS Liquid Glass bottom navigation bar featuring an iridescent
/// chromatic refraction slider bubble that smoothly slides across tabs.
class GraziaBottomNav extends ConsumerStatefulWidget {
  static final GlobalKey aiStudioKey = GlobalKey();
  static final GlobalKey collectionsKey = GlobalKey();

  final int currentIndex;
  final ValueChanged<int> onTap;

  const GraziaBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  ConsumerState<GraziaBottomNav> createState() => _GraziaBottomNavState();
}

class _GraziaBottomNavState extends ConsumerState<GraziaBottomNav> {
  static const _items = [
    _NavItem(icon: Icons.home_rounded, label: 'Home'),
    _NavItem(icon: Icons.grid_view_rounded, label: 'Collections'),
    _NavItem(icon: Icons.auto_awesome_rounded, label: 'AI Studio'),
    _NavItem(icon: Icons.view_in_ar_rounded, label: 'VR'),
    _NavItem(icon: Icons.person_rounded, label: 'Profile'),
  ];

  int? _draggedIndex;

  void _handleDrag(Offset localPosition, double totalWidth) {
    const padH = 4.0;
    final usableW = totalWidth - (padH * 2);
    if (usableW <= 0) return;
    final itemW = usableW / _items.length;
    final index = ((localPosition.dx - padH) / itemW)
        .floor()
        .clamp(0, _items.length - 1);
    if (index != widget.currentIndex && index != _draggedIndex) {
      _draggedIndex = index;
      HapticFeedback.selectionClick();
      widget.onTap(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final palette = ref.watch(themePaletteProvider);
    final isDark = ref.watch(themePaletteProvider.notifier).isDarkMode;

    // Compact floating dock sizing
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 356),
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: bottomPadding > 0 ? bottomPadding + 6 : 14,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                height: 58,
                decoration: BoxDecoration(
                  // Dynamic liquid frosted glass fill
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDark
                        ? [
                            const Color(0xFF1B1C22).withValues(alpha: 0.70),
                            const Color(0xFF0F1014).withValues(alpha: 0.62),
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.85),
                            Colors.white.withValues(alpha: 0.70),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.16)
                        : Colors.black.withValues(alpha: 0.08),
                    width: 0.9,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.10),
                      blurRadius: 26,
                      spreadRadius: -2,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: const Color(0xFFE040FB).withValues(alpha: isDark ? 0.06 : 0.03),
                      blurRadius: 20,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const padH = 4.0;
                    const padV = 4.0;
                    final totalW = constraints.maxWidth;
                    final usableW = totalW - (padH * 2);
                    final itemW = usableW / _items.length;
                    final targetLeft = padH + (widget.currentIndex.clamp(0, _items.length - 1) * itemW);

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) => _handleDrag(details.localPosition, totalW),
                      onHorizontalDragStart: (details) => _handleDrag(details.localPosition, totalW),
                      onHorizontalDragUpdate: (details) => _handleDrag(details.localPosition, totalW),
                      onHorizontalDragEnd: (_) => _draggedIndex = null,
                      child: Stack(
                        children: [
                          // 1. Sliding Iridescent Liquid Bubble Lens (Refractive Rainbow Edge)
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 320),
                            curve: Curves.easeInOutCubic,
                            left: targetLeft,
                            top: padV,
                            width: itemW,
                            height: 58 - (padV * 2),
                            child: _IridescentLiquidBubble(
                              isDark: isDark,
                              palette: palette,
                            ),
                          ),

                          // 2. Interactive Navigation Items
                          Row(
                            children: List.generate(_items.length, (i) {
                              final item = _items[i];
                              final isActive = widget.currentIndex == i;
                              return Expanded(
                                child: _buildNavItem(
                                  index: i,
                                  item: item,
                                  isActive: isActive,
                                  palette: palette,
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required _NavItem item,
    required bool isActive,
    required LuxuryPalette palette,
  }) {
    Key? targetKey;
    if (index == 1) targetKey = GraziaBottomNav.collectionsKey;
    if (index == 2) targetKey = GraziaBottomNav.aiStudioKey;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: targetKey,
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap(index);
        },
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: isActive ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutBack,
                child: Icon(
                  item.icon,
                  size: 20,
                  color: isActive ? palette.primary : palette.textTertiary,
                  shadows: isActive
                      ? [
                          Shadow(
                            color: palette.primary.withValues(alpha: 0.65),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 9.5,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? palette.textPrimary : palette.textTertiary,
                  letterSpacing: 0.15,
                ),
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.label,
  });
}

/// The Liquid Glass Iridescent Bubble Lens Slider
class _IridescentLiquidBubble extends StatelessWidget {
  final bool isDark;
  final LuxuryPalette palette;

  const _IridescentLiquidBubble({
    required this.isDark,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: CustomPaint(
        painter: _LiquidBubblePainter(
          isDark: isDark,
          palette: palette,
        ),
      ),
    );
  }
}

class _LiquidBubblePainter extends CustomPainter {
  final bool isDark;
  final LuxuryPalette palette;

  _LiquidBubblePainter({
    required this.isDark,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(size.height / 2));

    // 1. Ambient outer prismatic glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.85,
        colors: [
          const Color(0xFFE040FB).withValues(alpha: isDark ? 0.22 : 0.15),
          const Color(0xFF00E5FF).withValues(alpha: isDark ? 0.18 : 0.12),
          Colors.transparent,
        ],
      ).createShader(rect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRRect(rrect.deflate(1), glowPaint);

    // 2. Liquid Glass Body (Translucent refractive lens)
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [
                Colors.white.withValues(alpha: 0.16),
                const Color(0xFF1E1F24).withValues(alpha: 0.35),
              ]
            : [
                Colors.white.withValues(alpha: 0.65),
                Colors.white.withValues(alpha: 0.25),
              ],
      ).createShader(rect);
    canvas.drawRRect(rrect, bodyPaint);

    // 3. Chromatic Iridescent Refractive Rim (Rainbow edge matching reference)
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..shader = SweepGradient(
        center: Alignment.center,
        colors: const [
          Color(0xFF00F0FF), // Electric Cyan
          Color(0xFF7000FF), // Deep Violet
          Color(0xFFFF007A), // Hot Magenta / Red
          Color(0xFFFFB800), // Amber Gold
          Color(0xFF00FF85), // Emerald / Mint
          Color(0xFF00F0FF), // Return to Cyan
        ],
        stops: const [0.0, 0.22, 0.48, 0.72, 0.88, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect.deflate(0.9), rimPaint);

    // 4. Upper Specular Lens Reflection (curved glassy highlight)
    final highlightPath = Path()
      ..addArc(
        Rect.fromLTWH(rect.left + 3, rect.top + 1.5, rect.width - 6, (size.height / 2) + 2),
        3.14159,
        3.14159,
      );
    final highlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: isDark ? 0.85 : 0.95),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(rect);
    canvas.drawPath(highlightPath, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant _LiquidBubblePainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
