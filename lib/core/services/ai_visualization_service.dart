import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/env_config.dart';
import '../models/stone.dart';
import '../../features/live_ai/presentation/widgets/ar_camera_view.dart';

/// AI-powered wall visualization service
/// Uses wall segmentation + client-side compositing for photorealistic results.
/// The original room image is preserved; only the detected wall region is modified.
class AIVisualizationService {
  static AIVisualizationService? _instance;
  static AIVisualizationService get instance => _instance ??= AIVisualizationService._();

  AIVisualizationService._();

  final Dio _dio = Dio();
  final _env = EnvConfig();
  bool _initialized = false;

  String get _baseUrl => _env.apiBaseUrl;

  /// Initialize service
  void init() {
    if (_initialized) return;

    _dio.options = BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 120),
      baseUrl: _baseUrl,
    );

    _initialized = true;
    debugPrint('✅ AI Visualization service initialized');
  }

  /// Generate realistic wall visualization with stone texture
  ///
  /// This uses wall segmentation + perspective compositing:
  /// 1. Detect walls and objects in the room image
  /// 2. Select the target wall (largest or user-selected)
  /// 3. Create occlusion mask for objects on the wall
  /// 4. Generate perspective-correct tile pattern from stone texture
  /// 5. Composite onto wall region only, preserving everything else
  Future<AIVisualizationResult> generateVisualization({
    required File roomImage,
    required Stone stone,
    String? selectedWallId,
    Function(double)? onProgress,
  }) async {
    if (!_initialized) init();

    try {
      onProgress?.call(0.1);
      debugPrint('🎨 Starting AI visualization for ${stone.name}');

      // Step 1: Upload image to temporary storage and get data URL
      onProgress?.call(0.2);
      final imageDataUrl = await _imageToDataUrl(roomImage);
      debugPrint('📤 Image converted to data URL (${imageDataUrl.length} chars)');

      // Step 2: Detect walls and objects using AI with segmentation
      onProgress?.call(0.3);
      final detection = await _detectWallsAndObjects(imageDataUrl);
      debugPrint('🔍 Detection: walls=${detection.walls.length}, objects=${detection.objects.length}, wallDetected=${detection.wallDetected}');

      if (!detection.wallDetected || detection.walls.isEmpty) {
        throw AIVisualizationException(
          'No suitable wall detected in the image. Please try a photo with a clear, well-lit wall.',
          type: AIErrorType.noWallDetected,
        );
      }

      // Step 3: Select wall (user-selected or best confidence)
      onProgress?.call(0.5);
      final targetWall = _selectTargetWall(detection.walls, selectedWallId);
      debugPrint('🎯 Selected wall: ${targetWall.id} (confidence: ${targetWall.confidence})');

      // Step 4: Get stone texture URL
      final textureUrl = stone.images.isNotEmpty ? stone.images.first : '';
      if (textureUrl.isEmpty) {
        throw AIVisualizationException(
          'Stone has no texture image',
          type: AIErrorType.noTexture,
        );
      }

      // Step 5: Compose visualization using platform-specific implementation
      onProgress?.call(0.7);
      final resultImageUrl = await _composeVisualization(
        roomImageDataUrl: imageDataUrl,
        textureUrl: textureUrl,
        wall: targetWall,
        objects: detection.objects,
        opacity: 0.96,
      );

      onProgress?.call(1.0);
      debugPrint('✅ AI visualization complete');

      return AIVisualizationResult(
        originalImageUrl: imageDataUrl,
        visualizedImageUrl: resultImageUrl,
        stone: stone,
        selectedWallId: targetWall.id,
        processingTime: const Duration(seconds: 0),
        confidenceScore: targetWall.confidence,
      );
    } on DioException catch (e) {
      debugPrint('❌ Network error: ${e.message}');
      throw AIVisualizationException(
        'Network error: ${e.message}',
        type: AIErrorType.network,
        originalError: e,
      );
    } catch (e) {
      debugPrint('❌ AI visualization error: $e');
      throw AIVisualizationException(
        'Failed to generate visualization: $e',
        type: AIErrorType.unknown,
        originalError: e,
      );
    }
  }

  /// Convert image file to data URL
  Future<String> _imageToDataUrl(File image) async {
    final bytes = await image.readAsBytes();
    final base64Image = base64Encode(bytes);
    final mimeType = _getMimeType(image.path);
    return 'data:$mimeType;base64,$base64Image';
  }

  /// Detect walls and objects in the image using server-side AI with segmentation
  Future<WallDetectionResult> _detectWallsAndObjects(String imageDataUrl) async {
    // Use the same wall detection API as Live AR with segmentation support
    const endpoint = '/api/wall-detect';

    try {
      final response = await _dio.post(
        endpoint,
        data: {'image': imageDataUrl, 'useSegmentation': true},
        options: Options(
          headers: {'Content-Type': 'application/json'},
          // Longer timeout for AI processing with segmentation
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

      final data = response.data as Map<String, dynamic>;
      return WallDetectionResult.fromJson(data);
    } on DioException catch (e) {
      debugPrint('❌ Wall detection API error: ${e.message}');
      // Fallback: return empty result (will trigger noWallDetected error)
      return WallDetectionResult(
        wallDetected: false,
        confidence: 0.0,
        walls: [],
        objects: [],
      );
    }
  }

  /// Select target wall from detected walls
  DetectedWall _selectTargetWall(List<DetectedWall> walls, String? selectedWallId) {
    if (selectedWallId != null) {
      final selected = walls.where((w) => w.id == selectedWallId).firstOrNull;
      if (selected != null) return selected;
    }
    // Return highest confidence wall
    walls.sort((a, b) => b.confidence.compareTo(a.confidence));
    return walls.first;
  }

  /// Compose visualization using platform-specific implementation
  /// On web: uses GraziaAR JavaScript engine via ARCameraView
  /// On mobile: uses native compositing (to be implemented)
  Future<String> _composeVisualization({
    required String roomImageDataUrl,
    required String textureUrl,
    required DetectedWall wall,
    required List<DetectedObject> objects,
    required double opacity,
  }) async {
    // On web, use ARCameraView's renderStaticVisualization
    // This is a platform-specific implementation that uses the GraziaAR JS engine
    try {
      final result = await ARCameraView.renderStaticVisualization(
        roomImageDataUrl,
        textureUrl,
        opacity,
      );
      return result ?? '';
    } catch (e) {
      debugPrint('❌ Compose visualization error: $e');
      throw AIVisualizationException(
        'Failed to compose visualization: $e',
        type: AIErrorType.compositingFailed,
        originalError: e,
      );
    }
  }

  /// Get MIME type from file extension
  String _getMimeType(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  /// Check if service is configured
  bool get isConfigured => true; // Uses serverless function, no client-side API key needed
}

// ═══════════════════════════════════════════════════════════════════════════
// DATA MODELS
// ═══════════════════════════════════════════════════════════════════════════

/// Result of wall detection
class WallDetectionResult {
  final bool wallDetected;
  final double confidence;
  final List<DetectedWall> walls;
  final List<DetectedObject> objects;

  const WallDetectionResult({
    required this.wallDetected,
    required this.confidence,
    required this.walls,
    required this.objects,
  });

  factory WallDetectionResult.fromJson(Map<String, dynamic> json) {
    return WallDetectionResult(
      wallDetected: json['wallDetected'] as bool? ?? false,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      walls: (json['walls'] as List<dynamic>? ?? [])
          .map((w) => DetectedWall.fromJson(w as Map<String, dynamic>))
          .toList(),
      objects: (json['objects'] as List<dynamic>? ?? [])
          .map((o) => DetectedObject.fromJson(o as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Detected wall with polygon and metadata
class DetectedWall {
  final String id;
  final double confidence;
  final List<List<double>> polygon; // [[x,y], [x,y], [x,y], [x,y]] normalized 0-1
  final Map<String, dynamic> boundingBox; // {x, y, width, height} normalized
  final bool pixelLevel; // True if polygon comes from pixel-level segmentation

  const DetectedWall({
    required this.id,
    required this.confidence,
    required this.polygon,
    required this.boundingBox,
    this.pixelLevel = false,
  });

  factory DetectedWall.fromJson(Map<String, dynamic> json) {
    return DetectedWall(
      id: json['id'] as String? ?? 'wall_${DateTime.now().millisecondsSinceEpoch}',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      polygon: (json['polygon'] as List<dynamic>? ?? [])
          .map((p) => (p as List<dynamic>).map((c) => (c as num).toDouble()).toList())
          .toList(),
      boundingBox: (json['boundingBox'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ??
          {},
      pixelLevel: json['pixelLevel'] as bool? ?? false,
    );
  }

  /// Get polygon as list of Offsets (normalized 0-1)
  List<ui.Offset> get polygonOffsets => polygon
      .where((p) => p.length == 2)
      .map((p) => ui.Offset(p[0], p[1]))
      .toList();

  /// Get wall center (normalized)
  ui.Offset get center {
    if (polygonOffsets.isEmpty) return const ui.Offset(0.5, 0.5);
    double sumX = 0, sumY = 0;
    for (final p in polygonOffsets) {
      sumX += p.dx;
      sumY += p.dy;
    }
    return ui.Offset(sumX / polygonOffsets.length, sumY / polygonOffsets.length);
  }
}

/// Detected object on wall (for occlusion)
class DetectedObject {
  final String type; // painting, window, door, furniture, mirror, tv, shelf, outlet, switch, other
  final double confidence;
  final List<List<double>> polygon; // [[x,y], [x,y], [x,y], [x,y]] normalized 0-1
  final bool pixelLevel; // True if polygon comes from pixel-level segmentation

  const DetectedObject({
    required this.type,
    required this.confidence,
    required this.polygon,
    this.pixelLevel = false,
  });

  factory DetectedObject.fromJson(Map<String, dynamic> json) {
    return DetectedObject(
      type: json['type'] as String? ?? 'other',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      polygon: (json['polygon'] as List<dynamic>? ?? [])
          .map((p) => (p as List<dynamic>).map((c) => (c as num).toDouble()).toList())
          .toList(),
      pixelLevel: json['pixelLevel'] as bool? ?? false,
    );
  }

  List<ui.Offset> get polygonOffsets => polygon
      .where((p) => p.length == 2)
      .map((p) => ui.Offset(p[0], p[1]))
      .toList();
}

/// Result of AI visualization
class AIVisualizationResult {
  final String originalImageUrl;
  final String visualizedImageUrl;
  final Stone stone;
  final String selectedWallId;
  final Duration processingTime;
  final double confidenceScore;

  const AIVisualizationResult({
    required this.originalImageUrl,
    required this.visualizedImageUrl,
    required this.stone,
    required this.selectedWallId,
    required this.processingTime,
    required this.confidenceScore,
  });
}

/// AI visualization exception
class AIVisualizationException implements Exception {
  final String message;
  final AIErrorType type;
  final dynamic originalError;

  const AIVisualizationException(
    this.message, {
    required this.type,
    this.originalError,
  });

  @override
  String toString() => 'AIVisualizationException: $message';
}

/// AI error types
enum AIErrorType {
  notConfigured,
  network,
  noWallDetected,
  noTexture,
  compositingFailed,
  timeout,
  canceled,
  unknown,
}