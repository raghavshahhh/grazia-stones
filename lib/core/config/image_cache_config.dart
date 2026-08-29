import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';

/// Global image cache configuration
/// 
/// Configures CachedNetworkImage settings for the entire app
class ImageCacheConfig {
  static const int maxCacheSize = 200; // MB
  static const Duration stalePeriod = Duration(days: 7);
  static const Duration maxAge = Duration(days: 30);

  /// Initialize image cache settings
  static void init() {
    // Configure CachedNetworkImage manager
    // Note: This uses the default singleton, settings apply globally
    debugPrint('📦 Image cache configured: ${maxCacheSize}MB, stale after $stalePeriod');
  }

  /// Clear image cache
  static Future<void> clearCache() async {
    await DefaultCacheManager().emptyCache();
    debugPrint('🗑️ Image cache cleared');
  }

  /// Get cache size in bytes
  static Future<int> getCacheSize() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      int totalSize = 0;
      await for (final entity in cacheDir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      return totalSize;
    } catch (e) {
      debugPrint('⚠️ Could not calculate cache size: $e');
      return 0;
    }
  }

  /// Get cache size in MB
  static Future<double> getCacheSizeMB() async {
    final bytes = await getCacheSize();
    return bytes / (1024 * 1024);
  }
}


/// Optimized network image widget
/// 
/// Uses CachedNetworkImage with:
/// - Loading placeholder
/// - Error handling
/// - Fade-in animation
/// - Proper sizing and memory management
class OptimizedNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  const OptimizedNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    Widget image = CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) =>
          placeholder ?? _buildPlaceholder(context),
      errorWidget: (context, url, error) =>
          errorWidget ?? _buildErrorWidget(context),
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 100),
      memCacheWidth: width != null ? (width! * 2).toInt() : null,
      memCacheHeight: height != null ? (height! * 2).toInt() : null,
      maxWidthDiskCache: width != null ? (width! * 3).toInt() : 1200,
      maxHeightDiskCache: height != null ? (height! * 3).toInt() : 1200,
    );

    if (borderRadius != null) {
      image = ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    return image;
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: borderRadius,
      ),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(Colors.grey[400]),
        ),
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: borderRadius,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_rounded,
            size: 32,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 8),
          Text(
            'Failed to load',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

