import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:grazia_stones/core/constants/app_colors.dart';

class GlassTheme {
  GlassTheme._();

  // ── Blur Values ──
  static const double blurLight = 10;
  static const double blurMedium = 20;
  static const double blurHeavy = 30;

  // ── Glass Opacity ──
  static const double opacityLight = 0.06;
  static const double opacityMedium = 0.10;
  static const double opacityHeavy = 0.18;
  static const double opacityUltra = 0.25;

  // ── Glass Border ──
  static const double borderThin = 0.5;
  static const double borderMedium = 1.0;

  // ── Animated durations ──
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 250);
  static const Duration durationSlow = Duration(milliseconds: 400);

  // ── Glass Decorations ──
  static BoxDecoration glassLight = BoxDecoration(
    color: AppColors.white.withOpacity(opacityLight),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: AppColors.white.withOpacity(borderThin),
      width: borderThin,
    ),
  );

  static BoxDecoration glassMedium = BoxDecoration(
    color: AppColors.white.withOpacity(opacityMedium),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: AppColors.white.withOpacity(0.12),
      width: borderThin,
    ),
  );

  static BoxDecoration glassHeavy = BoxDecoration(
    color: AppColors.white.withOpacity(opacityHeavy),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      color: AppColors.white.withOpacity(0.15),
      width: borderMedium,
    ),
  );

  // ── Gold Shimmer Decoration ──
  static BoxDecoration goldShimmer = BoxDecoration(
    borderRadius: BorderRadius.circular(16),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        AppColors.goldWarm.withOpacity(0.08),
        AppColors.goldLight.withOpacity(0.04),
        AppColors.goldWarm.withOpacity(0.08),
      ],
    ),
    border: Border.all(
      color: AppColors.goldWarm.withOpacity(0.15),
      width: 0.5,
    ),
  );

  // ── Backdrop Filter Widget ──
  static Widget blur({
    required Widget child,
    double sigmaX = blurMedium,
    double sigmaY = blurMedium,
    double? opacity,
  }) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigmaX, sigmaY: sigmaY),
        child: Container(
          color: opacity != null
              ? AppColors.white.withOpacity(opacity)
              : Colors.transparent,
          child: child,
        ),
      ),
    );
  }

  // ── Glass Card with gradient border ──
  static Widget glassCard({
    required Widget child,
    double borderRadius = 16,
    double blurAmount = blurLight,
    EdgeInsets? padding,
    EdgeInsets? margin,
    double? width,
    double? height,
  }) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: blurAmount,
            sigmaY: blurAmount,
          ),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: AppColors.white.withOpacity(opacityLight),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: AppColors.white.withOpacity(0.1),
                width: 0.5,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.white.withOpacity(0.08),
                  AppColors.white.withOpacity(0.02),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  // ── Glass Button ──
  static Widget glassButton({
    required Widget child,
    required VoidCallback? onPressed,
    double borderRadius = 14,
    Color? glowColor,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            splashColor: (glowColor ?? AppColors.goldWarm).withOpacity(0.15),
            highlightColor: (glowColor ?? AppColors.goldWarm).withOpacity(0.08),
            borderRadius: BorderRadius.circular(borderRadius),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.white.withOpacity(opacityLight),
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(
                  color: AppColors.white.withOpacity(0.1),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (glowColor ?? AppColors.goldWarm).withOpacity(0.08),
                    blurRadius: 20,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  // ── Animated Glass Container ──
  static Widget animatedGlass({
    required Widget child,
    required bool isHovered,
    double scale = 1.0,
    double borderRadius = 16,
  }) {
    return AnimatedContainer(
      duration: durationNormal,
      curve: Curves.easeOutCubic,
      transform: Matrix4.identity()..scale(scale),
      transformAlignment: Alignment.center,
      decoration: BoxDecoration(
        color: isHovered
            ? AppColors.white.withOpacity(opacityMedium)
            : AppColors.white.withOpacity(opacityLight),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: isHovered
              ? AppColors.goldWarm.withOpacity(0.25)
              : AppColors.white.withOpacity(0.08),
          width: isHovered ? 1.0 : 0.5,
        ),
        boxShadow: [
          if (isHovered)
            BoxShadow(
              color: AppColors.goldWarm.withOpacity(0.12),
              blurRadius: 24,
              spreadRadius: -4,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: child,
    );
  }

  // ── Gradient Overlay for images ──
  static LinearGradient imageOverlay({
    Alignment begin = Alignment.topCenter,
    Alignment end = Alignment.bottomCenter,
    List<double>? stops,
  }) {
    return LinearGradient(
      begin: begin,
      end: end,
      stops: stops,
      colors: const [
        Colors.transparent,
        Colors.transparent,
        Color(0xCC000000),
      ],
    );
  }

  // ── Gold Glow ──
  static List<BoxShadow> goldGlow({double blur = 20, double spread = -4}) {
    return [
      BoxShadow(
        color: AppColors.goldWarm.withOpacity(0.15),
        blurRadius: blur,
        spreadRadius: spread,
      ),
    ];
  }

  // ── Subtle inner glow for glass ──
  static List<BoxShadow> innerGlow({double blur = 12}) {
    return [
      BoxShadow(
        color: AppColors.white.withOpacity(0.05),
        blurRadius: blur,
        spreadRadius: -2,
        // inset: true,
      ),
    ];
  }
}
