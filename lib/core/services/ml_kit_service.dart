import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:camera/camera.dart';

/// ML Kit service for image labeling and object detection
class MLKitService {
  static MLKitService? _instance;
  static MLKitService get instance => _instance ??= MLKitService._();
  
  MLKitService._();

  ImageLabeler? _imageLabeler;
  bool _isInitialized = false;

  /// Initialize ML Kit image labeler
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Initialize with default image labeler options
      final options = ImageLabelerOptions(
        confidenceThreshold: 0.5, // Only labels with 50%+ confidence
      );
      
      _imageLabeler = ImageLabeler(options: options);
      _isInitialized = true;
      
      debugPrint('✅ ML Kit service initialized');
    } catch (e) {
      debugPrint('❌ ML Kit initialization error: $e');
      rethrow;
    }
  }

  /// Process camera image for stone detection
  Future<List<DetectedLabel>> processImage(CameraImage image) async {
    if (!_isInitialized || _imageLabeler == null) {
      throw Exception('ML Kit not initialized. Call init() first.');
    }

    try {
      // Convert CameraImage to InputImage
      final inputImage = _convertCameraImage(image);
      
      if (inputImage == null) {
        debugPrint('❌ Failed to convert camera image');
        return [];
      }

      // Process image with ML Kit
      final labels = await _imageLabeler!.processImage(inputImage);
      
      // Filter stone-related labels
      final stoneLabels = _filterStoneRelatedLabels(labels);
      
      debugPrint('✅ Detected ${stoneLabels.length} stone-related labels');
      
      return stoneLabels.map((label) => DetectedLabel(
        label: label.label,
        confidence: label.confidence,
        index: label.index,
      )).toList();
      
    } catch (e) {
      debugPrint('❌ Image processing error: $e');
      return [];
    }
  }

  /// Process image from file path
  Future<List<DetectedLabel>> processImageFile(String filePath) async {
    if (!_isInitialized || _imageLabeler == null) {
      throw Exception('ML Kit not initialized. Call init() first.');
    }

    try {
      final inputImage = InputImage.fromFilePath(filePath);
      final labels = await _imageLabeler!.processImage(inputImage);
      
      final stoneLabels = _filterStoneRelatedLabels(labels);
      
      return stoneLabels.map((label) => DetectedLabel(
        label: label.label,
        confidence: label.confidence,
        index: label.index,
      )).toList();
      
    } catch (e) {
      debugPrint('❌ File processing error: $e');
      return [];
    }
  }

  /// Convert CameraImage to InputImage
  InputImage? _convertCameraImage(CameraImage image) {
    try {
      // Get image rotation
      final rotation = InputImageRotation.rotation0deg;

      // Get image format
      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null) return null;

      // Get plane data
      final plane = image.planes.first;
      
      // Create InputImage
      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    } catch (e) {
      debugPrint('❌ Camera image conversion error: $e');
      return null;
    }
  }

  /// Filter labels related to stones, marble, granite, etc.
  List<ImageLabel> _filterStoneRelatedLabels(List<ImageLabel> labels) {
    // Keywords related to stones and construction materials
    const stoneKeywords = [
      'stone', 'marble', 'granite', 'tile', 'floor', 'wall',
      'rock', 'surface', 'material', 'texture', 'pattern',
      'ceramic', 'porcelain', 'slate', 'limestone', 'sandstone',
      'travertine', 'quartzite', 'onyx', 'basalt', 'terrazzo',
      'countertop', 'flooring', 'cladding', 'veneer'
    ];

    return labels.where((label) {
      final labelLower = label.label.toLowerCase();
      return stoneKeywords.any((keyword) => labelLower.contains(keyword));
    }).toList();
  }

  /// Get stone properties from detected labels
  Map<String, dynamic> analyzeStoneProperties(List<DetectedLabel> labels) {
    if (labels.isEmpty) {
      return {
        'detected': false,
        'confidence': 0.0,
        'properties': <String, dynamic>{},
      };
    }

    // Get highest confidence label
    final bestLabel = labels.reduce((a, b) => 
      a.confidence > b.confidence ? a : b
    );

    // Analyze properties based on labels
    final properties = <String, String>{};
    
    for (final label in labels) {
      final labelLower = label.label.toLowerCase();
      
      // Material type
      if (labelLower.contains('marble')) {
        properties['material'] = 'Marble';
      } else if (labelLower.contains('granite')) {
        properties['material'] = 'Granite';
      } else if (labelLower.contains('ceramic')) {
        properties['material'] = 'Ceramic';
      }
      
      // Surface type
      if (labelLower.contains('floor')) {
        properties['application'] = 'Flooring';
      } else if (labelLower.contains('wall')) {
        properties['application'] = 'Wall Cladding';
      } else if (labelLower.contains('countertop')) {
        properties['application'] = 'Countertop';
      }
      
      // Pattern/Texture
      if (labelLower.contains('pattern')) {
        properties['texture'] = 'Patterned';
      } else if (labelLower.contains('smooth')) {
        properties['texture'] = 'Smooth';
      }
    }

    return {
      'detected': true,
      'confidence': bestLabel.confidence,
      'primaryLabel': bestLabel.label,
      'properties': properties,
      'allLabels': labels.map((l) => {
        'label': l.label,
        'confidence': l.confidence,
      }).toList(),
    };
  }

  /// Match detected properties with stone database
  String? matchStoneFromDatabase(
    Map<String, dynamic> detectedProperties,
    List<Map<String, dynamic>> stoneDatabase,
  ) {
    if (!detectedProperties['detected']) return null;

    final properties = detectedProperties['properties'] as Map<String, String>;
    final material = properties['material']?.toLowerCase();
    
    // Simple matching logic - can be enhanced
    for (final stone in stoneDatabase) {
      final stoneName = (stone['name'] as String?)?.toLowerCase() ?? '';
      final stoneCollection = (stone['collection'] as String?)?.toLowerCase() ?? '';
      
      if (material != null) {
        if (stoneName.contains(material) || stoneCollection.contains(material)) {
          return stone['id'] as String?;
        }
      }
    }
    
    return null;
  }

  /// Dispose ML Kit resources
  Future<void> dispose() async {
    try {
      await _imageLabeler?.close();
      _imageLabeler = null;
      _isInitialized = false;
      debugPrint('✅ ML Kit service disposed');
    } catch (e) {
      debugPrint('❌ ML Kit disposal error: $e');
    }
  }
}

/// Detected label data class
class DetectedLabel {
  final String label;
  final double confidence;
  final int index;

  DetectedLabel({
    required this.label,
    required this.confidence,
    required this.index,
  });

  @override
  String toString() {
    return 'DetectedLabel(label: $label, confidence: ${(confidence * 100).toStringAsFixed(1)}%)';
  }
}
