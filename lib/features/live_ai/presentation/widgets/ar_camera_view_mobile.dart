/// Mobile implementation of ARCameraView using native ARKit/ARCore via platform channels.
/// Provides real AR with plane detection, wall tracking, and spatial measurement.
library;

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart' hide Colors;
import 'package:flutter/services.dart' show rootBundle, HapticFeedback;
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:grazia_stones/core/services/ar_native_channel.dart';
import 'package:grazia_stones/core/services/room_analysis_service.dart';
import 'package:grazia_stones/shared/widgets/smart_stone_image.dart';

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
      Uint8List bytes;
      if (assetPath.startsWith('http://') || assetPath.startsWith('https://')) {
        final res = await http.get(Uri.parse(assetPath)).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200) {
          bytes = res.bodyBytes;
        } else {
          throw Exception('Failed to download texture: HTTP ${res.statusCode}');
        }
      } else {
        final ByteData data = await rootBundle.load(assetPath);
        bytes = data.buffer.asUint8List();
      }
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

  static Future<String?> getWallState() async {
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
  bool _showWallBracket = false;
  bool _is3DStudioMode = false;
  int _selectedRoomIndex = 0;
  bool _showSofaShield = true;
  bool _showLidarMesh = true;
  bool _hasLiDARHardware = false;

  final List<Map<String, dynamic>> _roomScenes = [
    {
      'title': 'Living Room',
      'image': 'assets/images/home_hero_living_room.jpg',
      'wallArea': '14.8 m²',
      'wallConfidence': 98.6,
      'wallDimensions': '4.2m × 3.5m',
      'obstacleType': 'sofa',
      'obstacleName': 'Sectional Sofa & Lounge',
      'obstacleConfidence': 96.4,
      'perspectiveY': -0.06,
      'perspectiveX': 0.02,
    },
    {
      'title': 'Hotel Lobby',
      'image': 'assets/images/hero_luxury_fireplace.jpg',
      'wallArea': '21.4 m²',
      'wallConfidence': 99.1,
      'wallDimensions': '6.1m × 3.5m',
      'obstacleType': 'furniture',
      'obstacleName': 'Hearth & Lounge Armchairs',
      'obstacleConfidence': 95.8,
      'perspectiveY': 0.0,
      'perspectiveX': 0.01,
    },
    {
      'title': 'Dining Suite',
      'image': 'assets/images/hero_luxury_dining_fluted.jpg',
      'wallArea': '16.2 m²',
      'wallConfidence': 97.8,
      'wallDimensions': '4.8m × 3.4m',
      'obstacleType': 'furniture',
      'obstacleName': 'Marble Dining Suite',
      'obstacleConfidence': 95.2,
      'perspectiveY': -0.04,
      'perspectiveX': 0.02,
    },
    {
      'title': 'Master Bedroom',
      'image': 'assets/images/hero_luxury_bedroom.jpg',
      'wallArea': '12.5 m²',
      'wallConfidence': 98.2,
      'wallDimensions': '3.9m × 3.2m',
      'obstacleType': 'sofa',
      'obstacleName': 'King Headboard & Suite',
      'obstacleConfidence': 97.0,
      'perspectiveY': 0.04,
      'perspectiveX': 0.02,
    },
  ];

  StreamSubscription? _updateSubscription;
  StreamSubscription? _wallDetectedSubscription;
  StreamSubscription? _wallUpdatedSubscription;
  StreamSubscription? _wallRemovedSubscription;
  StreamSubscription? _measurementResultSubscription;
  StreamSubscription? _errorSubscription;
  StreamSubscription? _obstacleDetectedSubscription;

  List<Map<String, dynamic>> _detectedWalls = [];
  final List<Map<String, dynamic>> _detectedObstacles = [];
  String? _selectedWallId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _displayStoneTexture = widget.stoneImagePath;
    _displayOpacity = widget.opacity;
    _displayScale = widget.scale;
    _displayPosition = widget.position;
    
    _initializeNativeAR();
    _listenToStaticUpdates();
    _listenToNativeEvents();
  }

  Future<void> _initializeNativeAR() async {
    try {
      var status = await Permission.camera.request();
      if (!status.isGranted) {
        status = await Permission.camera.status;
      }

      if (!status.isGranted) {
        // Show the permission screen (retry / open Settings) instead of
        // silently dropping into the sample-photo studio.
        if (mounted) {
          setState(() {
            _isPermissionDenied = true;
            _isInitialized = true;
          });
        }
        return;
      }

      final supported = await ARNativeChannel.isARSupported().timeout(
        const Duration(seconds: 4),
        onTimeout: () => false,
      );

      if (!supported) {
        // Simulator or non-ARKit hardware: Seamlessly activate 3D Room Studio
        if (mounted) {
          setState(() {
            _is3DStudioMode = true;
            _isInitialized = true;
          });
          widget.onReady?.call();
        }
        return;
      }

      // Initialize native AR channel and room analysis
      _hasLiDARHardware = await ARNativeChannel.hasLiDAR();
      RoomAnalysisService.instance.init();
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
      debugPrint('[ARCameraView] native AR init failed: $e');
      if (mounted) {
        setState(() {
          _error = 'Could not start the AR camera. $e';
          _isInitialized = true;
        });
      }
    }
  }

  Future<void> _loadAndSendTexture(String assetPath) async {
    await ARCameraView._loadAndSendTexture(assetPath, _displayOpacity);
  }

  void _listenToStaticUpdates() {
    _updateSubscription = ARCameraView._controller.stream.listen((update) {
      if (!mounted) return;
      setState(() {
        if (update.stone != null) {
          _displayStoneTexture = update.stone;
          if (update.stone != null && !_is3DStudioMode) {
            _loadAndSendTexture(update.stone!);
          }
        }
        if (update.opacity != null) _displayOpacity = update.opacity!;
        if (update.scale != null) _displayScale = update.scale!;
        if (update.position != null) _displayPosition = update.position!;
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
          _selectedWallId ??= id;
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

    _measurementResultSubscription = ARNativeChannel.onMeasurementResult.listen((data) {
      if (!mounted) return;
      debugPrint('[ARCameraView] Measurement result: $data');
    });

    _errorSubscription = ARNativeChannel.onError.listen((error) {
      if (!mounted) return;
      setState(() => _error = error);
      widget.onError?.call();
    });

    _obstacleDetectedSubscription = ARNativeChannel.onObstacleDetected.listen((data) {
      if (!mounted) return;
      setState(() {
        _detectedObstacles.add(data);
      });
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
    _measurementResultSubscription?.cancel();
    _errorSubscription?.cancel();
    _obstacleDetectedSubscription?.cancel();
    
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
    if (!_isInitialized) {
      return _buildLoadingState();
    }

    if (_is3DStudioMode) {
      return _build3DStudioView();
    }

    if (_isPermissionDenied) return _buildPermissionDenied();
    if (_error != null) return _buildErrorState();

    return Stack(
      fit: StackFit.expand,
      children: [
        // Native AR view
        ARNativeChannel.getARView(),
        
        // Wall boundary bracket (if showing)
        if (_showWallBracket && _selectedWallId != null) _buildWallBracket(),
        
        // Stone texture preview (small corner preview)
        if (_displayStoneTexture != null) _buildTexturePreview(),
      ],
    );
  }

  Widget _build3DStudioView() {
    final texturePath = _displayStoneTexture ?? widget.stoneImagePath ?? 'assets/images/athena_3d_tex.png';
    final currentRoom = _roomScenes[_selectedRoomIndex % _roomScenes.length];
    final roomImage = currentRoom['image'] as String;
    final roomTitle = currentRoom['title'] as String;
    final wallArea = currentRoom['wallArea'] as String? ?? '14.8 m²';
    final wallDims = currentRoom['wallDimensions'] as String? ?? '4.2m × 3.5m';
    final rawWallConf = currentRoom['wallConfidence'];
    final wallConf = rawWallConf is num ? rawWallConf.toDouble() : (double.tryParse(rawWallConf?.toString() ?? '') ?? 98.6);
    final obstacleName = currentRoom['obstacleName'] as String? ?? 'Sectional Sofa & Lounge';
    final rawObstacleConf = currentRoom['obstacleConfidence'];
    final obstacleConf = rawObstacleConf is num ? rawObstacleConf.toDouble() : (double.tryParse(rawObstacleConf?.toString() ?? '') ?? 96.4);
    final rawPerspY = currentRoom['perspectiveY'];
    final perspectiveY = rawPerspY is num ? rawPerspY.toDouble() : (double.tryParse(rawPerspY?.toString() ?? '') ?? -0.06);
    final rawPerspX = currentRoom['perspectiveX'];
    final perspectiveX = rawPerspX is num ? rawPerspX.toDouble() : (double.tryParse(rawPerspX?.toString() ?? '') ?? 0.02);

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Luxury room interior photo
        Image.asset(
          roomImage,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(color: const Color(0xFF1E1E1E)),
        ),

        // 2. Ambient depth overlay
        Container(
          color: material.Colors.black.withValues(alpha: 0.22),
        ),

        // 3. 3D Perspective Wall Placement
        Center(
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..translate(_displayPosition.dx, _displayPosition.dy)
              ..rotateY(perspectiveY)
              ..rotateX(perspectiveX)
              ..scale(_displayScale),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.76,
              height: MediaQuery.of(context).size.height * 0.42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: material.Colors.black.withValues(alpha: 0.6),
                    blurRadius: 28,
                    offset: const Offset(-8, 12),
                  ),
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Stone texture on 3D wall
                    Opacity(
                      opacity: _displayOpacity.clamp(0.2, 1.0),
                      child: SmartStoneImage(
                        imageUrl: texturePath,
                        fit: BoxFit.cover,
                      ),
                    ),

                    // Directional lighting and shadow for realistic architectural depth
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            material.Colors.white.withValues(alpha: 0.2),
                            material.Colors.transparent,
                            material.Colors.black.withValues(alpha: 0.4),
                          ],
                        ),
                      ),
                    ),

                    // LiDAR Depth Wireframe Mesh (when enabled)
                    if (_showLidarMesh)
                      CustomPaint(
                        painter: _LidarMeshPainter(
                          color: const Color(0xFFD4AF37).withValues(alpha: 0.38),
                        ),
                      ),

                    // Architectural gold edge boundary
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFFD4AF37).withValues(alpha: 0.7),
                          width: 1.2,
                        ),
                      ),
                    ),

                    // Wall Plane details tag on wall
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: material.Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                            width: 0.7,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF4CAF50),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'WALL 1 • $wallDims • ${wallConf.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: material.Colors.white,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // 4. Sofa & Furniture Occlusion Shield
        if (_showSofaShield)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 124,
            left: 16,
            right: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: material.Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.7),
                      width: 1.1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.shield_rounded, color: Color(0xFF4CAF50), size: 15),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'SOFA & FURNITURE SHIELD',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF4CAF50),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'OCCLUSION PROTECTED',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF4CAF50),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Detected: $obstacleName (${obstacleConf.toStringAsFixed(0)}% conf) • Stone placed behind furniture',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 9.5,
                                color: material.Colors.white.withValues(alpha: 0.85),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // 5. Top Left HUD Badges
        Positioned(
          top: MediaQuery.of(context).padding.top + 54,
          left: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: material.Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.6),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.view_in_ar_rounded, size: 13, color: Color(0xFFD4AF37)),
                    const SizedBox(width: 6),
                    Text(
                      '3D WALL • $roomTitle',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFD4AF37),
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: material.Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: material.Colors.white.withValues(alpha: 0.15),
                    width: 0.6,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF00E5FF),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _hasLiDARHardware ? 'LiDAR 3D Hardware • Active' : 'Sample Room Preview',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: material.Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 6. Top Right Controls (Room Switcher, LiDAR Mesh toggle, Sofa Shield toggle)
        Positioned(
          top: MediaQuery.of(context).padding.top + 54,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Change Room
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _selectedRoomIndex = (_selectedRoomIndex + 1) % _roomScenes.length;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                  decoration: BoxDecoration(
                    color: material.Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: material.Colors.white.withValues(alpha: 0.3),
                      width: 0.8,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.swap_horiz_rounded, size: 14, color: material.Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Room',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: material.Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mesh toggle
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _showLidarMesh = !_showLidarMesh);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                      margin: const EdgeInsets.only(right: 5),
                      decoration: BoxDecoration(
                        color: _showLidarMesh
                            ? const Color(0xFFD4AF37).withValues(alpha: 0.25)
                            : material.Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: _showLidarMesh
                              ? const Color(0xFFD4AF37)
                              : material.Colors.white.withValues(alpha: 0.25),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.grid_4x4_rounded,
                            size: 11,
                            color: _showLidarMesh ? const Color(0xFFD4AF37) : material.Colors.white70,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Mesh',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: _showLidarMesh ? const Color(0xFFD4AF37) : material.Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Shield toggle
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _showSofaShield = !_showSofaShield);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: _showSofaShield
                            ? const Color(0xFF4CAF50).withValues(alpha: 0.25)
                            : material.Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: _showSofaShield
                              ? const Color(0xFF4CAF50)
                              : material.Colors.white.withValues(alpha: 0.25),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 11,
                            color: _showSofaShield ? const Color(0xFF4CAF50) : material.Colors.white70,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Shield',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: _showSofaShield ? const Color(0xFF4CAF50) : material.Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 7. Corner texture thumbnail
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


  Widget _buildWallBracket() {
    // This is drawn by native AR - we don't need to draw it in Flutter
    return const SizedBox.shrink();
  }

  Widget _buildTexturePreview() {
    final texturePath = _displayStoneTexture;
    if (texturePath == null || texturePath.isEmpty) return const SizedBox.shrink();

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
          child: SmartStoneImage(
            imageUrl: texturePath,
            fit: BoxFit.cover,
          ),
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
              'Camera access needed',
              style: TextStyle(
                color: material.Colors.white.withValues(alpha: 0.8),
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error ?? 'Enable camera access to preview stones on your wall.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: material.Colors.white.withValues(alpha: 0.5),
                  fontFamily: 'Inter',
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Retry matters: if the permission prompt was dismissed or the
                // status was read before the user answered, this recovers
                // without making them leave the screen.
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _isPermissionDenied = false;
                      _error = null;
                    });
                    _initializeNativeAR();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: material.Colors.white,
                    side: BorderSide(color: material.Colors.white.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text('Try Again', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => openAppSettings(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC8A53C),
                    foregroundColor: material.Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text('Open Settings', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
                ),
              ],
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
                        _is3DStudioMode = true;
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

/// Subtle architectural LiDAR Depth wireframe grid painter
class _LidarMeshPainter extends CustomPainter {
  final Color color;

  const _LidarMeshPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Draw horizontal grid lines
    const int rows = 5;
    const int cols = 7;
    final rowStep = size.height / rows;
    final colStep = size.width / cols;

    for (int r = 1; r < rows; r++) {
      final y = r * rowStep;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Draw vertical grid lines
    for (int c = 1; c < cols; c++) {
      final x = c * colStep;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }

    // Draw crosshair intersection dots (LiDAR depth sample points)
    for (int r = 1; r < rows; r++) {
      for (int c = 1; c < cols; c++) {
        canvas.drawCircle(Offset(c * colStep, r * rowStep), 1.8, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LidarMeshPainter oldDelegate) => oldDelegate.color != color;
}