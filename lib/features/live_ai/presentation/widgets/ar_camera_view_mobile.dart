/// Mobile implementation of ARCameraView using native ARKit/ARCore via platform channels.
/// Provides real AR with plane detection, wall tracking, and spatial measurement.
library;

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart' hide Colors;
import 'package:flutter/services.dart' show rootBundle, HapticFeedback;
import 'package:permission_handler/permission_handler.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'package:grazia_stones/core/services/ar_native_channel.dart';

import 'package:flutter/material.dart' as material;

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

  // Static control API - delegates to native channel
  static final _controller = StreamController<_ARUpdate>.broadcast();

  static void updateStone(String? assetPath, double opacity) {
    _controller.add(_ARUpdate(stone: assetPath, opacity: opacity));
    if (assetPath != null) {
      _loadAndSendTexture(assetPath, opacity);
    }
  }

  static Future<void> _loadAndSendTexture(String assetPath, double opacity) async {
    try {
      final ByteData data = await rootBundle.load(assetPath);
      final Uint8List bytes = data.buffer.asUint8List();
      await ARNativeChannel.setTexture(bytes);
    } catch (e) {
      debugPrint('[ARCameraView] Failed to load texture: $e');
    }
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

  static void startRecording() {
    // TODO: Implement native recording
  }

  static void stopRecording() {
    // TODO: Implement native recording
  }

  static Map<String, Offset>? getWallCorners() => null;

  static void setManualCorner(String name, Offset value) {}
  static void clearManualCorners() {}

  static Future<String?> renderStaticVisualization(
      String roomImageDataUrl, String textureDataUrl, double opacity) async => null;

  // Enhanced API - delegates to native
  static Future<List<Map<String, dynamic>>?> getWalls() async {
    return await ARNativeChannel.getWalls();
  }

  static Future<void> selectWall(String wallId) async {
    await ARNativeChannel.selectWall(wallId);
  }

  static Future<void> startCalibration({String unit = 'ft'}) async {
    await ARNativeChannel.startCalibration(unit: unit);
  }

  static Future<bool> finishCalibration(double realLength) async {
    return await ARNativeChannel.finishCalibration(realLength);
  }

  static Future<Map<String, dynamic>?> getCalibration() async {
    return await ARNativeChannel.getCalibration();
  }

  static Future<double?> measureDistance(Offset p1, Offset p2) async {
    return await ARNativeChannel.measureDistance(p1, p2);
  }

  static Future<Map<String, dynamic>?> calculateTileQuantity({
    required double tileWidth,
    required double tileHeight,
    String tileUnit = 'ft',
    double wastagePercent = 10.0,
  }) async {
    return await ARNativeChannel.calculateTileQuantity(
      tileWidth: tileWidth,
      tileHeight: tileHeight,
      tileUnit: tileUnit,
      wastagePercent: wastagePercent,
    );
  }

  static void requestSegmentation() {}

  static void setTileDimensions(double width, double height, String unit) {}

  static Future<String> getWallState() async {
    return await ARNativeChannel.getWallState();
  }

  static Future<void> preloadTexture(String textureUrl) async {
    await ARNativeChannel.preloadTexture(textureUrl);
  }

  static Future<void> preloadTextures(List<String> textureUrls) async {
    for (final url in textureUrls) {
      await ARNativeChannel.preloadTexture(url);
    }
  }

  static void stopCamera() {
    _controller.add(_ARUpdate(stop: true));
    ARNativeChannel.pauseSession();
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

class _ARCameraViewState extends State<ARCameraView> with WidgetsBindingObserver {
  bool _isInitialized = false;
  bool _isPermissionDenied = false;
  String? _error;
  bool _nativeARStarted = false;

  String? _displayStoneTexture;
  double _displayOpacity = 0.72;
  double _displayScale = 1.0;
  Offset _displayPosition = Offset.zero;
  double _displayRotation = 0.0;
  bool _showWallBracket = false;

  StreamSubscription? _updateSubscription;
  StreamSubscription? _wallDetectedSubscription;
  StreamSubscription? _wallUpdatedSubscription;
  StreamSubscription? _wallRemovedSubscription;
  StreamSubscription? _trackingStateSubscription;
  StreamSubscription? _wallStateSubscription;
  StreamSubscription? _measurementResultSubscription;
  StreamSubscription? _errorSubscription;

  List<Map<String, dynamic>> _detectedWalls = [];
  String _wallState = 'SEARCHING';
  String? _selectedWallId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _displayStoneTexture = widget.stoneImagePath;
    _displayOpacity = widget.opacity;
    _displayScale = widget.scale;
    _displayPosition = widget.position;
    _displayRotation = widget.rotation;
    
    _initializeNativeAR();
    _listenToStaticUpdates();
    _listenToNativeEvents();
  }

  Future<void> _initializeNativeAR() async {
    try {
      final status = await Permission.camera.request().timeout(
        const Duration(seconds: 4),
        onTimeout: () => PermissionStatus.denied,
      );

      if (!status.isGranted) {
        if (mounted) {
          setState(() {
            _isPermissionDenied = true;
            _error = 'Camera permission required for AR (Simulator / Camera unavailable)';
          });
          widget.onError?.call();
        }
        return;
      }

      final supported = await ARNativeChannel.isARSupported().timeout(
        const Duration(seconds: 3),
        onTimeout: () => false,
      );

      if (!supported) {
        if (mounted) {
          setState(() => _error = 'AR requires physical hardware (iOS Simulator detected)');
          widget.onError?.call();
        }
        return;
      }

      // Initialize native AR channel
      await ARNativeChannel.initialize();
      
      // Start AR session
      await ARNativeChannel.startSession();
      _nativeARStarted = true;

      if (mounted) {
        setState(() => _isInitialized = true);
        widget.onReady?.call();
      }

      // Load initial texture
      if (_displayStoneTexture != null) {
        await _loadAndSendTexture(_displayStoneTexture!);
      }

    } catch (e) {
      if (mounted) {
        setState(() => _error = 'AR Camera unavailable on Simulator: $e');
        widget.onError?.call();
      }
    }
  }

  Future<void> _loadAndSendTexture(String assetPath) async {
    try {
      final ByteData data = await rootBundle.load(assetPath);
      final Uint8List bytes = data.buffer.asUint8List();
      await ARNativeChannel.setTexture(bytes);
    } catch (e) {
      debugPrint('[ARCameraView] Failed to load texture: $e');
    }
  }

  void _listenToStaticUpdates() {
    _updateSubscription = ARCameraView._controller.stream.listen((update) {
      if (!mounted) return;
      setState(() {
        if (update.stone != null) {
          _displayStoneTexture = update.stone;
          if (update.stone != null) {
            _loadAndSendTexture(update.stone!);
          }
        }
        if (update.opacity != null) _displayOpacity = update.opacity!;
        if (update.scale != null) _displayScale = update.scale!;
        if (update.position != null) _displayPosition = update.position!;
        if (update.rotation != null) _displayRotation = update.rotation!;
        if (update.showBoundary != null) _showWallBracket = update.showBoundary!;
        if (update.stop == true) _stopNativeAR();
      });
    });
  }

  void _listenToNativeEvents() {
    _wallDetectedSubscription = ARNativeChannel.onWallDetected.listen((wallData) {
      if (!mounted) return;
      final id = wallData['id'] as String?;
      if (id != null) {
        final wasEmpty = _detectedWalls.isEmpty;
        setState(() {
          _detectedWalls.add(wallData);
          if (_selectedWallId == null) {
            _selectedWallId = id;
          }
        });
        if (wasEmpty) HapticFeedback.mediumImpact(); // first wall lock
      }
    });

    _wallUpdatedSubscription = ARNativeChannel.onWallUpdated.listen((wallData) {
      if (!mounted) return;
      final id = wallData['id'] as String?;
      if (id != null) {
        setState(() {
          _detectedWalls = _detectedWalls.map((w) => w['id'] == id ? wallData : w).toList();
        });
      }
    });

    _wallRemovedSubscription = ARNativeChannel.onWallRemoved.listen((wallId) {
      if (!mounted) return;
      setState(() {
        _detectedWalls.removeWhere((w) => w['id'] == wallId);
        if (_selectedWallId == wallId) {
          _selectedWallId = _detectedWalls.isNotEmpty ? _detectedWalls.first['id'] as String? : null;
        }
      });
    });

    _trackingStateSubscription = ARNativeChannel.onTrackingStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _wallState = state);
    });

    _wallStateSubscription = ARNativeChannel.onWallStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _wallState = state);
    });

    _measurementResultSubscription = ARNativeChannel.onMeasurementResult.listen((data) {
      if (!mounted) return;
      // Handle measurement results if needed
      debugPrint('[ARCameraView] Measurement result: $data');
    });

    _errorSubscription = ARNativeChannel.onError.listen((error) {
      if (!mounted) return;
      setState(() => _error = error);
      widget.onError?.call();
    });
  }

  void _stopNativeAR() {
    ARNativeChannel.pauseSession();
    _nativeARStarted = false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updateSubscription?.cancel();
    _wallDetectedSubscription?.cancel();
    _wallUpdatedSubscription?.cancel();
    _wallRemovedSubscription?.cancel();
    _trackingStateSubscription?.cancel();
    _wallStateSubscription?.cancel();
    _measurementResultSubscription?.cancel();
    _errorSubscription?.cancel();
    
    if (_nativeARStarted) {
      ARNativeChannel.stopCamera();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      if (_nativeARStarted) {
        ARNativeChannel.pauseSession();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_nativeARStarted) {
        ARNativeChannel.resumeSession();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isPermissionDenied) return _buildPermissionDenied();
    if (_error != null) return _buildErrorState();
    if (!_isInitialized) {
      return _buildLoadingState();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Native AR view
        ARNativeChannel.getARView(),
        
        // Wall state overlay
        _buildWallStateOverlay(),
        
        // Wall boundary bracket (if showing)
        if (_showWallBracket && _selectedWallId != null) _buildWallBracket(),
        
        // Stone texture preview (small corner preview)
        if (_displayStoneTexture != null) _buildTexturePreview(),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Container(
      color: material.Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFFC8A53C)),
            const SizedBox(height: 16),
            Text(
              'Initializing AR...',
              style: TextStyle(
                color: material.Colors.white.withValues(alpha: 0.8),
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Detecting walls and surfaces...',
              style: TextStyle(
                color: material.Colors.white.withValues(alpha: 0.5),
                fontFamily: 'Inter',
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWallStateOverlay() {
    String label;
    IconData icon;
    Color stateColor;

    switch (_wallState) {
      case 'SEARCHING':
        label = 'Point camera at a wall';
        icon = Icons.crop_free_rounded;
        stateColor = const Color(0xFFD4AF37);
        break;
      case 'DETECTING':
        label = 'Detecting wall...';
        icon = Icons.auto_awesome_rounded;
        stateColor = const Color(0xFFD4AF37);
        break;
      case 'LOCKED':
      case 'TRACKING':
        label = 'Wall detected';
        icon = Icons.check_circle_rounded;
        stateColor = const Color(0xFF4CAF50);
        break;
      case 'LIMITED_INSUFFICIENT_FEATURES':
        label = 'Move closer to a textured wall';
        icon = Icons.zoom_in_rounded;
        stateColor = const Color(0xFFFFB74D);
        break;
      case 'LIMITED_EXCESSIVE_MOTION':
        label = 'Hold device steady';
        icon = Icons.motion_photos_pause_rounded;
        stateColor = const Color(0xFFFFB74D);
        break;
      case 'PAUSED':
      case 'STOPPED':
        label = 'AR paused';
        icon = Icons.pause_circle_rounded;
        stateColor = const Color(0xFFE57373);
        break;
      case 'LOST':
        label = 'Wall lost — point back at wall';
        icon = Icons.error_outline_rounded;
        stateColor = const Color(0xFFE57373);
        break;
      default:
        label = 'Initializing AR...';
        icon = Icons.crop_free_rounded;
        stateColor = const Color(0xFFD4AF37);
    }

    return Positioned(
      top: MediaQuery.of(context).padding.top + 72,
      left: 0,
      right: 0,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: material.Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: stateColor.withValues(alpha: 0.6), width: 1.0),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: stateColor, size: 15),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: stateColor == const Color(0xFF4CAF50) ? material.Colors.white : stateColor,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWallBracket() {
    // This is drawn by native AR - we don't need to draw it in Flutter
    return const SizedBox.shrink();
  }

  Widget _buildTexturePreview() {
    final texturePath = _displayStoneTexture;
    if (texturePath == null || texturePath.isEmpty) return const SizedBox.shrink();

    final isNetwork = texturePath.startsWith('http://') || texturePath.startsWith('https://');

    return Positioned(
      top: MediaQuery.of(context).padding.top + 120,
      right: 16,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: material.Colors.white.withValues(alpha: 0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: material.Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: isNetwork
              ? Image.network(texturePath, fit: BoxFit.cover)
              : Image.asset(texturePath, fit: BoxFit.cover),
        ),
      ),
    );
  }

  Widget _buildPermissionDenied() {
    return Container(
      color: material.Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.camera_alt_outlined, color: material.Colors.white.withValues(alpha: 0.5), size: 48),
            const SizedBox(height: 16),
            Text(
              'Camera permission denied',
              style: TextStyle(
                color: material.Colors.white.withValues(alpha: 0.8),
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enable in Settings to use AR',
              style: TextStyle(
                color: material.Colors.white.withValues(alpha: 0.5),
                fontFamily: 'Inter',
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => openAppSettings(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC8A53C),
                foregroundColor: material.Colors.black,
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
      color: material.Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: material.Colors.red.withValues(alpha: 0.8), size: 48),
              const SizedBox(height: 16),
              Text(
                _error ?? 'Unknown error',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: material.Colors.white.withValues(alpha: 0.8),
                  fontFamily: 'Inter',
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _error = null;
                        _isPermissionDenied = false;
                        _isInitialized = true;
                      });
                      widget.onReady?.call();
                    },
                    icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
                    label: const Text('Simulator Preview Mode', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFC8A53C),
                      side: const BorderSide(color: Color(0xFFC8A53C)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _error = null;
                        _isPermissionDenied = false;
                        _isInitialized = false;
                      });
                      _initializeNativeAR();
                    },
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Retry', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC8A53C),
                      foregroundColor: material.Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}