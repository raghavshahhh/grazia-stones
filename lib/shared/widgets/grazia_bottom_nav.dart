import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:grazia_stones/shared/theme/colors.dart';

/// Apple-style floating pill bottom navigation bar.
/// Features: floating pill shape, blur backdrop, gold active indicator,
/// center raised Live AI button, smooth scale animations.
class GraziaBottomNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const GraziaBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<GraziaBottomNav> createState() => _GraziaBottomNavState();
}

class _GraziaBottomNavState extends State<GraziaBottomNav> {
  static const _items = [
    _NavItem(icon: Icons.home_rounded, label: 'Home'),
    _NavItem(icon: Icons.grid_view_rounded, label: 'Collections'),
    _NavItem(icon: Icons.camera_rounded, label: 'Live AI', isCenter: true),
    _NavItem(icon: Icons.shopping_bag_rounded, label: 'Cart'),
    _NavItem(icon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final palette = GLuxuryPalettes.gold;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: bottomPadding + 8,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              color: palette.surface.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: palette.border.withValues(alpha: 0.4),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 24,
                  spreadRadius: -4,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: palette.primary.withValues(alpha: 0.06),
                  blurRadius: 12,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_items.length, (i) {
                final item = _items[i];
                final isActive = widget.currentIndex == i;
                if (item.isCenter) {
                  return _buildCenterButton(i, isActive, palette);
                }
                return _buildNavItem(i, item, isActive, palette);
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    _NavItem item,
    bool isActive,
    GoldPalette palette,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap(index);
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              width: isActive ? 32 : 0,
              height: 3,
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                gradient: isActive ? palette.primaryGradient : null,
                borderRadius: BorderRadius.circular(2),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: palette.primary.withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: -2,
                        ),
                      ]
                    : null,
              ),
            ),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 22,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive
                    ? palette.primary
                    : palette.textTertiary,
              ),
              child: Icon(
                item.icon,
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive
                    ? palette.primary
                    : palette.textTertiary,
                letterSpacing: 0.3,
              ),
              child: Text(item.label),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterButton(
    int index,
    bool isActive,
    GoldPalette palette,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onTap(index);
      },
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: palette.primaryGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: palette.primary.withValues(alpha: 0.35),
                    blurRadius: 16,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: AnimatedScale(
                scale: isActive ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(
                  Icons.camera_rounded,
                  size: 20,
                  color: Color(0xFF0D0D0D),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Live AI',
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive
                    ? palette.primary
                    : palette.textTertiary,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final bool isCenter;

  const _NavItem({
    required this.icon,
    required this.label,
    this.isCenter = false,
  });
}
