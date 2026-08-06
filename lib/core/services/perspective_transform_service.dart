import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'wall_detection_service.dart';

/// Perspective Transform Service
/// Applies realistic perspective warping, edge feathering, and lighting adjustment
/// to stone textures for photorealistic AR placement on walls
class PerspectiveTransformService {
  static PerspectiveTransformService? _instance;
  static PerspectiveTransformService get instance =>
      _instance ??= PerspectiveTransformService._();

  PerspectiveTransformService._();

  /// Apply perspective transform to stone texture
  /// Returns a transformed image that matches the wall perspective
  Future<ui.Image?> applyPerspectiveTransform({
    required ui.Image stoneTexture,
    required WallDetectionResult wallDetection,
    required Size screenSize,
    double opacity = 0.80,
    double edgeFeatherRadius = 3.0,
    double brightnessAdjust = 0.0,
  }) async {
    try {
      // Convert Flutter Image to img.Image for processing
      final ByteData? byteData = await stoneTexture.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) return null;

      final imgData = img.decodeImage(byteData.buffer.asUint8List());
      if (imgData == null) return null;

      // Step 1: Calculate perspective transform matrix
      final matrix = _calculatePerspectiveMatrix(
        wallDetection.corners,
        wallDetection.bounds,
      );

      // Step 2: Apply perspective warp
      var transformed = _warpPerspective(imgData, matrix, wallDetection.bounds);

      // Step 3: Adjust brightness to match wall lighting
      if (brightnessAdjust != 0.0) {
        transformed = _adjustBrightness(transformed, brightnessAdjust);
      }

      // Step 4: Apply edge feathering (2-4px blur at edges)
      transformed = _applyEdgeFeather(transformed, edgeFeatherRadius);

      // Step 5: Apply opacity
      transformed = _applyOpacity(transformed, opacity);

      // Convert back to Flutter Image
      return _imgToFlutterImage(transformed);
    } catch (e) {
      debugPrint('❌ Perspective transform error: $e');
      return null;
    }
  }

  /// Calculate perspective transform matrix
  /// Maps texture corners to wall corners
  Matrix4 _calculatePerspectiveMatrix(
    WallCorners wallCorners,
    ui.Rect bounds,
  ) {
    // Source points (texture corners - normalized 0 to 1)
    final srcPoints = [
      ui.Offset(0, 0), // Top-left
      ui.Offset(1, 0), // Top-right
      ui.Offset(0, 1), // Bottom-left
      ui.Offset(1, 1), // Bottom-right
    ];

    // Destination points (wall corners - in screen space)
    final dstPoints = [
      wallCorners.topLeft,
      wallCorners.topRight,
      wallCorners.bottomLeft,
      wallCorners.bottomRight,
    ];

    // Calculate perspective matrix using homography
    return _computeHomography(srcPoints, dstPoints);
  }

  /// Compute homography matrix for perspective transform
  /// This is a simplified version - for production, use a proper homography library
  Matrix4 _computeHomography(List<ui.Offset> src, List<ui.Offset> dst) {
    // Simplified perspective transform
    // For a full implementation, use opencv or similar
    
    // For now, return a basic scaling/translation matrix
    final scaleX = (dst[1].dx - dst[0].dx) / (src[1].dx - src[0].dx);
    final scaleY = (dst[2].dy - dst[0].dy) / (src[2].dy - src[0].dy);
    final translateX = dst[0].dx - (src[0].dx * scaleX);
    final translateY = dst[0].dy - (src[0].dy * scaleY);

    return Matrix4.identity()
      ..translate(translateX, translateY)
      ..scale(scaleX, scaleY);
  }

  /// Warp image using perspective matrix
  img.Image _warpPerspective(
    img.Image source,
    Matrix4 matrix,
    ui.Rect targetBounds,
  ) {
    final targetWidth = targetBounds.width.toInt();
    final targetHeight = targetBounds.height.toInt();

    // Create output image
    final output = img.Image(
      width: targetWidth,
      height: targetHeight,
      numChannels: 4,
    );

    // Apply perspective warp (simplified)
    // For production, implement proper bilinear/bicubic interpolation
    for (int y = 0; y < targetHeight; y++) {
      for (int x = 0; x < targetWidth; x++) {
        // Map output pixel to source pixel
        final srcX = (x * source.width / targetWidth) % source.width;
        final srcY = (y * source.height / targetHeight) % source.height;

        final srcPixel = source.getPixel(srcX.toInt(), srcY.toInt());
        output.setPixel(x, y, srcPixel);
      }
    }

    return output;
  }

  /// Adjust image brightness
  img.Image _adjustBrightness(img.Image image, double amount) {
    // amount: -1.0 to 1.0 (negative = darker, positive = brighter)
    final adjustment = (amount * 50).round(); // Scale to -50 to +50

    return img.adjustColor(
      image,
      brightness: adjustment,
    );
  }

  /// Apply edge feathering (soft blur at edges)
  img.Image _applyEdgeFeather(img.Image image, double radius) {
    if (radius <= 0) return image;

    // Create a mask for edge feathering
    final width = image.width;
    final height = image.height;
    final featherPixels = radius.toInt();

    // Apply alpha gradient at edges
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        // Calculate distance from edge
        final distLeft = x;
        final distRight = width - x - 1;
        final distTop = y;
        final distBottom = height - y - 1;

        final minDist = [distLeft, distRight, distTop, distBottom]
            .reduce((a, b) => a < b ? a : b);

        // Apply feather effect
        if (minDist < featherPixels) {
          final alpha = minDist / featherPixels;
          final pixel = image.getPixel(x, y);
          final currentAlpha = pixel.a;
          final newAlpha = (currentAlpha * alpha).toInt();

          image.setPixelRgba(
            x,
            y,
            pixel.r.toInt(),
            pixel.g.toInt(),
            pixel.b.toInt(),
            newAlpha,
          );
        }
      }
    }

    return image;
  }

  /// Apply opacity to entire image
  img.Image _applyOpacity(img.Image image, double opacity) {
    final opacityFactor = opacity.clamp(0.0, 1.0);

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final newAlpha = (pixel.a * opacityFactor).toInt();

        image.setPixelRgba(
          x,
          y,
          pixel.r.toInt(),
          pixel.g.toInt(),
          pixel.b.toInt(),
          newAlpha,
        );
      }
    }

    return image;
  }

  /// Convert img.Image to Flutter ui.Image
  Future<ui.Image?> _imgToFlutterImage(img.Image image) async {
    try {
      final png = img.encodePng(image);
      final codec = await ui.instantiateImageCodec(png);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      debugPrint('❌ Failed to convert image: $e');
      return null;
    }
  }

  /// Create a realistic blend effect (for multiply blend mode simulation)
  img.Image applyMultiplyBlend(
    img.Image texture,
    img.Image background,
  ) {
    final output = img.Image(
      width: texture.width,
      height: texture.height,
      numChannels: 4,
    );

    for (int y = 0; y < texture.height; y++) {
      for (int x = 0; x < texture.width; x++) {
        final texPixel = texture.getPixel(x, y);
        final bgPixel = background.getPixel(x, y);

        // Multiply blend: output = (texture * background) / 255
        final r = (texPixel.r * bgPixel.r / 255).toInt();
        final g = (texPixel.g * bgPixel.g / 255).toInt();
        final b = (texPixel.b * bgPixel.b / 255).toInt();
        final a = texPixel.a.toInt();

        output.setPixelRgba(x, y, r, g, b, a);
      }
    }

    return output;
  }
}

