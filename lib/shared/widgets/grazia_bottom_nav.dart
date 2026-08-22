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
    final isDark = ref.watch(themePaletteProvider.notifier).isDarkMode;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: bottomPadding + 8,
          ),
          child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              color: palette.surface.withValues(alpha: isDark ? 0.90 : 0.96),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: palette.border,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
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
        height: 58,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              item.icon,
              size: 20,
              color: isActive ? palette.primary : palette.textTertiary,
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? palette.textPrimary : palette.textTertiary,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isActive ? 4 : 0,
              height: 4,
              decoration: BoxDecoration(
                color: isActive ? palette.primary : Colors.transparent,
                shape: BoxShape.circle,
              ),
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
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        height: 58,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: palette.primaryGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: palette.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.camera_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Live AI',
              style: TextStyle(
                fontSize: 9,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                color: isActive ? palette.primary : palette.textSecondary,
                letterSpacing: 0.2,
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
