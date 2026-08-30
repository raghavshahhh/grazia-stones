import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:grazia_stones/core/services/ai_endpoint_client.dart';
import 'package:grazia_stones/core/services/supabase_service.dart';


/// Room analysis service for detecting walls and surfaces
///
/// Calls the api/wall-detect Vercel endpoint (NVIDIA NIM-backed) for:
/// - Wall detection and segmentation
/// - Surface identification
/// - Confidence scoring
/// - Object detection for occlusion handling
class RoomAnalysisService {
  static RoomAnalysisService? _instance;
  static RoomAnalysisService get instance => _instance ??= RoomAnalysisService._();

  RoomAnalysisService._();

  final _supabase = SupabaseService.instance.client;

  bool _initialized = false;

  /// Initialize service
  void init() {
    if (_initialized) return;
    _initialized = true;
    debugPrint('✅ Room Analysis service initialized');
  }

  /// Analyze room image for walls and surfaces
  ///
  /// Returns analysis result with detected walls and confidence
  Future<RoomAnalysisResult> analyzeRoom({
    required File roomImage,
    bool useSegmentation = true,
  }) async {
    if (!_initialized) init();

    try {
      debugPrint('🔍 Starting room analysis...');

      // Convert image to base64
      final bytes = await roomImage.readAsBytes();
      final base64Image = base64Encode(bytes);
      final imageDataUrl = 'data:image/jpeg;base64,$base64Image';

      // Upload to storage so the result image URL is durable (not just the
      // data: URL), and for the caller to reference the input later.
      final fileName = 'room_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _supabase.storage.from('ai-visualizations').uploadBinary(
            'temp/$fileName',
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              cacheControl: '3600',
            ),
          );

      final imageUrl = _supabase.storage
          .from('ai-visualizations')
          .getPublicUrl('temp/$fileName');

      debugPrint('📤 Image uploaded: $imageUrl');

      final data = await AIEndpointClient.post('/api/wall-detect', {
        'image': imageDataUrl,
        'useSegmentation': useSegmentation,
      });
      // api/wall-detect returns {wallDetected, confidence, walls, objects}
      // without a `success` field — derive it so isUsable works correctly.
      data['success'] = data['wallDetected'] ?? false;
      data['message'] = data['wallDetected'] == true
          ? 'Wall detected'
          : 'No wall detected';

      debugPrint('✅ Room analysis complete');