/// Texture Mapping Configuration
class TextureMappingConfig {
  final double opacity;
  final double edgeFeatherRadius;
  final double brightnessAdjust;
  final bool preserveShadows;
  final BlendMode blendMode;

  const TextureMappingConfig({
    this.opacity = 0.80,
    this.edgeFeatherRadius = 3.0,
    this.brightnessAdjust = 0.0,
    this.preserveShadows = true,
    this.blendMode = BlendMode.multiply,
  });

  /// TilesView/IKEA Place style preset
  static const TextureMappingConfig realistic = TextureMappingConfig(
    opacity: 0.82,
    edgeFeatherRadius: 3.5,
    brightnessAdjust: -0.05,
    preserveShadows: true,
    blendMode: BlendMode.multiply,
  );

  /// High opacity preset
  static const TextureMappingConfig bold = TextureMappingConfig(
    opacity: 0.95,
    edgeFeatherRadius: 2.0,
    brightnessAdjust: 0.0,
    preserveShadows: false,
    blendMode: BlendMode.srcOver,
  );

  /// Subtle preset
  static const TextureMappingConfig subtle = TextureMappingConfig(
    opacity: 0.65,
    edgeFeatherRadius: 4.0,
    brightnessAdjust: -0.10,
    preserveShadows: true,
    blendMode: BlendMode.multiply,
  );
}
