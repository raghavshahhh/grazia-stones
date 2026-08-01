import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:grazia_stones/core/constants/app_colors.dart';
import 'package:grazia_stones/core/constants/app_dimensions.dart';

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
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.charcoal,
            border: Border(
              top: BorderSide(color: AppColors.slate, width: 0.5),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: AppDimensions.bottomNavHeight,
              child: Row(
                children: [
                  _buildItem(0, Icons.home_outlined, Icons.home_rounded, 'Home'),
                  _buildItem(
                      1, Icons.grid_view_outlined, Icons.grid_view, 'Collections'),
                  _buildItem(
                      2, Icons.auto_awesome_outlined, Icons.auto_awesome, 'AI Viz'),
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
              duration: const Duration(milliseconds: 200),
              width: isActive ? 48 : 40,
              height: 3,
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: isActive ? AppColors.goldWarm : Colors.transparent,
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              ),
            ),
            Icon(
              isActive ? filledIcon : outlineIcon,
              size: 22,
              color: isActive ? AppColors.goldWarm : AppColors.silverDark,
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
