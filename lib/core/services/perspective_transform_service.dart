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

      // Step 1: Calculate perspective transform matrix (homography)
      final matrix = _calculatePerspectiveMatrix(
        wallDetection.corners,
        wallDetection.bounds,
      );

      // Step 2: Apply perspective warp using homography
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

  /// Calculate perspective transform matrix (homography)
  /// Maps texture corners (0,0)-(1,1) to wall corners in screen space
  Matrix4 _calculatePerspectiveMatrix(
    WallCorners wallCorners,
    ui.Rect bounds,
  ) {
    // Source points: texture corners in normalized coordinates
    final srcPoints = [
      ui.Offset(0.0, 0.0), // Top-left
      ui.Offset(1.0, 0.0), // Top-right
      ui.Offset(1.0, 1.0), // Bottom-right
      ui.Offset(0.0, 1.0), // Bottom-left
    ];

    // Destination points: wall corners in screen space
    final dstPoints = [
      wallCorners.topLeft,
      wallCorners.topRight,
      wallCorners.bottomRight,
      wallCorners.bottomLeft,
    ];

    // Calculate homography matrix
    return _computeHomography(srcPoints, dstPoints);
  }

  /// Compute homography matrix for perspective transform using DLT (Direct Linear Transform)
  /// Maps 4 source points to 4 destination points
  Matrix4 _computeHomography(List<ui.Offset> src, List<ui.Offset> dst) {
    // DLT algorithm for homography estimation
    // We need to solve Ah = 0 for the 8 DOF homography matrix
    // h = [h11, h12, h13, h21, h22, h23, h31, h32, h33]^T with h33 = 1
    
    final List<List<double>> A = [];
    final List<double> b = [];

    for (int i = 0; i < 4; i++) {
      final x = src[i].dx;
      final y = src[i].dy;
      final xp = dst[i].dx;
      final yp = dst[i].dy;

      // Two equations per point
      A.add([x, y, 1, 0, 0, 0, -xp * x, -xp * y]);
      b.add(xp);
      
      A.add([0, 0, 0, x, y, 1, -yp * x, -yp * y]);
      b.add(yp);
    }

    // Solve using least squares: h = (A^T A)^-1 A^T b
    final h = _solveLeastSquares(A, b);
    
    // Build 3x3 homography matrix
    final h11 = h[0], h12 = h[1], h13 = h[2];
    final h21 = h[3], h22 = h[4], h23 = h[5];
    final h31 = h[6], h32 = h[7], h33 = 1.0;

    return Matrix4(
      h11, h12, 0, h13,
      h21, h22, 0, h23,
      0,   0,   1, 0,
      h31, h32, 0, h33,
    );
  }

  /// Solve least squares problem using normal equations
  List<double> _solveLeastSquares(List<List<double>> A, List<double> b) {
    final m = A.length; // 8
    final n = A[0].length; // 8

    // Compute A^T A
    final List<List<double>> ATA = List.generate(n, (_) => List.filled(n, 0.0));
    for (int i = 0; i < n; i++) {
      for (int j = 0; j < n; j++) {
        double sum = 0.0;
        for (int k = 0; k < m; k++) {
          sum += A[k][i] * A[k][j];
        }
        ATA[i][j] = sum;
      }
    }

    // Compute A^T b
    final List<double> ATb = List.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      double sum = 0.0;
      for (int k = 0; k < m; k++) {
        sum += A[k][i] * b[k];
      }
      ATb[i] = sum;
    }

    // Solve ATA * h = ATb using Gaussian elimination
    return _gaussianElimination(ATA, ATb);
  }

  /// Gaussian elimination for solving linear system
  List<double> _gaussianElimination(List<List<double>> A, List<double> b) {
    final n = A.length;
    
    // Augmented matrix
    final List<List<double>> aug = List.generate(n, (i) => List.from(A[i])..add(b[i]));

    // Forward elimination
    for (int i = 0; i < n; i++) {
      // Find pivot
      int maxRow = i;
      for (int k = i + 1; k < n; k++) {
        if (aug[k][i].abs() > aug[maxRow][i].abs()) {
          maxRow = k;
        }
      }
      
      // Swap rows
      if (maxRow != i) {
        final temp = aug[i];
        aug[i] = aug[maxRow];
        aug[maxRow] = temp;
      }

      // Check for singular matrix
      if (aug[i][i].abs() < 1e-10) {
        // Fallback: return identity-like solution
        return List.generate(n, (i) => i < n - 1 ? 0.0 : 1.0);
      }

      // Eliminate below
      for (int k = i + 1; k < n; k++) {
        final factor = aug[k][i] / aug[i][i];
        for (int j = i; j <= n; j++) {
          aug[k][j] -= factor * aug[i][j];
        }
      }
    }

    // Back substitution
    final x = List.filled(n, 0.0);
    for (int i = n - 1; i >= 0; i--) {
      double sum = aug[i][n];
      for (int j = i + 1; j < n; j++) {
        sum -= aug[i][j] * x[j];
      }
      x[i] = sum / aug[i][i];
    }

    return x;
  }

  /// Warp image using perspective homography matrix
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

    // Extract matrix elements (3x3 homography embedded in 4x4)
    final m = matrix.storage;
    // [h11, h12, 0, h13]
    // [h21, h22, 0, h23]
    // [0,   0,   1, 0]
    // [h31, h32, 0, h33]
    final h11 = m[0], h12 = m[4], h13 = m[12];
    final h21 = m[1], h22 = m[5], h23 = m[13];
    final h31 = m[3], h32 = m[7], h33 = m[15];

    // Inverse mapping: for each output pixel, find source pixel
    for (int y = 0; y < targetHeight; y++) {
      for (int x = 0; x < targetWidth; x++) {
        // Homogeneous coordinates
        final w = h31 * x + h32 * y + h33;
        if (w.abs() < 1e-6) continue;
        
        final srcX = (h11 * x + h12 * y + h13) / w;
        final srcY = (h21 * x + h22 * y + h23) / w;

        // Check bounds
        if (srcX >= 0 && srcX < source.width - 1 && srcY >= 0 && srcY < source.height - 1) {
          // Bilinear interpolation
          final x0 = srcX.floor();
          final y0 = srcY.floor();
          final x1 = x0 + 1;
          final y1 = y0 + 1;
          final dx = srcX - x0;
          final dy = srcY - y0;

          if (x1 < source.width && y1 < source.height) {
            final p00 = source.getPixel(x0, y0);
            final p10 = source.getPixel(x1, y0);
            final p01 = source.getPixel(x0, y1);
            final p11 = source.getPixel(x1, y1);

            final r = _lerp(_lerp(p00.r.toDouble(), p10.r.toDouble(), dx),
                           _lerp(p01.r.toDouble(), p11.r.toDouble(), dx), dy).round();
            final g = _lerp(_lerp(p00.g.toDouble(), p10.g.toDouble(), dx),
                           _lerp(p01.g.toDouble(), p11.g.toDouble(), dx), dy).round();
            final b = _lerp(_lerp(p00.b.toDouble(), p10.b.toDouble(), dx),
                           _lerp(p01.b.toDouble(), p11.b.toDouble(), dx), dy).round();
            final a = _lerp(_lerp(p00.a.toDouble(), p10.a.toDouble(), dx),
                           _lerp(p01.a.toDouble(), p11.a.toDouble(), dx), dy).round();

            output.setPixelRgba(x, y, r.clamp(0, 255), g.clamp(0, 255), b.clamp(0, 255), a.clamp(0, 255));
          }
        }
      }
    }

    return output;
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  /// Adjust image brightness
  img.Image _adjustBrightness(img.Image image, double amount) {
    final adjustment = (amount * 50).round();
    return img.adjustColor(image, brightness: adjustment);
  }

  /// Apply edge feathering (soft alpha gradient at edges)
  img.Image _applyEdgeFeather(img.Image image, double radius) {
    if (radius <= 0) return image;

    final width = image.width;
    final height = image.height;
    final featherPixels = radius.toInt();

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final distLeft = x;
        final distRight = width - x - 1;
        final distTop = y;
        final distBottom = height - y - 1;

        final minDist = [distLeft, distRight, distTop, distBottom]
            .reduce((a, b) => a < b ? a : b);

        if (minDist < featherPixels) {
          final alpha = minDist / featherPixels;
          final pixel = image.getPixel(x, y);
          final currentAlpha = pixel.a;
          final newAlpha = (currentAlpha * alpha).toInt();

          image.setPixelRgba(
            x, y,
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
          x, y,
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