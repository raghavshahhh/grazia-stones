import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:grazia_stones/shared/theme/colors.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';

/// Apple-style floating pill bottom navigation bar.
/// Features: floating pill shape, blur backdrop, gold active indicator,
/// center raised Live AI button, smooth scale animations.
class GraziaBottomNav extends ConsumerStatefulWidget {
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
    _NavItem(icon: Icons.camera_rounded, label: 'Live AI', isCenter: true),
    _NavItem(icon: Icons.shopping_bag_rounded, label: 'Cart'),
    _NavItem(icon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final palette = ref.watch(themePaletteProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: bottomPadding + 6,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  palette.surface.withValues(alpha: 0.88),
                  palette.surface.withValues(alpha: 0.78),
                ],
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: palette.border.withValues(alpha: 0.3),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 20,
                  spreadRadius: -6,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: palette.primary.withValues(alpha: 0.08),
                  blurRadius: 16,
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
    LuxuryPalette palette,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap(index);
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              width: isActive ? 28 : 0,
              height: 2,
              margin: const EdgeInsets.only(bottom: 5),
              decoration: BoxDecoration(
                gradient: isActive ? palette.primaryGradient : null,
                borderRadius: BorderRadius.circular(2),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: palette.primary.withValues(alpha: 0.4),
                          blurRadius: 6,
                          spreadRadius: -2,
                        ),
                      ]
                    : null,
              ),
            ),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 20,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive
                    ? palette.primary
                    : palette.textTertiary,
              ),
              child: Icon(
                item.icon,
                size: 20,
              ),
            ),
            const SizedBox(height: 1),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 9,
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
    LuxuryPalette palette,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onTap(index);
      },
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 2),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: palette.primaryGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: palette.primary.withValues(alpha: 0.35),
                    blurRadius: 14,
                    spreadRadius: 0,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: AnimatedScale(
                scale: isActive ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(
                  Icons.camera_rounded,
                  size: 18,
                  color: Color(0xFF0D0D0D),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Live AI',
              style: TextStyle(
                fontSize: 9,
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
