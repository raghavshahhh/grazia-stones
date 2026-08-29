import 'package:flutter/material.dart';
import 'package:grazia_stones/shared/theme/colors.dart';

/// Renders local asset images or network images seamlessly with an Apple-grade crossfade & luxury stone texture placeholder.
class SmartStoneImage extends StatelessWidget {
  final String? imageUrl;
  final String? localAsset;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Alignment alignment;
  final LuxuryPalette? palette;
  final Color? fallbackColor;

  const SmartStoneImage({
    super.key,
    this.imageUrl,
    this.localAsset,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.width,
    this.height,
    this.palette,
    this.fallbackColor,
  });

  @override
  Widget build(BuildContext context) {
    final activePalette = palette ?? GLuxuryPalettes.gold;

    // Prefer localAsset if provided
    final effectiveAsset = localAsset ?? imageUrl;

    if (effectiveAsset == null || effectiveAsset.isEmpty) {
      return _buildPlaceholder(activePalette);
    }

    if (effectiveAsset.startsWith('http://') || effectiveAsset.startsWith('https://')) {
      return Image.network(
        effectiveAsset,
        fit: fit,
        alignment: alignment,
        width: width,
        height: height,
        cacheWidth: width != null && width! > 0 ? (width! * 2).toInt() : null,
        cacheHeight: height != null && height! > 0 ? (height! * 2).toInt() : null,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) {
            return AnimatedOpacity(
              opacity: frame != null ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              child: child,
            );
          }
          return _buildPlaceholder(activePalette);
        },
        errorBuilder: (_, _, _) => _buildPlaceholder(activePalette),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildPlaceholder(activePalette);
        },
      );
    }

    // Local asset
    return Image.asset(
      effectiveAsset,
      fit: fit,
      alignment: alignment,
      width: width,
      height: height,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }
        return _buildPlaceholder(activePalette);
      },
      errorBuilder: (_, _, _) => _buildPlaceholder(activePalette),
    );
  }

  Widget _buildPlaceholder(LuxuryPalette palette) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: fallbackColor ?? palette.surface,
        gradient: fallbackColor == null
            ? LinearGradient(
                colors: [
                  palette.surfaceLight.withValues(alpha: 0.8),
                  palette.surfaceDark.withValues(alpha: 0.95),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.texture_rounded,
            size: 32,
            color: palette.primary.withValues(alpha: 0.25),
          ),
          Positioned(
            bottom: 6,
            child: Text(
              'GRAZIA',
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.5,
                color: palette.primary.withValues(alpha: 0.35),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
