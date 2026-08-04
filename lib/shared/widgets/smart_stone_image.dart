import 'package:flutter/material.dart';
import 'package:grazia_stones/shared/theme/colors.dart';

/// Renders local asset images or network images seamlessly with an elegant stone texture fallback.
class SmartStoneImage extends StatelessWidget {
  final String? imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final LuxuryPalette? palette;

  const SmartStoneImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final activePalette = palette ?? GLuxuryPalettes.gold;

    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildPlaceholder(activePalette);
    }

    final url = imageUrl!;

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, __, ___) => _buildPlaceholder(activePalette),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildPlaceholder(activePalette);
        },
      );
    }

    // Local asset
    return Image.asset(
      url,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (_, __, ___) => _buildPlaceholder(activePalette),
    );
  }

  Widget _buildPlaceholder(LuxuryPalette palette) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            palette.surfaceLight,
            palette.surfaceDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.texture_rounded,
            size: 40,
            color: palette.primary.withValues(alpha: 0.3),
          ),
          Positioned(
            bottom: 8,
            child: Text(
              'GRAZIA STONES',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
                color: palette.textTertiary.withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
