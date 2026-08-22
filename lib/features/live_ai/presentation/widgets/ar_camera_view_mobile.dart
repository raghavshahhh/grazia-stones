/// Mobile implementation of ARCameraView using camera package
/// Works on Android and iOS with real device camera
library;

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

class ARCameraView extends StatefulWidget {
  const ARCameraView({
    super.key,
    this.onReady,
    this.onError,
    this.stoneImagePath,
    this.opacity = 0.72,
    this.scale = 1.0,
    this.position = Offset.zero,
    this.rotation = 0.0,
  });

  final VoidCallback? onReady;
  final VoidCallback? onError;
  final String? stoneImagePath;
  final double opacity;
  final double scale;
  final Offset position;
  final double rotation;

  // Static control API
  static final _controller = StreamController<_ARUpdate>.broadcast();

  static void updateStone(String? assetPath, double opacity) {
    _controller.add(_ARUpdate(stone: assetPath, opacity: opacity));
  }

  static void updateOpacity(double opacity) {
    _controller.add(_ARUpdate(opacity: opacity));
  }

  static void updateScale(double scale) {
    _controller.add(_ARUpdate(scale: scale));
  }

  static void updatePosition(Offset position) {
    _controller.add(_ARUpdate(position: position));
  }

  static void updateRotation(double rotation) {
    _controller.add(_ARUpdate(rotation: rotation));
  }

  static void showWallBoundary(bool show) {
    _controller.add(_ARUpdate(showBoundary: show));
  }

  // ponytail: no native video capture on mobile yet, web is the only
  // deployed target — wire up camera-package recording if mobile ships.
  static void startRecording() {}

  static void stopRecording() {}

  static Map<String, Offset>? getWallCorners() => null;

  static void setManualCorner(String name, Offset value) {}

  static void clearManualCorners() {}

  static Future<String?> renderStaticVisualization(
          String roomImageDataUrl, String textureDataUrl, double opacity) async =>
      null;

  // New Enhanced API stubs (mobile not yet implemented)
  static List<Map<String, dynamic>>? getWalls() => null;
  static bool selectWall(String wallId) => false;
  static void startCalibration({String unit = 'ft'}) {}
  static bool finishCalibration(double realLength) => false;
  static Map<String, dynamic>? getCalibration() => null;
  static double? measureDistance(Offset p1, Offset p2) => null;
  static Map<String, dynamic>? calculateTileQuantity({
    required double tileWidth,
    required double tileHeight,
    String tileUnit = 'ft',
    double wastagePercent = 10.0,
  }) =>
      null;
  
  static void requestSegmentation() {}
  
  static void setTileDimensions(double width, double height, String unit) {}

  static void stopCamera() {
    _controller.add(_ARUpdate(stop: true));
  }

  @override
  State<ARCameraView> createState() => _ARCameraViewState();
}

class _ARUpdate {
  final String? stone;
  final double? opacity;
  final double? scale;
  final Offset? position;
  final double? rotation;
  final bool? showBoundary;
  final bool? stop;

  _ARUpdate({
    this.stone,
    this.opacity,
    this.scale,
    this.position,
    this.rotation,
    this.showBoundary,
    this.stop,
  });
}

