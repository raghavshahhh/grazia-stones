import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart';

/// Converts a Flutter logical-pixel screen point into the coordinate space a
/// given native AR hit-test API expects.
///
/// ARKit's `hitTest`/raycast APIs are defined in UIKit "points", which are
/// already the same unit as Flutter's logical pixels (both are the
/// device-independent unit scaled by the same screen scale factor) — so iOS
/// needs no conversion.
///
/// SceneView's `hitTestAR(xPx, yPx)` on Android expects raw native/physical
/// pixels of the underlying Android View, which are `devicePixelRatio` times
/// larger than Flutter's logical pixels. Sending logical pixels there was the
/// bug: on a density-3.0 device a tap at the visual center would raycast at
/// roughly 1/3 of the way into the screen instead.
///
/// Pulled out as a pure function (no platform channel calls) so it can be
/// unit-tested deterministically without a device/plugin.
@visibleForTesting
Offset scaleLogicalPointForNativeAR(
  Offset logicalPoint, {
  required double devicePixelRatio,
  required bool isAndroidNative,
}) {
  if (!isAndroidNative) return logicalPoint;
  return Offset(
    logicalPoint.dx * devicePixelRatio,
    logicalPoint.dy * devicePixelRatio,
  );
}

/// Platform channel for native AR (ARKit on iOS, ARCore on Android)
class ARNativeChannel {
  static const MethodChannel _channel = MethodChannel('com.graziastones.ar/native');

  /// Real device pixel ratio for the current display, used to convert
  /// logical-pixel screen taps into native pixels for Android's SceneView
  /// hit-test APIs. See [scaleLogicalPointForNativeAR].
  static double get _devicePixelRatio =>
      ui.PlatformDispatcher.instance.views.first.devicePixelRatio;

  static Offset _toNativeScreenPoint(Offset logicalPoint) {
    return scaleLogicalPointForNativeAR(
      logicalPoint,
      devicePixelRatio: _devicePixelRatio,
      isAndroidNative: !kIsWeb && Platform.isAndroid,
    );
  }
  static const EventChannel _eventChannel = EventChannel('com.graziastones.ar/events');
  
  static final StreamController<Map<String, dynamic>> _wallDetectedController = 
      StreamController<Map<String, dynamic>>.broadcast();
  static final StreamController<Map<String, dynamic>> _wallUpdatedController = 
      StreamController<Map<String, dynamic>>.broadcast();
  static final StreamController<String> _wallRemovedController = 
      StreamController<String>.broadcast();
  static final StreamController<String> _trackingStateController = 
      StreamController<String>.broadcast();
  static final StreamController<String> _errorController = 
      StreamController<String>.broadcast();
  static final StreamController<String> _wallStateController = 
      StreamController<String>.broadcast();
  static final StreamController<Map<String, dynamic>> _measurementResultController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  // Public streams
  static Stream<Map<String, dynamic>> get onWallDetected => _wallDetectedController.stream;
  static Stream<Map<String, dynamic>> get onWallUpdated => _wallUpdatedController.stream;
  static Stream<String> get onWallRemoved => _wallRemovedController.stream;
  static Stream<String> get onTrackingStateChanged => _trackingStateController.stream;
  static Stream<String> get onError => _errorController.stream;
  static Stream<String> get onWallStateChanged => _wallStateController.stream;
  static Stream<Map<String, dynamic>> get onMeasurementResult => _measurementResultController.stream;
  
  /// Initialize the platform channel and event listeners
  static Future<void> initialize() async {
    _eventChannel.receiveBroadcastStream().listen(_onEvent, onError: _onEventError);
    debugPrint('[ARNativeChannel] Initialized');
  }
  
