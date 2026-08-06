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
  static String? _currentStoneTexture;
  static double _currentOpacity = 0.72;
  static double _currentScale = 1.0;
  static Offset _currentPosition = Offset.zero;
  static double _currentRotation = 0.0;
  static bool _showBoundary = false;
  static final _controller = StreamController<_ARUpdate>.broadcast();

  static void updateStone(String? assetPath, double opacity) {
    _currentStoneTexture = assetPath;
    _currentOpacity = opacity;
    _controller.add(_ARUpdate(stone: assetPath, opacity: opacity));
  }

  static void updateOpacity(double opacity) {
    _currentOpacity = opacity;
    _controller.add(_ARUpdate(opacity: opacity));
  }

  static void updateScale(double scale) {
    _currentScale = scale;
    _controller.add(_ARUpdate(scale: scale));
  }

  static void updatePosition(Offset position) {
    _currentPosition = position;
    _controller.add(_ARUpdate(position: position));
  }

  static void updateRotation(double rotation) {
    _currentRotation = rotation;
    _controller.add(_ARUpdate(rotation: rotation));
  }

  static void showWallBoundary(bool show) {
    _showBoundary = show;
    _controller.add(_ARUpdate(showBoundary: show));
  }

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
  List<CameraDescription>? _cameras;

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
      // Request camera permission
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        setState(() {
          _isPermissionDenied = true;
          _error = 'Camera permission is required';
        });
        widget.onError?.call();
        return;
      }

      // Get available cameras
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() {
          _error = 'No cameras available on this device';
        });
        widget.onError?.call();
        return;
      }

      // Find back camera (environment)
      CameraDescription? backCamera;
      for (final camera in _cameras!) {
        if (camera.lensDirection == CameraLensDirection.back) {
          backCamera = camera;
          break;
        }
      }

      // Fallback to first camera if no back camera
      final selectedCamera = backCamera ?? _cameras!.first;

      // Initialize camera controller
      _controller = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _controller!.initialize();

      if (!mounted) return;

      setState(() {
        _isInitialized = true;
        _error = null;
      });

      widget.onReady?.call();

      // Apply initial stone texture if provided
      if (_displayStoneTexture != null) {
        ARCameraView.updateStone(_displayStoneTexture, _displayOpacity);
      }
      ARCameraView.showWallBoundary(true);
    } catch (e) {
      setState(() {
        _error = 'Camera initialization failed: ${e.toString()}';
      });
      widget.onError?.call();
    }
  }

  void _disposeCamera() {
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  @override
  void didUpdateWidget(ARCameraView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stoneImagePath != widget.stoneImagePath ||
        oldWidget.opacity != widget.opacity ||
        oldWidget.scale != widget.scale ||
        oldWidget.position != widget.position ||
        oldWidget.rotation != widget.rotation) {
      setState(() {
        _displayStoneTexture = widget.stoneImagePath;
        _displayOpacity = widget.opacity;
        _displayScale = widget.scale;
        _displayPosition = widget.position;
        _displayRotation = widget.rotation;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updateSubscription?.cancel();
    _disposeCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Error state
    if (_error != null) {
      return _buildErrorState();
    }

    // Permission denied
    if (_isPermissionDenied) {
      return _buildPermissionDenied();
    }

    // Loading state
    if (!_isInitialized || _controller == null) {
      return _buildLoadingState();
    }

    // Camera view with overlay
    return Stack(
      fit: StackFit.expand,
      children: [
        // Real camera feed
        ClipRect(
          child: OverflowBox(
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.previewSize!.height,
                height: _controller!.value.previewSize!.width,
                child: CameraPreview(_controller!),
              ),
            ),
          ),
        ),

        // Stone texture overlay with realistic blending + interactive transforms
        // 80% opacity + multiply blend + edge feathering + scale + position + rotation
        if (_displayStoneTexture != null)
          Positioned.fill(
            child: Transform.translate(
              offset: _displayPosition,
              child: Transform.rotate(
                angle: _displayRotation,
                child: Transform.scale(
                  scale: _displayScale,
                  child: Opacity(
                    opacity: _displayOpacity,
                    child: Container(
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage(_displayStoneTexture!),
                          repeat: ImageRepeat.repeat,
                          scale: 2.5 / _displayScale, // Adjust tile size based on scale
                        ),
                      ),
                      // Multiply blend mode preserves shadows and lighting
                      foregroundDecoration: BoxDecoration(
                        color: Colors.transparent,
                        backgroundBlendMode: BlendMode.multiply,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Edge feathering gradient (2-4px soft edges)
        if (_displayStoneTexture != null)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.12),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.12),
                    ],
                    stops: const [0.0, 0.06, 0.94, 1.0],
                  ),
                ),
              ),
            ),
          ),

        // Subtle vignette for depth
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.85,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.20),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Wall detection bracket
        if (_showWallBracket) _buildWallBracket(),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFFC8A53C),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Initializing Camera…',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Please allow camera access if prompted',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionDenied() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFC8A53C).withValues(alpha: 0.15),
                  border: Border.all(
                    color: const Color(0xFFC8A53C).withValues(alpha: 0.4),
                  ),
                ),
                child: const Icon(
                  Icons.videocam_off_rounded,
                  color: Color(0xFFC8A53C),
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Camera Permission Required',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'To use Live AR, please grant camera permissions in your device settings.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                  height: 1.5,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () async {
                  await openAppSettings();
                },
                icon: const Icon(Icons.settings, size: 20),
                label: const Text(
                  'Open Settings',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC8A53C),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
              ),
            ],
          ),
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
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 64,
              ),
              const SizedBox(height: 24),
              const Text(
                'Camera Error',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _error ?? 'An unknown error occurred',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                  height: 1.5,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _error = null;
                    _isPermissionDenied = false;
                  });
                  _initializeCamera();
                },
                icon: const Icon(Icons.refresh, size: 20),
                label: const Text(
                  'Retry',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC8A53C),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
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
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Color.lerp(
                    Colors.transparent,
                    const Color(0xFFC8A53C),
                    value,
                  )!,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFC8A53C).withValues(alpha: 0.1 * value),
                    blurRadius: 40,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Corner brackets
                  _buildCornerBracket(Alignment.topLeft),
                  _buildCornerBracket(Alignment.topRight),
                  _buildCornerBracket(Alignment.bottomLeft),
                  _buildCornerBracket(Alignment.bottomRight),
                ],
              ),
            ),
          );
        },
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
                ? const BorderSide(
                    color: Color(0xFFC8A53C),
                    width: 3,
                  )
                : BorderSide.none,
            bottom: !isTop
                ? const BorderSide(
                    color: Color(0xFFC8A53C),
                    width: 3,
                  )
                : BorderSide.none,
            left: isLeft
                ? const BorderSide(
                    color: Color(0xFFC8A53C),
                    width: 3,
                  )
                : BorderSide.none,
            right: !isLeft
                ? const BorderSide(
                    color: Color(0xFFC8A53C),
                    width: 3,
                  )
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}
