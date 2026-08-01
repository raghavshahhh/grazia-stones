import 'package:flutter/material.dart';
import 'package:grazia_stones/core/constants/app_colors.dart';
import 'package:grazia_stones/core/constants/app_dimensions.dart';

enum GraziaButtonVariant { primary, secondary, outline, ghost }

class GraziaButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final GraziaButtonVariant variant;
  final bool isLoading;
  final bool isFullWidth;
  final IconData? icon;
  final double? height;

  const GraziaButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = GraziaButtonVariant.primary,
    this.isLoading = false,
    this.isFullWidth = true,
    this.icon,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveHeight = height ?? AppDimensions.buttonHeight;

    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: effectiveHeight,
      child: switch (variant) {
        GraziaButtonVariant.primary => _buildPrimary(effectiveHeight),
        GraziaButtonVariant.secondary => _buildSecondary(effectiveHeight),
        GraziaButtonVariant.outline => _buildOutline(effectiveHeight),
        GraziaButtonVariant.ghost => _buildGhost(effectiveHeight),
      },
    );
  }

  Widget _buildPrimary(double h) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: isLoading ? null : AppColors.goldGradient,
        color: isLoading ? AppColors.goldDark.withOpacity(0.5) : null,
        borderRadius: BorderRadius.circular(AppDimensions.buttonBorderRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.goldWarm.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: MaterialButton(
        onPressed: isLoading ? null : onPressed,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(AppDimensions.buttonBorderRadius),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg),
        child: _buildChild(AppColors.black),
      ),
    );
  }

  Widget _buildSecondary(double h) {
    return MaterialButton(
      onPressed: isLoading ? null : onPressed,
      color: AppColors.graphite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.buttonBorderRadius),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg),
      child: _buildChild(AppColors.white),
    );
  }

  Widget _buildOutline(double h) {
    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: Size(isFullWidth ? double.infinity : 0, h),
        side: const BorderSide(color: AppColors.silverDark, width: 1.5),
        foregroundColor: AppColors.silverLight,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(AppDimensions.buttonBorderRadius),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg),
      ),
      child: _buildChild(AppColors.silverLight),
    );
  }

  Widget _buildGhost(double h) {
    return TextButton(
      onPressed: isLoading ? null : onPressed,
      style: TextButton.styleFrom(
        minimumSize: Size(isFullWidth ? double.infinity : 0, h),
        foregroundColor: AppColors.goldWarm,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.buttonBorderRadius),
        ),
      ),
      child: _buildChild(AppColors.goldWarm),
    );
  }

  Widget _buildChild(Color textColor) {
    if (isLoading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.black),
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: textColor),
          const SizedBox(width: AppDimensions.xs),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: textColor,
            ),
          ),
        ],
      );
    }

    return Text(
      label,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: textColor,
      ),
    );
  }
}
