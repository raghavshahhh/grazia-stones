import 'package:cached_network_image/cached_network_image.dart';
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

    final hasNetworkUrl = imageUrl != null &&
        (imageUrl!.startsWith('http://') || imageUrl!.startsWith('https://'));
    final hasLocalAsset = localAsset != null && localAsset!.isNotEmpty;

    if (hasNetworkUrl) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        fit: fit,
        alignment: alignment,
        width: width,
        height: height,
        memCacheWidth: width != null && width!.isFinite && width! > 0 ? (width! * 2).toInt() : null,
        memCacheHeight: height != null && height!.isFinite && height! > 0 ? (height! * 2).toInt() : null,
        fadeInDuration: const Duration(milliseconds: 280),
        fadeInCurve: Curves.easeOutCubic,
        placeholder: (context, url) => hasLocalAsset
            ? Image.asset(
                localAsset!,
                fit: fit,
                alignment: alignment,
                width: width,
                height: height,
              )
            : _buildPlaceholder(activePalette),
        errorWidget: (context, url, error) => hasLocalAsset
            ? Image.asset(
                localAsset!,
                fit: fit,
                alignment: alignment,
                width: width,
                height: height,
                errorBuilder: (_, _, _) => _buildPlaceholder(activePalette),
              )
            : _buildPlaceholder(activePalette),
      );
    }

    final effectiveLocal = (imageUrl != null && imageUrl!.isNotEmpty && !imageUrl!.startsWith('http'))
        ? imageUrl!
        : (hasLocalAsset ? localAsset! : null);

    if (effectiveLocal == null || effectiveLocal.isEmpty) {
      return _buildPlaceholder(activePalette);
    }

    // Local asset
    return Image.asset(
      effectiveLocal,
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
