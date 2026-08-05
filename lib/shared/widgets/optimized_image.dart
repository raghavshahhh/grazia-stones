import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:grazia_stones/shared/theme/colors.dart';

/// Optimized image widget with caching and loading states
class OptimizedImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;

  const OptimizedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildErrorWidget();
    }

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) => _buildErrorWidget(),
        fadeInDuration: const Duration(milliseconds: 300),
        fadeOutDuration: const Duration(milliseconds: 100),
        memCacheWidth: width != null ? (width! * 2).toInt() : null,
        memCacheHeight: height != null ? (height! * 2).toInt() : null,
        maxWidthDiskCache: 1920,
        maxHeightDiskCache: 1080,
      ),
    );
  }

  Widget _buildPlaceholder() {
    if (placeholder != null) return placeholder!;

    return Container(
      width: width,
      height: height,
      color: backgroundColor ?? GLuxuryPalettes.gold.surfaceDark,
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(
              GLuxuryPalettes.gold.primary.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    if (errorWidget != null) return errorWidget!;

    return Container(
      width: width,
      height: height,
      color: backgroundColor ?? GLuxuryPalettes.gold.surfaceDark,
      child: Icon(
        Icons.broken_image_outlined,
        color: GLuxuryPalettes.gold.textTertiary,
        size: 32,
      ),
    );
  }
}

/// Optimized thumbnail image widget
class OptimizedThumbnail extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const OptimizedThumbnail({
    super.key,
    required this.imageUrl,
    this.size = 100,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return OptimizedImage(
      imageUrl: imageUrl,
      width: size,
      height: size,
      fit: fit,
      borderRadius: borderRadius ?? BorderRadius.circular(8),
    );
  }
}

/// Optimized hero image widget
class OptimizedHeroImage extends StatelessWidget {
  final String? imageUrl;
  final String heroTag;
  final double? width;
  final double? height;
  final BoxFit fit;

  const OptimizedHeroImage({
    super.key,
    required this.imageUrl,
    required this.heroTag,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: heroTag,
      child: OptimizedImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
      ),
    );
  }
}

/// Optimized circular avatar
class OptimizedAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final Color? backgroundColor;
  final Widget? placeholder;

  const OptimizedAvatar({
    super.key,
    required this.imageUrl,
    this.radius = 40,
    this.backgroundColor,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? GLuxuryPalettes.gold.surfaceDark,
      child: ClipOval(
        child: imageUrl != null && imageUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: imageUrl!,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                placeholder: (context, url) => _buildPlaceholder(),
                errorWidget: (context, url, error) => _buildError(),
              )
            : _buildPlaceholder(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    if (placeholder != null) return placeholder!;
    
    return Icon(
      Icons.person_outline,
      size: radius,
      color: GLuxuryPalettes.gold.textTertiary,
    );
  }

  Widget _buildError() {
    return Icon(
      Icons.person_off_outlined,
      size: radius,
      color: GLuxuryPalettes.gold.textTertiary,
    );
  }
}

/// Image gallery widget with caching
class OptimizedImageGallery extends StatelessWidget {
  final List<String> imageUrls;
  final double height;
  final Function(int)? onImageTap;

  const OptimizedImageGallery({
    super.key,
    required this.imageUrls,
    this.height = 300,
    this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text('No images available'),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: PageView.builder(
        itemCount: imageUrls.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => onImageTap?.call(index),
            child: OptimizedImage(
              imageUrl: imageUrls[index],
              height: height,
              fit: BoxFit.cover,
            ),
          );
        },
      ),
    );
  }
}