  static void _onEvent(dynamic event) {
    if (event is Map) {
      final type = event['type'] as String?;
      final data = event['data'] as Map?;
      
      switch (type) {
        case 'wallDetected':
          _wallDetectedController.add(Map<String, dynamic>.from(data ?? {}));
          break;
        case 'wallUpdated':
          _wallUpdatedController.add(Map<String, dynamic>.from(data ?? {}));
          break;
        case 'wallRemoved':
          _wallRemovedController.add(data?['id'] as String? ?? '');
          break;
        case 'trackingStateChanged':
          _trackingStateController.add(data?['state'] as String? ?? 'UNKNOWN');
          break;
        case 'wallStateChanged':
          _wallStateController.add(data?['state'] as String? ?? 'SEARCHING');
          break;
        case 'measurementResult':
          _measurementResultController.add(Map<String, dynamic>.from(data ?? {}));
          break;
        case 'error':
          _errorController.add(data?['message'] as String? ?? 'Unknown error');
          break;
      }
    }
  }
  
  static void _onEventError(dynamic error) {
    debugPrint('[ARNativeChannel] Event error: $error');
  }
  
  // MARK: - Session Control
  
  /// Start the AR session
  static Future<void> startSession() async {
    try {
      await _channel.invokeMethod('startSession');
      debugPrint('[ARNativeChannel] Session started');
    } on PlatformException catch (e) {
      debugPrint('[ARNativeChannel] Failed to start session: ${e.message}');
      rethrow;
    }
  }
  
  /// Pause the AR session
  static Future<void> pauseSession() async {
    try {
      await _channel.invokeMethod('pauseSession');
      debugPrint('[ARNativeChannel] Session paused');
    } on PlatformException catch (e) {
      debugPrint('[ARNativeChannel] Failed to pause session: ${e.message}');
      rethrow;
    }
  }
  
  /// Resume the AR session
  static Future<void> resumeSession() async {
    try {
      await _channel.invokeMethod('resumeSession');
      debugPrint('[ARNativeChannel] Session resumed');
    } on PlatformException catch (e) {
      debugPrint('[ARNativeChannel] Failed to resume session: ${e.message}');
      rethrow;
    }
  }
  
  // MARK: - Wall Management
  
  /// Select a specific wall for texturing
  static Future<void> selectWall(String wallId) async {
    try {
      await _channel.invokeMethod('selectWall', {'wallId': wallId});
      debugPrint('[ARNativeChannel] Selected wall: $wallId');
    } on PlatformException catch (e) {
      debugPrint('[ARNativeChannel] Failed to select wall: ${e.message}');
      rethrow;
    }
  }
  
  /// Get all detected walls
  static Future<List<Map<String, dynamic>>> getWalls() async {
    try {
      final result = await _channel.invokeMethod('getWalls');
      return List<Map<String, dynamic>>.from(result as List);
    } on PlatformException catch (e) {
      debugPrint('[ARNativeChannel] Failed to get walls: ${e.message}');
      rethrow;
    }
  }
  
  /// Get currently selected wall ID
  static Future<String?> getSelectedWallId() async {
    try {
      final result = await _channel.invokeMethod('getSelectedWallId');
      return result as String?;
    } on PlatformException catch (e) {
      debugPrint('[ARNativeChannel] Failed to get selected wall: ${e.message}');
      return null;
    }
  }
  
  // MARK: - Texture Management
  
  /// Set the texture for the selected wall
  static Future<void> setTexture(Uint8List imageData) async {
    try {
      await _channel.invokeMethod('setTexture', {'imageData': imageData});
      debugPrint('[ARNativeChannel] Texture set (${imageData.length} bytes)');
    } on PlatformException catch (e) {
      debugPrint('[ARNativeChannel] Failed to set texture: ${e.message}');
      rethrow;
    }
  }
  
  /// Clear the current texture
  static Future<void> clearTexture() async {
    try {
      await _channel.invokeMethod('clearTexture');
      debugPrint('[ARNativeChannel] Texture cleared');
    } on PlatformException catch (e) {
      debugPrint('[ARNativeChannel] Failed to clear texture: ${e.message}');
      rethrow;
    }
  }
  
  // MARK: - Measurement
  
