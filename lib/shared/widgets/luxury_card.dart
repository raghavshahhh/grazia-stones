import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../theme/colors.dart';
import '../theme/shadows.dart';
import '../theme/borders.dart';
import '../theme/gradients.dart';

/// Glass-morphism card with blur backdrop, gold border, and shadow.
/// Supports light/dark glass, optional gold accent border, and tap interaction.
class GLuxuryCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool isGlass;
  final bool showGoldBorder;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;

  const GLuxuryCard({
    super.key,
    required this.child,
    this.onTap,
    this.isGlass = true,
    this.showGoldBorder = false,
    this.padding,
    this.margin,
    this.width,
    this.height,
  });

  @override
  State<GLuxuryCard> createState() => _GLuxuryCardState();
}

class _GLuxuryCardState extends State<GLuxuryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: GTokens.durationFast,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: GTokens.curveEaseOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = GLuxuryPalettes.gold;

    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        );
      },
      child: GestureDetector(
        onTapDown: widget.onTap != null ? (_) {
          _controller.forward();
          setState(() => _isPressed = true);
        } : null,
        onTapUp: widget.onTap != null ? (_) {
          _controller.reverse();
          setState(() => _isPressed = false);
          widget.onTap?.call();
        } : null,
        onTapCancel: widget.onTap != null ? () {
          _controller.reverse();
          setState(() => _isPressed = false);
        } : null,
        child: AnimatedContainer(
          duration: GTokens.durationFast,
          width: widget.width,
          height: widget.height,
          margin: widget.margin,
          decoration: BoxDecoration(
            color: widget.isGlass
                ? palette.surface.withValues(alpha: _isPressed ? 0.95 : 0.9)
                : palette.surface,
            borderRadius: GLuxuryBorders.cardRadius,
            border: Border.all(
              color: widget.showGoldBorder
                  ? palette.primary.withValues(alpha: _isPressed ? 0.8 : 0.4)
                  : palette.border,
              width: widget.showGoldBorder ? 1.5 : 1.0,
            ),
            boxShadow: _isPressed ? null : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: GLuxuryBorders.cardRadius,
            child: BackdropFilter(
              filter: widget.isGlass
                  ? ImageFilter.blur(sigmaX: GTokens.blurMd, sigmaY: GTokens.blurMd)
                  : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
              child: Container(
                padding: widget.padding ?? const EdgeInsets.all(GTokens.space4),
                decoration: BoxDecoration(
                  gradient: GLuxuryGradients.glassHighlight,
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Static version of LuxuryCard for non-interactive use (lists, displays).
class GLuxuryCardStatic extends StatelessWidget {
  final Widget child;
  final bool isGlass;
  final bool showGoldBorder;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;

  const GLuxuryCardStatic({
    super.key,
    required this.child,
    this.isGlass = true,
    this.showGoldBorder = false,
    this.padding,
    this.margin,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final palette = GLuxuryPalettes.gold;

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: isGlass
            ? palette.surface.withValues(alpha: 0.5)
            : palette.surface,
        borderRadius: GLuxuryBorders.cardRadius,
        border: Border.all(
          color: showGoldBorder
              ? palette.primary.withValues(alpha: 0.3)
              : palette.border,
          width: showGoldBorder ? 1.5 : 0.5,
        ),
        boxShadow: GLuxuryShadows.level2,
      ),
      child: ClipRRect(
        borderRadius: GLuxuryBorders.cardRadius,
        child: BackdropFilter(
          filter: isGlass
              ? ImageFilter.blur(sigmaX: GTokens.blurMd, sigmaY: GTokens.blurMd)
              : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
          child: Container(
            padding: padding ?? const EdgeInsets.all(GTokens.space4),
            decoration: BoxDecoration(
              gradient: GLuxuryGradients.glassHighlight,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
