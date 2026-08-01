import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:grazia_stones/core/constants/app_colors.dart';
import 'package:grazia_stones/core/constants/app_dimensions.dart';
import 'package:grazia_stones/core/theme/glass_theme.dart';

class GraziaBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const GraziaBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: GlassTheme.blurHeavy, sigmaY: GlassTheme.blurHeavy),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.charcoal.withOpacity(0.8),
            border: Border(
              top: BorderSide(
                color: AppColors.goldWarm.withOpacity(0.08),
                width: 0.5,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: -4,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: AppDimensions.bottomNavHeight,
              child: Row(
                children: [
                  _buildItem(0, Icons.home_outlined, Icons.home_rounded, 'Home'),
                  _buildItem(1, Icons.grid_view_outlined, Icons.grid_view, 'Collections'),
                  _buildLiveAIButton(2),
                  _buildItem(3, Icons.shopping_bag_outlined, Icons.shopping_bag, 'Cart'),
                  _buildItem(4, Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLiveAIButton(int index) {
    final isActive = currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: GlassTheme.durationNormal,
              curve: Curves.easeOutCubic,
              width: isActive ? 48 : 0,
              height: 3,
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                gradient: isActive ? AppColors.goldGradient : null,
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                boxShadow: isActive ? GlassTheme.goldGlow(blur: 8, spread: -2) : null,
              ),
            ),
            AnimatedContainer(
              duration: GlassTheme.durationNormal,
              padding: isActive
                  ? const EdgeInsets.symmetric(horizontal: 12, vertical: 4)
                  : EdgeInsets.zero,
              decoration: isActive
                  ? BoxDecoration(
                      color: AppColors.goldWarm.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    )
                  : null,
              child: isActive
                  ? const Icon(
                      Icons.camera_rounded,
                      size: 22,
                      color: AppColors.goldWarm,
                    )
                  : Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: AppColors.goldGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.goldWarm.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.camera_rounded,
                        size: 18,
                        color: Colors.black,
                      ),
                    ),
            ),
            const SizedBox(height: 2),
            Text(
              'Live AI',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                color: isActive ? AppColors.goldWarm : AppColors.goldWarm.withOpacity(0.8),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(int index, IconData outlineIcon, IconData filledIcon, String label) {
    final isActive = currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: GlassTheme.durationNormal,
              curve: Curves.easeOutCubic,
              width: isActive ? 48 : 0,
              height: 3,
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                gradient: isActive ? AppColors.goldGradient : null,
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                boxShadow: isActive ? GlassTheme.goldGlow(blur: 8, spread: -2) : null,
              ),
            ),
            AnimatedContainer(
              duration: GlassTheme.durationNormal,
              padding: isActive
                  ? const EdgeInsets.symmetric(horizontal: 12, vertical: 4)
                  : EdgeInsets.zero,
              decoration: isActive
                  ? BoxDecoration(
                      color: AppColors.goldWarm.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    )
                  : null,
              child: Icon(
                isActive ? filledIcon : outlineIcon,
                size: 22,
                color: isActive ? AppColors.goldWarm : AppColors.silverDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? AppColors.goldWarm : AppColors.silverDark,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
