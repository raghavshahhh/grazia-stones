import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grazia_stones/core/constants/app_colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';

/// Floating capsule nav (Home, Collections, AI Studio, Profile) plus a separate round gold
/// Live AR hero button on its right.
///
/// [currentIndex] / [onTap] use the shell's tab indices: 0 home, 1 collections, 2 AI studio,
/// 3 Live AR (the round button), 4 profile.
class GraziaBottomNav extends ConsumerStatefulWidget {
  static final GlobalKey aiStudioKey = GlobalKey();
  static final GlobalKey collectionsKey = GlobalKey();
  static final GlobalKey arKey = GlobalKey();
  static final GlobalKey vrKey = arKey; // Kept for backwards compatibility

  static const int arTabIndex = 3;
  static const double barHeight = 64;
  /// Gap under the dock. On a phone with a home indicator the dock sits just above it (the indicator area
  /// is 34 pt; the bar only needs ~20), so it floats low like a native tab bar.
  static double bottomGap(double bottomInset) => bottomInset > 0 ? bottomInset - 14 : 12;

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
  static final _items = [
    const _NavItem(tab: 0, icon: Icons.home_rounded, label: 'Home'),
    _NavItem(tab: 1, icon: Icons.grid_view_rounded, label: 'Collections', key: GraziaBottomNav.collectionsKey),
    _NavItem(tab: 2, icon: Icons.auto_awesome_rounded, label: 'AI Studio', key: GraziaBottomNav.aiStudioKey),
    const _NavItem(tab: 4, icon: Icons.person_rounded, label: 'Profile'),
  ];

  static const _anim = Duration(milliseconds: 250);
  static const _pad = 5.0;

  int? _draggedTab;

  /// The tour keys are global, but during a route transition the old shell's nav is still on screen while the new
  /// one mounts ("Multiple widgets used the same GlobalKey", which corrupted the tree). Only one nav holds them.
  static _GraziaBottomNavState? _keyOwner;
  bool get _ownsKeys => identical(_keyOwner, this);

  @override
  void initState() {
    super.initState();
    _keyOwner ??= this;
  }

  @override
  void dispose() {
    if (_ownsKeys) _keyOwner = null;
    super.dispose();
  }

  void _select(int tab) {
    HapticFeedback.selectionClick();
    widget.onTap(tab);
  }

  void _handleDrag(double dx, double width) {
    final itemW = (width - _pad * 2) / _items.length;
    if (itemW <= 0) return;
    final tab = _items[((dx - _pad) / itemW).floor().clamp(0, _items.length - 1)].tab;
    if (tab != widget.currentIndex && tab != _draggedTab) {
      _draggedTab = tab;
      _select(tab);
    }
  }

  @override
  Widget build(BuildContext context) {
    _keyOwner ??= this;   // the previous owner left (its route finished closing)
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final palette = ref.watch(themePaletteProvider);
    final isDark = ref.watch(themePaletteProvider.notifier).isDarkMode;
    final selectedSlot = _items.indexWhere((i) => i.tab == widget.currentIndex);
    final arSelected = widget.currentIndex == GraziaBottomNav.arTabIndex;
    const h = GraziaBottomNav.barHeight;

    // heightFactor 1: size to the dock itself. Without it Align fills the whole screen height, so the
    // Scaffold reported a full-height bottom bar and every screen got padding.bottom == screen height.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1.0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: EdgeInsets.only(left: 16, right: 16, bottom: GraziaBottomNav.bottomGap(bottomInset)),
            child: SizedBox(
              height: h,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(h / 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                            blurRadius: 24,
                            spreadRadius: -4,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(h / 2),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF16171C).withValues(alpha: 0.78)
                                  : Colors.white.withValues(alpha: 0.80),
                              borderRadius: BorderRadius.circular(h / 2),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.10)
                                    : Colors.black.withValues(alpha: 0.06),
                                width: 0.8,
                              ),
                            ),
                            child: LayoutBuilder(
                              builder: (context, c) {
                                final itemW = (c.maxWidth - _pad * 2) / _items.length;
                                return GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onHorizontalDragUpdate: (d) => _handleDrag(d.localPosition.dx, c.maxWidth),
                                  onHorizontalDragEnd: (_) => _draggedTab = null,
                                  child: Stack(
                                    children: [
                                      AnimatedPositioned(
                                        duration: _anim,
                                        curve: Curves.easeOutCubic,
                                        left: _pad + (selectedSlot < 0 ? 0 : selectedSlot) * itemW,
                                        top: _pad,
                                        width: itemW,
                                        height: h - _pad * 2,
                                        child: AnimatedOpacity(
                                          duration: _anim,
                                          curve: Curves.easeOutCubic,
                                          // On Live AR no pill tab is selected; the round button shows it.
                                          opacity: selectedSlot < 0 ? 0 : 1,
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? Colors.white.withValues(alpha: 0.10)
                                                  : AppColors.goldWarm.withValues(alpha: 0.14),
                                              borderRadius: BorderRadius.circular((h - _pad * 2) / 2),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: _pad),
                                        child: Row(
                                          children: [
                                            for (final item in _items)
                                              Expanded(
                                                child: _PillItem(
                                                  key: _ownsKeys ? item.key : null,
                                                  item: item,
                                                  selected: item.tab == widget.currentIndex,
                                                  idleColor: palette.textSecondary,
                                                  onTap: () => _select(item.tab),
                                                ),
                                              ),
                                          ],
                                        ),
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
                  const SizedBox(width: 10),
                  _ArButton(
                    key: _ownsKeys ? GraziaBottomNav.arKey : null,
                    size: h,
                    selected: arSelected,
                    isDark: isDark,
                    onTap: () => _select(GraziaBottomNav.arTabIndex),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final int tab;
  final IconData icon;
  final String label;
  final GlobalKey? key;

  const _NavItem({required this.tab, required this.icon, required this.label, this.key});
}

class _PillItem extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final Color idleColor;
  final VoidCallback onTap;

  const _PillItem({
    super.key,
    required this.item,
    required this.selected,
    required this.idleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.goldWarm : idleColor;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        customBorder: const StadiumBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
            // scaleDown keeps the label inside the 64px bar at large text scales.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<Color?>(
                    tween: ColorTween(end: color),
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    builder: (_, c, _) => Icon(item.icon, size: 22, color: c),
                  ),
                  const SizedBox(height: 3),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: color,
                      letterSpacing: 0.1,
                    ),
                    child: Text(item.label, maxLines: 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Round gold Live AR hero button that sits outside the pill.
class _ArButton extends StatelessWidget {
  final double size;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _ArButton({
    super.key,
    required this.size,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Live AR',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.goldLight, AppColors.goldWarm, AppColors.goldDark],
          ),
          // Selected: white ring + stronger glow so the hero action reads as the active tab.
          border: Border.all(
            color: selected
                ? (isDark ? Colors.white : Colors.white.withValues(alpha: 0.95))
                : Colors.white.withValues(alpha: 0.18),
            width: selected ? 2.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.goldWarm.withValues(alpha: selected ? 0.55 : 0.35),
              blurRadius: selected ? 22 : 16,
              spreadRadius: selected ? 1 : -2,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: const Center(
              child: Icon(Icons.view_in_ar_rounded, size: 28, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
