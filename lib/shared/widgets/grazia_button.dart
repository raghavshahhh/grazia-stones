import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/core/constants/app_dimensions.dart';
import 'package:grazia_stones/core/theme/glass_theme.dart';

enum GraziaButtonVariant { primary, secondary, outline, ghost, glass }

class GraziaButton extends StatefulWidget {
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
  State<GraziaButton> createState() => _GraziaButtonState();
}

class _GraziaButtonState extends State<GraziaButton>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final effectiveHeight = widget.height ?? AppDimensions.buttonHeight;
    final palette = GLuxuryPalettes.gold;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: GlassTheme.durationNormal,
          curve: Curves.easeOutCubic,
          width: widget.isFullWidth ? double.infinity : null,
          height: effectiveHeight,
          transform: _isPressed
              ? (Matrix4.diagonal3Values(0.97, 0.97, 0.97))
              : (_isHovered
                  ? (Matrix4.diagonal3Values(1.02, 1.02, 1.02))
                  : Matrix4.identity()),
          transformAlignment: Alignment.center,
          child: switch (widget.variant) {
            GraziaButtonVariant.primary =>
              _buildPrimary(effectiveHeight, palette),
            GraziaButtonVariant.secondary =>
              _buildSecondary(effectiveHeight, palette),
            GraziaButtonVariant.outline =>
              _buildOutline(effectiveHeight, palette),
            GraziaButtonVariant.ghost => _buildGhost(effectiveHeight, palette),
            GraziaButtonVariant.glass => _buildGlass(effectiveHeight, palette),
          },
        ),
      ),
    );
  }

  Widget _buildPrimary(double h, LuxuryPalette p) {
    return Container(
      decoration: BoxDecoration(
        gradient: widget.isLoading ? null : p.primaryGradient,
        color: widget.isLoading ? p.primary.withValues(alpha: 0.5) : null,
        borderRadius: BorderRadius.circular(AppDimensions.buttonBorderRadius),
        boxShadow: [
          BoxShadow(
            color: p.primary.withValues(alpha: _isHovered ? 0.45 : 0.25),
            blurRadius: _isHovered ? 28 : 18,
            spreadRadius: _isHovered ? -2 : 0,
          ),
        ],
      ),
      child: MaterialButton(
        onPressed: widget.isLoading ? null : widget.onPressed,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.buttonBorderRadius),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg),
        child: _buildChild(p.background),
      ),
    );
  }

  Widget _buildSecondary(double h, LuxuryPalette p) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimensions.buttonBorderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            color: _isHovered
                ? p.surface.withValues(alpha: 0.9)
                : p.surface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(AppDimensions.buttonBorderRadius),
            border: Border.all(
              color: p.textPrimary.withValues(alpha: _isHovered ? 0.1 : 0.05),
              width: 0.5,
            ),
          ),
          child: MaterialButton(
            onPressed: widget.isLoading ? null : widget.onPressed,
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(AppDimensions.buttonBorderRadius),
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg),
            child: _buildChild(p.textPrimary),
          ),
        ),
      ),
    );
  }

  Widget _buildOutline(double h, LuxuryPalette p) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.buttonBorderRadius),
        border: Border.all(
          color: _isHovered
              ? p.primary.withValues(alpha: 0.4)
              : p.accent.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: _isHovered
            ? [
                BoxShadow(
                  color: p.primary.withValues(alpha: 0.08),
                  blurRadius: 16,
                ),
              ]
            : null,
      ),
      child: OutlinedButton(
        onPressed: widget.isLoading ? null : widget.onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: Size(widget.isFullWidth ? double.infinity : 0, h),
          foregroundColor: _isHovered ? p.primary : p.textSecondary,
          backgroundColor:
              _isHovered ? p.primary.withValues(alpha: 0.04) : Colors.transparent,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppDimensions.buttonBorderRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg),
        ),
        child: _buildChild(_isHovered ? p.primary : p.textSecondary),
      ),
    );
  }

  Widget _buildGhost(double h, LuxuryPalette p) {
    return TextButton(
      onPressed: widget.isLoading ? null : widget.onPressed,
      style: TextButton.styleFrom(
        minimumSize: Size(widget.isFullWidth ? double.infinity : 0, h),
        foregroundColor: p.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.buttonBorderRadius),
        ),
      ),
      child: _buildChild(p.primary),
    );
  }

  Widget _buildGlass(double h, LuxuryPalette p) {
    return GlassTheme.glassButton(
      onPressed: widget.onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.lg, vertical: 14),
        child: _buildChild(p.textPrimary),
      ),
    );
  }

  Widget _buildChild(Color textColor) {
    if (widget.isLoading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
        ),
      );
    }

    if (widget.icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.icon, size: 20, color: textColor),
          const SizedBox(width: AppDimensions.xs),
          Text(
            widget.label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: textColor,
            ),
          ),
        ],
      );
    }

    return Text(
      widget.label,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: textColor,
      ),
    );
  }
}
