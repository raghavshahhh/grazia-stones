import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/tokens.dart';
import '../theme/colors.dart';
import '../theme/shadows.dart';
import '../theme/borders.dart';

/// Premium button with gold gradient, shimmer, haptic feedback.
/// Variants: filled (gold gradient), outlined (glass border), ghost (text only).
enum GLuxuryButtonStyle { filled, outlined, ghost }

class GLuxuryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final GLuxuryButtonStyle style;
  final IconData? icon;
  final bool isLoading;
  final bool isExpanded;
  final double? height;

  const GLuxuryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.style = GLuxuryButtonStyle.filled,
    this.icon,
    this.isLoading = false,
    this.isExpanded = true,
    this.height = 56,
  });

  @override
  State<GLuxuryButton> createState() => _GLuxuryButtonState();
}

class _GLuxuryButtonState extends State<GLuxuryButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => setState(() => _isPressed = true);
  void _onTapUp(TapUpDetails _) => setState(() => _isPressed = false);
  void _onTapCancel() => setState(() => _isPressed = false);

  @override
  Widget build(BuildContext context) {
    final palette = GLuxuryPalettes.gold;
    final enabled = widget.onPressed != null && !widget.isLoading;

    Widget child = AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, _) {
        return CustomPaint(
          painter: _isPressed ? null : _ShimmerPainter(
            animation: _shimmerController.value,
            color: palette.primary,
          ),
          child: _buildContent(palette, enabled),
        );
      },
    );

    if (widget.style == GLuxuryButtonStyle.filled) {
      child = Container(
        height: widget.height,
        decoration: BoxDecoration(
          gradient: enabled
              ? (_isPressed ? palette.shimmerGradient : palette.primaryGradient)
              : LinearGradient(colors: [
                  palette.border.withValues(alpha: 0.5),
                  palette.border.withValues(alpha: 0.3),
                ]),
          borderRadius: GLuxuryBorders.buttonRadius,
          boxShadow: enabled ? GLuxuryShadows.goldGlowSubtle : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? widget.onPressed : null,
            onTapDown: enabled ? _onTapDown : null,
            onTapUp: enabled ? _onTapUp : null,
            onTapCancel: enabled ? _onTapCancel : null,
            borderRadius: GLuxuryBorders.buttonRadius,
            splashColor: palette.primary.withValues(alpha: 0.15),
            highlightColor: palette.primary.withValues(alpha: 0.08),
            child: Center(child: child),
          ),
        ),
      );
    }

    if (widget.style == GLuxuryButtonStyle.outlined) {
      child = Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: _isPressed
              ? palette.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: GLuxuryBorders.buttonRadius,
          border: Border.all(
            color: enabled
                ? palette.primary.withValues(alpha: _isPressed ? 0.6 : 0.3)
                : palette.border,
            width: 1.5,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? widget.onPressed : null,
            onTapDown: enabled ? _onTapDown : null,
            onTapUp: enabled ? _onTapUp : null,
            onTapCancel: enabled ? _onTapCancel : null,
            borderRadius: GLuxuryBorders.buttonRadius,
            child: Center(child: child),
          ),
        ),
      );
    }

    // ghost
    child = GestureDetector(
      onTapDown: enabled ? _onTapDown : null,
      onTapUp: enabled ? _onTapUp : null,
      onTapCancel: enabled ? _onTapCancel : null,
      child: AnimatedContainer(
        duration: GTokens.durationInstant,
        height: widget.height,
        decoration: BoxDecoration(
          color: _isPressed
              ? palette.primary.withValues(alpha: 0.06)
              : Colors.transparent,
          borderRadius: GLuxuryBorders.buttonRadius,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? widget.onPressed : null,
            borderRadius: GLuxuryBorders.buttonRadius,
            child: Center(child: child),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: GTokens.space4),
      child: child,
    );
  }

  Widget _buildContent(LuxuryPalette palette, bool enabled) {
    final color = enabled
        ? (widget.style == GLuxuryButtonStyle.filled ? Colors.white : palette.textPrimary)
        : palette.textTertiary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: GTokens.space5),
      child: Row(
        mainAxisSize: widget.isExpanded ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.isLoading) ...[
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(color.withValues(alpha: 0.6)),
              ),
            ),
            const SizedBox(width: GTokens.space3),
          ] else if (widget.icon != null) ...[
            Icon(widget.icon, size: 20, color: color),
            const SizedBox(width: GTokens.space2),
          ],
          Text(
            widget.label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  final double animation;
  final Color color;

  _ShimmerPainter({required this.animation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0),
          color.withValues(alpha: 0.06),
          color.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(
        (animation * size.width * 1.5) - size.width * 0.5,
        0,
        size.width * 0.5,
        size.height,
      ));

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), Radius.circular(size.height / 2)),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ShimmerPainter old) => old.animation != animation;
}
