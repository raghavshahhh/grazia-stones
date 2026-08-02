import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// Shimmer loading skeleton for luxury dark theme.
/// Wraps a child with animated shimmer overlay, or shows a standalone skeleton.
class GLuxuryShimmer extends StatefulWidget {
  final Widget child;
  final bool isLoading;
  final LinearGradient? shimmerGradient;

  const GLuxuryShimmer({
    super.key,
    required this.child,
    this.isLoading = true,
    this.shimmerGradient,
  });

  /// Shimmer box placeholder.
  static Widget box({
    double? width,
    double height = 16,
    double borderRadius = GTokens.radiusSm,
  }) {
    return _ShimmerBox(width: width, height: height, borderRadius: borderRadius);
  }

  /// Shimmer circle placeholder.
  static Widget circle({double size = 48}) {
    return _ShimmerCircle(size: size);
  }

  /// Shimmer text line placeholder.
  static Widget text({double? width, double height = 14}) {
    return _ShimmerBox(width: width, height: height, borderRadius: GTokens.radiusXs);
  }

  @override
  State<GLuxuryShimmer> createState() => _GLuxuryShimmerState();
}

class _GLuxuryShimmerState extends State<GLuxuryShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return ShaderMask(
          shaderCallback: (bounds) {
            final gradient = widget.shimmerGradient ?? LinearGradient(
              colors: [
                const Color(0xFF1A1A1A),
                const Color(0xFF2A2A2A),
                const Color(0xFF1A1A1A),
              ],
              stops: const [0.0, 0.5, 1.0],
              transform: _SlidingGradientTransform(
                slidePercent: _controller.value,
              ),
            );
            return gradient.createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: widget.child,
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;
  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent * 2 - bounds.width, 0, 0);
  }
}

class _ShimmerBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const _ShimmerBox({this.width, required this.height, required this.borderRadius});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

class _ShimmerCircle extends StatelessWidget {
  final double size;
  const _ShimmerCircle({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        shape: BoxShape.circle,
      ),
    );
  }
}