      return RoomAnalysisResult.fromJson(data);
    } catch (e) {
      debugPrint('❌ Room analysis error: $e');
      throw RoomAnalysisException(
        'Failed to analyze room: $e',
        type: RoomAnalysisErrorType.analysisError,
      );
    }
  }

  /// Analyze room from URL (already uploaded)
  Future<RoomAnalysisResult> analyzeRoomFromUrl(String imageUrl) async {
    if (!_initialized) init();

    try {
      debugPrint('🔍 Analyzing room from URL...');

      final imageResponse = await Dio().get<List<int>>(
        imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = imageResponse.data!;
      final imageDataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      final data = await AIEndpointClient.post('/api/wall-detect', {
        'image': imageDataUrl,
        'useSegmentation': true,
      });
      data['success'] = data['wallDetected'] ?? false;
      data['message'] = data['wallDetected'] == true
          ? 'Wall detected'
          : 'No wall detected';

      return RoomAnalysisResult.fromJson(data);
    } catch (e) {
      debugPrint('❌ Room analysis error: $e');
      throw RoomAnalysisException(
        'Failed to analyze room: $e',
        type: RoomAnalysisErrorType.analysisError,
      );
    }
  }

  /// Check if the AI analysis endpoint is configured (NVIDIA key present)
  Future<bool> isServiceConfigured() async {
    try {
      final data = await AIEndpointClient.post('/api/wall-detect', {
        'image': 'data:image/png;base64,AA==',
        'useSegmentation': false,
      });
      return data['error'] != 'NVIDIA_NIM_API_KEY not configured';
    } catch (e) {
      debugPrint('⚠️ Could not check service configuration: $e');
      return false;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DATA MODELS
// ═══════════════════════════════════════════════════════════════════════════

/// Result of room analysis
class RoomAnalysisResult {
  final bool success;
  final bool wallDetected;
  final double confidence;
  final List<DetectedWall> walls;
  final List<DetectedObject> objects;
  final String message;
  final String? error;

  const RoomAnalysisResult({
    required this.success,
    required this.wallDetected,
    required this.confidence,
    required this.walls,
    required this.objects,
    required this.message,
    this.error,
  });

  factory RoomAnalysisResult.fromJson(Map<String, dynamic> json) {
    return RoomAnalysisResult(
      success: json['success'] as bool? ?? false,
      wallDetected: json['wallDetected'] as bool? ?? false,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      walls: (json['walls'] as List<dynamic>? ?? [])
          .map((w) => DetectedWall.fromJson(w as Map<String, dynamic>))
          .toList(),
      objects: (json['objects'] as List<dynamic>? ?? [])
          .map((o) => DetectedObject.fromJson(o as Map<String, dynamic>))
          .toList(),
      message: json['message'] as String? ?? '',
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'wallDetected': wallDetected,
      'confidence': confidence,
      'walls': walls.map((w) => w.toJson()).toList(),
      'objects': objects.map((o) => o.toJson()).toList(),
      'message': message,
      'error': error,
    };
  }

  /// Get best wall (highest confidence)
  DetectedWall? get bestWall {
    if (walls.isEmpty) return null;
    return walls.reduce((a, b) => a.confidence > b.confidence ? a : b);
  }

  /// Get largest wall (by area)
  DetectedWall? get largestWall {
    if (walls.isEmpty) return null;
    return walls.reduce((a, b) => a.area > b.area ? a : b);
  }

  /// Check if analysis is usable
  bool get isUsable => success && wallDetected && confidence > 0.3;
}

/// Detected wall with polygon and metadata
class DetectedWall {
  final String id;
  final double confidence;
  final List<List<double>> polygon;
  final Map<String, double> boundingBox;
  final double area;
  final bool pixelLevel;

  const DetectedWall({
    required this.id,
    required this.confidence,
    required this.polygon,
    required this.boundingBox,
    required this.area,
    this.pixelLevel = false,
  });

  factory DetectedWall.fromJson(Map<String, dynamic> json) {
    return DetectedWall(
      id: json['id'] as String? ?? 'wall_unknown',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      polygon: (json['polygon'] as List<dynamic>? ?? [])
          .map((p) => (p as List<dynamic>)
              .map((c) => (c as num).toDouble())
              .toList())
          .toList(),
      boundingBox: (json['boundingBox'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, (v as num).toDouble())),
      area: (json['area'] as num?)?.toDouble() ?? 0.0,
      pixelLevel: json['pixelLevel'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'confidence': confidence,
      'polygon': polygon,
      'boundingBox': boundingBox,
      'area': area,
      'pixelLevel': pixelLevel,
    };
  }

  /// Get wall center point (normalized 0-1)
  List<double> get center {
    if (polygon.isEmpty) return [0.5, 0.5];
    
    double sumX = 0, sumY = 0;
    for (final point in polygon) {
      if (point.length >= 2) {
        sumX += point[0];
        sumY += point[1];
      }
    }
    
    final count = polygon.length;
    return [sumX / count, sumY / count];
  }

  /// Get wall dimensions (width, height in normalized units)
  List<double> get dimensions {
    if (boundingBox.isEmpty) return [0.0, 0.0];
    return [
      boundingBox['width'] ?? 0.0,
      boundingBox['height'] ?? 0.0,
    ];
  }
}

/// Detected object on wall (for occlusion)
class DetectedObject {
  final String type;
  final double confidence;
  final List<List<double>> polygon;
  final bool pixelLevel;

  const DetectedObject({
    required this.type,
    required this.confidence,
    required this.polygon,
    this.pixelLevel = false,
  });

  factory DetectedObject.fromJson(Map<String, dynamic> json) {
    return DetectedObject(
      type: json['type'] as String? ?? 'other',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      polygon: (json['polygon'] as List<dynamic>? ?? [])
          .map((p) => (p as List<dynamic>)
              .map((c) => (c as num).toDouble())
              .toList())
          .toList(),
      pixelLevel: json['pixelLevel'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'confidence': confidence,
      'polygon': polygon,
      'pixelLevel': pixelLevel,
    };
  }

  /// Check if object is a major obstruction
  bool get isMajorObstruction {
    return ['furniture', 'window', 'door', 'tv', 'painting'].contains(type) 
        && confidence > 0.6;
  }
}

/// Room analysis exception
class RoomAnalysisException implements Exception {
  final String message;
  final RoomAnalysisErrorType type;
  final dynamic originalError;

  const RoomAnalysisException(
    this.message, {
    required this.type,
    this.originalError,
  });

  @override
  String toString() => 'RoomAnalysisException: $message';
}

/// Room analysis error types
enum RoomAnalysisErrorType {
  notConfigured,
  network,
  analysisError,
  noWallDetected,
  timeout,
  unknown,
}
