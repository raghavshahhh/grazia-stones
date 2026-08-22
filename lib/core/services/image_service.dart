import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Image optimization and compression service
class ImageService {
  static ImageService? _instance;
  static ImageService get instance => _instance ??= ImageService._();
  
  ImageService._();

  // Compression quality (0-100)
  static const int defaultQuality = 85;
  static const int thumbnailQuality = 70;
  static const int highQuality = 95;

  // Max dimensions
  static const int maxWidth = 1920;
  static const int maxHeight = 1080;
  static const int thumbnailSize = 400;

  /// Compress image file
  Future<File?> compressImage(
    File file, {
    int quality = defaultQuality,
    int? maxWidth,
    int? maxHeight,
  }) async {
    try {
      debugPrint('🖼️ Compressing image: ${file.path}');
      
      final dir = await getTemporaryDirectory();
      final targetPath = path.join(
        dir.path,
        '${DateTime.now().millisecondsSinceEpoch}_compressed.jpg',
      );

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: quality,
        minWidth: maxWidth ?? ImageService.maxWidth,
        minHeight: maxHeight ?? ImageService.maxHeight,
        format: CompressFormat.jpeg,
      );

      if (result == null) {
        debugPrint('❌ Compression failed');
        return null;
      }

      final originalSize = await file.length();
      final compressedSize = await result.length();
      final reduction = ((originalSize - compressedSize) / originalSize * 100).toStringAsFixed(1);

      debugPrint('✅ Compressed: ${_formatBytes(originalSize)} → ${_formatBytes(compressedSize)} ($reduction% reduction)');

      return File(result.path);
    } catch (e) {
      debugPrint('❌ Compression error: $e');
      return null;
    }
  }

  /// Compress image to Uint8List
  Future<Uint8List?> compressImageToBytes(
    File file, {
    int quality = defaultQuality,
    int? maxWidth,
    int? maxHeight,
  }) async {
    try {
      final result = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        quality: quality,
        minWidth: maxWidth ?? ImageService.maxWidth,
        minHeight: maxHeight ?? ImageService.maxHeight,
        format: CompressFormat.jpeg,
      );

      if (result == null) {
        debugPrint('❌ Compression to bytes failed');
        return null;
      }

      debugPrint('✅ Compressed to bytes: ${_formatBytes(result.length)}');
      return result;
    } catch (e) {
      debugPrint('❌ Compression error: $e');
      return null;
    }
  }

  /// Create thumbnail
  Future<File?> createThumbnail(File file) async {
    return compressImage(
      file,
      quality: thumbnailQuality,
      maxWidth: thumbnailSize,
      maxHeight: thumbnailSize,
    );
  }

  /// Compress from Uint8List
  Future<Uint8List?> compressBytes(
    Uint8List bytes, {
    int quality = defaultQuality,
    int? maxWidth,
    int? maxHeight,
  }) async {
    try {
      final result = await FlutterImageCompress.compressWithList(
        bytes,
        quality: quality,
        minWidth: maxWidth ?? ImageService.maxWidth,
        minHeight: maxHeight ?? ImageService.maxHeight,
        format: CompressFormat.jpeg,
      );

      debugPrint('✅ Compressed bytes: ${_formatBytes(bytes.length)} → ${_formatBytes(result.length)}');
      return result;
    } catch (e) {
      debugPrint('❌ Bytes compression error: $e');
      return null;
    }
  }

  /// Compress multiple images
  Future<List<File>> compressMultiple(
    List<File> files, {
    int quality = defaultQuality,
    Function(int, int)? onProgress,
  }) async {
    final compressed = <File>[];
    
    for (int i = 0; i < files.length; i++) {
      final result = await compressImage(files[i], quality: quality);
      if (result != null) {
        compressed.add(result);
      }
      onProgress?.call(i + 1, files.length);
    }

    return compressed;
  }

  /// Get image size
  Future<int> getImageSize(File file) async {
    return await file.length();
  }

  /// Get image dimensions
  Future<Map<String, int>?> getImageDimensions(File file) async {
    try {
      final _ = await file.readAsBytes();
      // This is a simplified version - use image package for accurate dimensions
      return {'width': 0, 'height': 0};
    } catch (e) {
      debugPrint('❌ Error getting dimensions: $e');
      return null;
    }
  }

  /// Clear cache
  Future<void> clearCache() async {
    try {
      final dir = await getTemporaryDirectory();
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
        await dir.create();
        debugPrint('✅ Image cache cleared');
      }
    } catch (e) {
      debugPrint('❌ Cache clear error: $e');
    }
  }

  /// Get cache size
  Future<int> getCacheSize() async {
    try {
      final dir = await getTemporaryDirectory();
      int totalSize = 0;
      
      if (dir.existsSync()) {
        await for (final entity in dir.list(recursive: true)) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }
      }
      
      return totalSize;
    } catch (e) {
      debugPrint('❌ Error calculating cache size: $e');
      return 0;
    }
  }

  /// Format bytes to human readable
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Optimize image for upload
  Future<File?> optimizeForUpload(File file) async {
    return compressImage(
      file,
      quality: highQuality,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
  }

  /// Optimize multiple images for upload
  Future<List<File>> optimizeMultipleForUpload(
    List<File> files, {
    Function(int, int)? onProgress,
  }) async {
    return compressMultiple(
      files,
      quality: highQuality,
      onProgress: onProgress,
    );
  }
}

/// Image compression presets
enum CompressionPreset {
  thumbnail(quality: 70, maxDimension: 400),
  medium(quality: 85, maxDimension: 1280),
  high(quality: 95, maxDimension: 1920),
  original(quality: 100, maxDimension: 4096);

  final int quality;
  final int maxDimension;

  const CompressionPreset({
    required this.quality,
    required this.maxDimension,
  });
}

/// Image optimization options
class ImageOptimizationOptions {
  final int quality;
  final int? maxWidth;
  final int? maxHeight;
  final CompressFormat format;
  final bool keepExif;

  const ImageOptimizationOptions({
    this.quality = 85,
    this.maxWidth,
    this.maxHeight,
    this.format = CompressFormat.jpeg,
    this.keepExif = false,
  });

  factory ImageOptimizationOptions.thumbnail() {
    return const ImageOptimizationOptions(
      quality: 70,
      maxWidth: 400,
      maxHeight: 400,
    );
  }

  factory ImageOptimizationOptions.preview() {
    return const ImageOptimizationOptions(
      quality: 85,
      maxWidth: 1280,
      maxHeight: 720,
    );
  }

  factory ImageOptimizationOptions.highQuality() {
    return const ImageOptimizationOptions(
      quality: 95,
      maxWidth: 1920,
      maxHeight: 1080,
    );
  }
}