class _ARCameraViewState extends State<ARCameraView>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isPermissionDenied = false;
  String? _error;

  String? _displayStoneTexture;
  double _displayOpacity = 0.72;
  double _displayScale = 1.0;
  Offset _displayPosition = Offset.zero;
  double _displayRotation = 0.0;
  bool _showWallBracket = false;

  StreamSubscription? _updateSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _displayStoneTexture = widget.stoneImagePath;
    _displayOpacity = widget.opacity;
    _displayScale = widget.scale;
    _displayPosition = widget.position;
    _displayRotation = widget.rotation;
    _initializeCamera();

    // Listen to static updates
    _updateSubscription = ARCameraView._controller.stream.listen((update) {
      if (!mounted) return;
      setState(() {
        if (update.stone != null) _displayStoneTexture = update.stone;
        if (update.opacity != null) _displayOpacity = update.opacity!;
        if (update.scale != null) _displayScale = update.scale!;
        if (update.position != null) _displayPosition = update.position!;
        if (update.rotation != null) _displayRotation = update.rotation!;
        if (update.showBoundary != null) _showWallBracket = update.showBoundary!;
        if (update.stop == true) _disposeCamera();
      });
    });
  }

  Future<void> _initializeCamera() async {
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        setState(() {
          _isPermissionDenied = true;
          _error = 'Camera permission is required';
        });
        widget.onError?.call();
        return;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'No cameras available');
        widget.onError?.call();
        return;
      }

      CameraDescription? backCamera;
      for (final camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.back) {
          backCamera = camera;
          break;
        }
      }

      _controller = CameraController(
        backCamera ?? cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _controller!.initialize();

      if (!mounted) return;

      setState(() => _isInitialized = true);
      widget.onReady?.call();

      if (_displayStoneTexture != null) {
        ARCameraView.updateStone(_displayStoneTexture, _displayOpacity);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Camera failed: $e');
      widget.onError?.call();
    }
  }

  void _disposeCamera() {
    _controller?.dispose();
    _controller = null;
    if (mounted) setState(() => _isInitialized = false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updateSubscription?.cancel();
    _disposeCamera();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _disposeCamera();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isPermissionDenied) return _buildPermissionDenied();
    if (_error != null) return _buildErrorState();
    if (!_isInitialized || _controller == null) {
      return const SizedBox.shrink();
    }
    return _buildCameraPreview();
  }

  Widget _buildCameraPreview() {
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Camera feed - fills entire screen
          _buildCameraFeed(),
          // Stone texture overlay
          if (_displayStoneTexture != null) _buildTextureOverlay(),
          // Wall boundary bracket
          if (_showWallBracket) _buildWallBracket(),
        ],
      ),
    );
  }

  /// Camera feed using FittedBox with BoxFit.cover for proper screen fill
  Widget _buildCameraFeed() {
    final previewSize = _controller!.value.previewSize!;

    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: previewSize.height,
        height: previewSize.width,
        child: RotatedBox(
          quarterTurns: 1,
          child: CameraPreview(_controller!),
        ),
      ),
    );
  }

  /// Stone texture overlay with opacity, scale, and rotation
  Widget _buildTextureOverlay() {
    return Positioned.fill(
      child: Opacity(
        opacity: _displayOpacity,
        child: Transform.scale(
          scale: _displayScale,
          child: Transform.translate(
            offset: _displayPosition,
            child: Transform.rotate(
              angle: _displayRotation,
              child: Image.asset(
                _displayStoneTexture!,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => Container(
                  color: Colors.amber.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionDenied() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.camera_alt_outlined, color: Colors.white.withValues(alpha: 0.5), size: 48),
            const SizedBox(height: 16),
            Text(
              'Camera permission denied',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enable in Settings',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontFamily: 'Inter',
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => openAppSettings(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC8A53C),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text('Open Settings', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.red.withValues(alpha: 0.8), size: 48),
              const SizedBox(height: 16),
              Text(
                _error ?? 'Unknown error',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontFamily: 'Inter',
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _error = null;
                    _isPermissionDenied = false;
                  });
                  _initializeCamera();
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC8A53C),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWallBracket() {
    return Positioned(
      top: MediaQuery.of(context).size.height * 0.08,
      left: MediaQuery.of(context).size.width * 0.04,
      right: MediaQuery.of(context).size.width * 0.04,
      bottom: MediaQuery.of(context).size.height * 0.22,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: const Color(0xFFC8A53C).withValues(alpha: 0.6),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            _buildCornerBracket(Alignment.topLeft),
            _buildCornerBracket(Alignment.topRight),
            _buildCornerBracket(Alignment.bottomLeft),
            _buildCornerBracket(Alignment.bottomRight),
          ],
        ),
      ),
    );
  }

  Widget _buildCornerBracket(Alignment alignment) {
    final isLeft = alignment.x < 0;
    final isTop = alignment.y < 0;

    return Align(
      alignment: alignment,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          border: Border(
            top: isTop
                ? const BorderSide(color: Color(0xFFC8A53C), width: 3)
                : BorderSide.none,
            bottom: !isTop
                ? const BorderSide(color: Color(0xFFC8A53C), width: 3)
                : BorderSide.none,
            left: isLeft
                ? const BorderSide(color: Color(0xFFC8A53C), width: 3)
                : BorderSide.none,
            right: !isLeft
                ? const BorderSide(color: Color(0xFFC8A53C), width: 3)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}