  /// Start a new measurement
  static Future<void> startMeasurement() async {
    try {
      await _channel.invokeMethod('startMeasurement');
      debugPrint('[ARNativeChannel] Measurement started');
    } on PlatformException catch (e) {
      debugPrint('[ARNativeChannel] Failed to start measurement: ${e.message}');
      rethrow;
    }
  }
  
  /// Add a measurement point at world coordinates
  static Future<String> addMeasurementPoint(Vector3 point) async {
    try {
      final result = await _channel.invokeMethod('addMeasurementPoint', {
        'x': point.x,
        'y': point.y,
        'z': point.z,
      });
      return result as String;
    } on PlatformException catch (e) {
      debugPrint('[ARNativeChannel] Failed to add measurement point: ${e.message}');
      rethrow;
    }
  }

  /// Ray-cast a screen-space tap against the detected wall plane and place a
  /// real ARKit world-space measurement anchor there. Returns null if the tap
  /// didn't hit a tracked wall plane (never falls back to screen coordinates).
  static Future<Map<String, dynamic>?> hitTestWallAtScreenPoint(Offset screenPoint) async {
    try {
      final nativePoint = _toNativeScreenPoint(screenPoint);
      final result = await _channel.invokeMethod('hitTestWallAtScreenPoint', {
        'screenX': nativePoint.dx,
        'screenY': nativePoint.dy,
      });
      if (result == null) return null;
      return Map<String, dynamic>.from(result as Map);
    } on PlatformException catch (e) {
      debugPrint('[ARNativeChannel] Failed to hit-test wall: ${e.message}');
      return null;
    }
  }
  
  /// Get the current measurement distance in meters
  static Future<double?> getMeasurementDistance() async {
    try {
      final result = await _channel.invokeMethod('getMeasurementDistance');
      return (result as num?)?.toDouble();
    } on PlatformException catch (e) {
      debugPrint('[ARNativeChannel] Failed to get measurement: ${e.message}');
      return null;
    }
  }
  
  /// Clear measurement anchors
  static Future<void> clearMeasurement() async {
    try {
      await _channel.invokeMethod('clearMeasurement');
      debugPrint('[ARNativeChannel] Measurement cleared');
    } on PlatformException catch (e) {
      debugPrint('[ARNativeChannel] Failed to clear measurement: ${e.message}');
      rethrow;
    }
  }
  
  // MARK: - Calibration
  
  /// Start calibration mode
  static Future<void> startCalibration({String unit = 'ft'}) async {
    try {
      await _channel.invokeMethod('startCalibration', {'unit': unit});
      debugPrint('[ARNativeChannel] Calibration started');
    } on PlatformException catch (e) {
      debugPrint('[ARNativeChannel] Failed to start calibration: ${e.message}');
      rethrow;
    }
  }
  
  /// Finish calibration with known real-world length
  static Future<bool> finishCalibration(double realLength) async {
    try {
      final result = await _channel.invokeMethod('finishCalibration', {'realLength': realLength});
      return result as bool? ?? false;
    } on PlatformException catch (e) {
      debugPrint('[ARNativeChannel] Failed to finish calibration: ${e.message}');
      return false;
    }
  }
  
  /// Get current calibration info
  static Future<Map<String, dynamic>?> getCalibration() async {
    try {
      final result = await _channel.invokeMethod('getCalibration');
      if (result == null) return null;
      return Map<String, dynamic>.from(result as Map);
    } on PlatformException catch (e) {
      debugPrint('[ARNativeChannel] Failed to get calibration: ${e.message}');
      return null;
    }
  }
  
  /// Measure distance between two screen points (requires calibration)
  static Future<double?> measureDistance(Offset p1, Offset p2) async {
    try {
      final n1 = _toNativeScreenPoint(p1);
      final n2 = _toNativeScreenPoint(p2);
      final result = await _channel.invokeMethod('measureDistance', {
        'x1': n1.dx,
        'y1': n1.dy,
        'x2': n2.dx,
        'y2': n2.dy,
      });
      return (result as num?)?.toDouble();
    } on PlatformException catch (e) {
      debugPrint('[ARNativeChannel] Failed to measure distance: ${e.message}');
      return null;
    }
  }
  
