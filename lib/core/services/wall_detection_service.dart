import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

/// Wall Detection Service
/// Uses Google ML Kit to detect flat surfaces and calculate perspective bounds
/// Provides wall edges, corners, and confidence score for realistic AR placement
class WallDetectionService {
  static WallDetectionService? _instance;
  static WallDetectionService get instance =>
      _instance ??= WallDetectionService._();

  WallDetectionService._();

  ObjectDetector? _objectDetector;
  bool _initialized = false;

  /// Initialize ML Kit Object Detector
  Future<void> init() async {
    if (_initialized) return;

    try {
      final options = ObjectDetectorOptions(
        mode: DetectionMode.stream,
        classifyObjects: false,
        multipleObjects: true,
      );

      _objectDetector = ObjectDetector(options: options);
      _initialized = true;
      debugPrint('✅ Wall Detection Service initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize Wall Detection: $e');
    }
  }

  /// Detect wall in camera frame
  /// Returns WallDetectionResult with bounds, corners, and confidence
  Future<WallDetectionResult?> detectWall(CameraImage image) async {
    if (!_initialized || _objectDetector == null) {
      await init();
    }

    try {
      // Convert CameraImage to InputImage for ML Kit
      final inputImage = _convertCameraImage(image);
      if (inputImage == null) return null;

      // Detect objects (we'll filter for flat surfaces)
      final objects = await _objectDetector!.processImage(inputImage);

      // Find the largest rectangular object (likely a wall)
      final wallCandidate = _findWallCandidate(objects, image.width, image.height);

      return wallCandidate;
    } catch (e) {
      debugPrint('❌ Wall detection error: $e');
      return null;
    }
  }

  /// Convert CameraImage to ML Kit InputImage
  InputImage? _convertCameraImage(CameraImage image) {
    try {
      // Get image format
      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null) return null;

      // Get plane data
      final plane = image.planes.first;

      // Create InputImage
      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: ui.Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotation.rotation0deg,
          format: format,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    } catch (e) {
      debugPrint('❌ Failed to convert camera image: $e');
      return null;
    }
  }

  /// Find the best wall candidate from detected objects
  WallDetectionResult? _findWallCandidate(
    List<DetectedObject> objects,
    int imageWidth,
    int imageHeight,
  ) {
    if (objects.isEmpty) {
      // No objects detected - return a default centered wall area
      return _createDefaultWall(imageWidth, imageHeight);
    }

    // Find the largest object (most likely the wall)
    DetectedObject? largestObject;
    double maxArea = 0.0;

    for (final obj in objects) {
      final rect = obj.boundingBox;
      final area = rect.width * rect.height;
      if (area > maxArea) {
        maxArea = area;
        largestObject = obj;
      }
    }

    if (largestObject == null) {
      return _createDefaultWall(imageWidth, imageHeight);
    }

    final bounds = largestObject.boundingBox;

    // Calculate wall corners (for perspective transform)
    final corners = WallCorners(
      topLeft: ui.Offset(bounds.left, bounds.top),
      topRight: ui.Offset(bounds.right, bounds.top),
      bottomLeft: ui.Offset(bounds.left, bounds.bottom),
      bottomRight: ui.Offset(bounds.right, bounds.bottom),
    );

    // Calculate confidence based on size and position
    final confidence = _calculateConfidence(bounds, imageWidth, imageHeight);

    return WallDetectionResult(
      bounds: bounds,
      corners: corners,
      confidence: confidence,
      centerPoint: ui.Offset(bounds.center.dx, bounds.center.dy),
    );
  }

  /// Create default wall area when no detection available
  WallDetectionResult _createDefaultWall(int width, int height) {
    // Default wall: center 60% of screen, excluding top and bottom bars
    final wallWidth = width * 0.7;
    final wallHeight = height * 0.55;
    final left = (width - wallWidth) / 2;
    final top = height * 0.12; // Below top bar

    final rect = ui.Rect.fromLTWH(left, top, wallWidth, wallHeight);

    final corners = WallCorners(
      topLeft: ui.Offset(rect.left, rect.top),
      topRight: ui.Offset(rect.right, rect.top),
      bottomLeft: ui.Offset(rect.left, rect.bottom),
      bottomRight: ui.Offset(rect.right, rect.bottom),
    );

    return WallDetectionResult(
      bounds: rect,
      corners: corners,
      confidence: 0.6, // Medium confidence for default
      centerPoint: ui.Offset(rect.center.dx, rect.center.dy),
    );
  }

  /// Calculate confidence score based on wall characteristics
  double _calculateConfidence(ui.Rect bounds, int imageWidth, int imageHeight) {
    // Factors:
    // 1. Size: larger walls = higher confidence
    // 2. Position: centered walls = higher confidence
    // 3. Aspect ratio: rectangular walls = higher confidence

    final area = bounds.width * bounds.height;
    final totalArea = imageWidth * imageHeight;
    final areaRatio = area / totalArea;

    // Size confidence (0.3 to 1.0)
    final sizeConfidence = (areaRatio * 2.0).clamp(0.3, 1.0);

    // Center confidence (0.5 to 1.0)
    final centerX = bounds.center.dx;
    final centerY = bounds.center.dy;
    final imageCenterX = imageWidth / 2;
    final imageCenterY = imageHeight / 2;
    final centerDistanceX = (centerX - imageCenterX).abs() / imageCenterX;
    final centerDistanceY = (centerY - imageCenterY).abs() / imageCenterY;
    final centerConfidence = (1.0 - (centerDistanceX + centerDistanceY) / 2).clamp(0.5, 1.0);

    // Aspect ratio confidence (0.7 to 1.0)
    final aspectRatio = bounds.width / bounds.height;
    final aspectConfidence = (aspectRatio > 0.8 && aspectRatio < 2.5) ? 1.0 : 0.7;

    // Combined confidence
    return (sizeConfidence * 0.5 + centerConfidence * 0.3 + aspectConfidence * 0.2).clamp(0.0, 1.0);
  }

  /// Dispose resources
  void dispose() {
    _objectDetector?.close();
    _objectDetector = null;
    _initialized = false;
  }
}

/// Wall Detection Result
class WallDetectionResult {
  final ui.Rect bounds;
  final WallCorners corners;
  final double confidence;
  final ui.Offset centerPoint;

  const WallDetectionResult({
    required this.bounds,
    required this.corners,
    required this.confidence,
    required this.centerPoint,
  });

  /// Check if this is a valid wall detection (confidence > 0.5)
  bool get isValid => confidence > 0.5;

  /// Check if this is a high-quality detection (confidence > 0.8)
  bool get isHighQuality => confidence > 0.8;
}

/// Wall Corners (for perspective transform)
class WallCorners {
  final ui.Offset topLeft;
  final ui.Offset topRight;
  final ui.Offset bottomLeft;
  final ui.Offset bottomRight;

  const WallCorners({
    required this.topLeft,
    required this.topRight,
    required this.bottomLeft,
    required this.bottomRight,
  });

  /// Get all corners as a list
  List<ui.Offset> toList() => [topLeft, topRight, bottomLeft, bottomRight];
}