  // MARK: - Tile Quantity Calculation
  
  /// Calculate tile quantity for the selected wall
  static Future<Map<String, dynamic>?> calculateTileQuantity({
    required double tileWidth,
    required double tileHeight,
    String tileUnit = 'ft',
    double wastagePercent = 10.0,
  }) async {
    try {
      final result = await _channel.invokeMethod('calculateTileQuantity', {
        'tileWidth': tileWidth,
        'tileHeight': tileHeight,
        'tileUnit': tileUnit,
        'wastagePercent': wastagePercent,
      });
      if (result == null) return null;
      return Map<String, dynamic>.from(result as Map);
    } on PlatformException catch (e) {
      debugPrint('[ARNativeChannel] Failed to calculate tile quantity: ${e.message}');
      return null;
    }
  }
  
  // MARK: - Wall State
  
  /// Get current wall tracking state
  static Future<String> getWallState() async {
    try {
      final result = await _channel.invokeMethod('getWallState');
      return result as String? ?? 'SEARCHING';
    } on PlatformException catch (e) {
      debugPrint('[ARNativeChannel] Failed to get wall state: ${e.message}');
      return 'SEARCHING';
    }
  }
  
  // MARK: - Texture Preloading
  
  /// Preload a texture for instant switching
  static Future<void> preloadTexture(String textureUrl) async {
    try {
      await _channel.invokeMethod('preloadTexture', {'textureUrl': textureUrl});
    } on PlatformException catch (e) {
      debugPrint('[ARNativeChannel] Failed to preload texture: ${e.message}');
    }
  }
  
  // MARK: - Camera Access
  
  /// Get the AR scene view for embedding in Flutter
  static Widget getARView() {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return const _ARKitView();
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return const _ARCoreView();
    }
    return const SizedBox.shrink();
  }
  
  /// Check if AR is supported on this device
  static Future<bool> isARSupported() async {
    try {
      final result = await _channel.invokeMethod('isARSupported');
      return result as bool? ?? false;
    } on PlatformException {
      return false;
    }
  }
  
  /// Check if LiDAR is available
  static Future<bool> hasLiDAR() async {
    try {
      final result = await _channel.invokeMethod('hasLiDAR');
      return result as bool? ?? false;
    } on PlatformException {
      return false;
    }
  }
  
  /// Stop the AR camera
  static Future<void> stopCamera() async {
    try {
      await _channel.invokeMethod('stopCamera');
      debugPrint('[ARNativeChannel] Camera stopped');
    } on PlatformException catch (e) {
      debugPrint('[ARNativeChannel] Failed to stop camera: ${e.message}');
    }
  }
  
  /// Dispose resources
  static void dispose() {
    _wallDetectedController.close();
    _wallUpdatedController.close();
    _wallRemovedController.close();
    _trackingStateController.close();
    _wallStateController.close();
    _measurementResultController.close();
    _errorController.close();
  }
}

/// iOS ARKit Platform View
class _ARKitView extends StatelessWidget {
  const _ARKitView();

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        viewType: 'com.graziastones.ar/arkit_view',
        layoutDirection: TextDirection.ltr,
        creationParams: <String, dynamic>{},
        creationParamsCodec: const StandardMessageCodec(),
      );
    }
    return const SizedBox.shrink();
  }
}

/// Android ARCore Platform View (SceneView-backed, see ARCorePlatformView.kt)
class _ARCoreView extends StatelessWidget {
  const _ARCoreView();

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return const AndroidView(
        viewType: 'com.graziastones.ar/arcore_view',
        layoutDirection: TextDirection.ltr,
        creationParams: <String, dynamic>{},
        creationParamsCodec: StandardMessageCodec(),
      );
    }
    return const SizedBox.shrink();
  }
}