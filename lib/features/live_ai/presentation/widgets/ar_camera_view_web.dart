/// Web implementation of ARCameraView.
/// Uses dart:html + dart:js to bridge to the GraziaAR JavaScript engine.
// ignore_for_file: avoid_web_libraries_in_flutter
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

@JS('eval')
external JSAny _jsEvalRaw(String expr);

// ── Platform view registration ──────────────────────────────────────────────

// Each ARCameraView instance gets its own view type + container id.
// The old shared hardcoded id let a second concurrently-mounted instance
// (e.g. AI Viz's "Live Camera" tab, mounted on top of the Shell's Live AI
// tab) collide with the first — GraziaAR.init() could resolve to a stale or
// wrong container, leaving the new one blank/black.
int _instanceCounter = 0;

void _registerContainer(String id, String viewType) {
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final div = web.HTMLDivElement()
      ..id = id
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.overflow = 'hidden'
      ..style.background = '#000';
    return div;
  });
}

// ── Helper: call a JS expression safely ─────────────────────────────────────

dynamic _jsEval(String expr) {
  try {
    return _jsEvalRaw(expr);
  } catch (e) {
    if (kDebugMode) debugPrint('[GraziaAR] JS error: $e');
    return null;
  }
}

// ── Asset → data:image/png;base64 converter for JS texture loading ──────────

Future<String?> _assetToDataUrl(String assetPath) async {
  try {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();
    final base64Str = base64Encode(bytes);
    return 'data:image/png;base64,$base64Str';
  } catch (e) {
    if (kDebugMode) debugPrint('[GraziaAR] Failed to load asset "$assetPath": $e');
    return null;
  }
}

// ── Static texture cache (avoids reloading same texture) ────────────────────

final Map<String, String> _textureCache = {};

Future<void> _loadAndSetTexture(String assetPath, double opacity) async {
  if (_textureCache.containsKey(assetPath)) {
    final cached = _textureCache[assetPath]!;
    _jsEval('GraziaAR.setTexture("$cached")');
    _jsEval('GraziaAR.setOpacity($opacity)');
    return;
  }
  final dataUrl = await _assetToDataUrl(assetPath);
  if (dataUrl != null) {
    _textureCache[assetPath] = dataUrl;
    // JS-escape the data URL (contains + / = chars)
    final safeUrl = dataUrl.replaceAll("'", "\\'");
    _jsEval("GraziaAR.setTexture('$safeUrl')");
    _jsEval('GraziaAR.setOpacity($opacity)');
  }
}

// ── Widget ───────────────────────────────────────────────────────────────────

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

  // ── Static control API (callable from anywhere in the screen) ──

  static void updateStone(String? assetPath, double opacity) {
    if (assetPath == null) {
      _jsEval('GraziaAR.setTexture(null)');
      return;
    }
    // Async load: check cache first, then load from asset bundle
    _loadAndSetTexture(assetPath, opacity);
  }

  static void updateOpacity(double opacity) {
    _jsEval('GraziaAR.setOpacity($opacity)');
  }

  static void updateScale(double scale) {
    _jsEval('GraziaAR.setScale($scale)');
  }

  static void updatePosition(Offset position) {
    _jsEval('GraziaAR.setPosition(${position.dx}, ${position.dy})');
  }

  static void updateRotation(double rotation) {
    _jsEval('GraziaAR.setRotation($rotation)');
  }

  static void showWallBoundary(bool show) {
    _jsEval('GraziaAR.showWallBoundary($show)');
  }

  static void stopCamera() {
    _jsEval('GraziaAR.stopCamera()');
  }

  static void startRecording() {
    _jsEval('GraziaAR.startRecording()');
  }

  static void stopRecording() {
    _jsEval('GraziaAR.stopRecording()');
  }

  static Map<String, Offset>? getWallCorners() {
    final raw = _jsEval('GraziaAR.getWallCornersJson()');
    if (raw == null) return null;
    final decoded = jsonDecode(raw.toString()) as Map<String, dynamic>;
    return decoded.map(
      (key, value) => MapEntry(
        key,
        Offset((value['x'] as num).toDouble(), (value['y'] as num).toDouble()),
      ),
    );
  }

  static void setManualCorner(String name, Offset value) {
    _jsEval('GraziaAR.setManualCorner("$name", ${value.dx}, ${value.dy})');
  }

  static void clearManualCorners() {
    _jsEval('GraziaAR.clearManualCorners()');
  }

  /// Composites [textureDataUrl] onto the detected wall region of
  /// [roomImageDataUrl] only — returns the composited image as a data URL,
  /// or null if no wall could be confidently detected (caller should show
  /// the original photo unchanged rather than guessing).
  static Future<String?> renderStaticVisualization(
    String roomImageDataUrl,
    String textureDataUrl,
    double opacity,
  ) async {
    final safeRoom = roomImageDataUrl.replaceAll("'", "\\'");
    final safeTexture = textureDataUrl.replaceAll("'", "\\'");
    _jsEval(
      "GraziaAR.renderStaticVisualization('$safeRoom', '$safeTexture', $opacity)",
    );

    final startedAt = DateTime.now();
    while (DateTime.now().difference(startedAt) < const Duration(seconds: 20)) {
      await Future.delayed(const Duration(milliseconds: 200));
      final raw = _jsEval('_graziaARStaticResult');
      final err = _jsEval('_graziaARStaticError');
      if (raw != null) {
        final decoded = jsonDecode(raw.toString()) as Map<String, dynamic>;
        return decoded['success'] == true ? decoded['image'] as String : null;
      }
      if (err != null) return null;
    }
    return null;
  }

  // ── New Enhanced API ─────────────────────────────────────────────────────

/// Get all detected walls with their corners, confidence, and area
  static List<Map<String, dynamic>>? getWalls() {
    final raw = _jsEval('GraziaAR.getWalls()');
    if (raw == null) return null;
    final List<dynamic> decoded = jsonDecode(raw.toString()) as List<dynamic>;
    return decoded.cast<Map<String, dynamic>>();
  }
  
  /// Request pixel-level segmentation (SAM) for current frame
  static void requestSegmentation() {
    _jsEval('GraziaAR.requestSegmentation()');
  }
  
  /// Set tile dimensions for accurate pattern generation
  static void setTileDimensions(double width, double height, String unit) {
    _jsEval('GraziaAR.setTileDimensions($width, $height, "$unit")');
  }
  
  /// Get current calibration info
  static Map<String, dynamic>? getCalibration() {
    final raw = _jsEval('GraziaAR.getCalibration()');
    if (raw == null) return null;
    return jsonDecode(raw.toString()) as Map<String, dynamic>;
  }

  /// Select a specific wall by ID for texturing
  static bool selectWall(String wallId) {
    final raw = _jsEval('GraziaAR.selectWall("$wallId")');
    return raw == true;
  }

  /// Start calibration mode
  static void startCalibration({String unit = 'ft'}) {
    _jsEval('GraziaAR.startCalibration("$unit")');
  }

  /// Finish calibration with known real-world length
  static bool finishCalibration(double realLength) {
    final raw = _jsEval('GraziaAR.finishCalibration($realLength)');
    return raw == true;
  }

  /// Measure distance between two points (requires calibration)
  static double? measureDistance(Offset p1, Offset p2) {
    final raw = _jsEval('GraziaAR.measureDistance(${p1.dx}, ${p1.dy}, ${p2.dx}, ${p2.dy})');
    if (raw == null) return null;
    return (raw as num).toDouble();
  }

  /// Calculate tile quantity for the selected wall
  static Map<String, dynamic>? calculateTileQuantity({
    required double tileWidth,
    required double tileHeight,
    String tileUnit = 'ft',
    double wastagePercent = 10.0,
  }) {
    final raw = _jsEval(
      'GraziaAR.calculateTileQuantity($tileWidth, $tileHeight, "$tileUnit", $wastagePercent)'
    );
    if (raw == null) return null;
    return jsonDecode(raw.toString()) as Map<String, dynamic>;
  }

  @override
  State<ARCameraView> createState() => _ARCameraViewState();
}

class _ARCameraViewState extends State<ARCameraView>
    with SingleTickerProviderStateMixin {
  bool _cameraReady = false;
  bool _requiresTap = false;
  bool _containerReady = false;
  String? _errorMsg;
  Timer? _pollTimer;
  int _initAttempts = 0;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;
  late final String _containerId;
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _containerId = 'grazia-ar-container-${++_instanceCounter}';
    _viewType = 'grazia-ar-camera-v1-$_containerId';
    _registerContainer(_containerId, _viewType);
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _startInitSequence());
  }

  void _startInitSequence() {
    _initAttempts = 0;
    _tryInitContainerAndCamera();
  }

  void _tryInitContainerAndCamera() {
    _initAttempts++;
    final initResult = _jsEval('GraziaAR.init("$_containerId")');

    if (initResult == true) {
      // ponytail: skip the auto-start attempt entirely — iOS Safari requires
      // a gesture-fresh call to getUserMedia() anyway (see 7s-hang comment
      // that used to live in _startCameraStream), so an unprompted auto call
      // just wastes time with no visible feedback ("button does nothing").
      // Go straight to the tap button; tapping it IS the fresh gesture.
      _containerReady = true;
      setState(() {
        _errorMsg = 'Tap below to start the camera.';
        _requiresTap = true;
      });
    } else if (_initAttempts < 20) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) _tryInitContainerAndCamera();
      });
    } else {
      setState(() {
        _errorMsg = 'AR camera container mounting timed out. Tap to retry.';
        _requiresTap = true;
      });
      widget.onError?.call();
    }
  }

  void _startCameraStream() {
    _jsEval('window._graziaARReady = false; window._graziaARError = null;');

    _jsEval(
      'GraziaAR.startCamera()'
      '.then(function(){ window._graziaARReady = true; })'
      '.catch(function(e){ window._graziaARError = e ? (e.message || e.toString()) : "Camera start failed"; });',
    );

    _pollTimer?.cancel();
    final startedAt = DateTime.now();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 250), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }

      final ready = _jsEval('_graziaARReady');
      final err = _jsEval('_graziaARError');

      if (ready == true) {
        t.cancel();
        setState(() {
          _cameraReady = true;
          _requiresTap = false;
          _errorMsg = null;
        });
        widget.onReady?.call();
        if (widget.stoneImagePath != null) {
          ARCameraView.updateStone(widget.stoneImagePath, widget.opacity);
        }
        ARCameraView.showWallBoundary(true);
      } else if (err != null && err.toString().isNotEmpty && err.toString() != 'null') {
        t.cancel();
        final errStr = err.toString();
        setState(() {
          _errorMsg = errStr;
          _requiresTap = true;
        });
        widget.onError?.call();
      } else if (DateTime.now().difference(startedAt) > const Duration(seconds: 7)) {
        // ponytail: iOS Safari can silently never resolve/reject getUserMedia
        // when it's called a few async ticks removed from the tap that
        // triggered it (auto-start on nav isn't "gesture-fresh" enough for
        // WebKit) — no permission prompt, no error, just an infinite hang.
        // Bail to the tap-to-start button, whose onPressed IS a fresh
        // synchronous gesture and reliably triggers the permission prompt.
        t.cancel();
        setState(() {
          _errorMsg = 'Tap below to start the camera.';
          _requiresTap = true;
        });
        widget.onError?.call();
      }
    });
  }

  void _onUserTapStart() {
    setState(() {
      _errorMsg = null;
      _requiresTap = false;
    });
    if (_containerReady) {
      _startCameraStream();
    } else {
      _startInitSequence();
    }
  }

  @override
  void didUpdateWidget(ARCameraView old) {
    super.didUpdateWidget(old);
    if (old.stoneImagePath != widget.stoneImagePath ||
        old.opacity != widget.opacity) {
      ARCameraView.updateStone(widget.stoneImagePath, widget.opacity);
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pulseCtrl.dispose();
    ARCameraView.stopCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        HtmlElementView(viewType: _viewType),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _cameraReady
              ? const SizedBox.shrink()
              : _errorMsg != null || _requiresTap
                  ? _buildTapToStartOverlay()
                  : _buildLoadingState(),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: FadeTransition(
          opacity: _pulseAnim,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFFC8A53C),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Initializing Camera…',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Allow camera access when prompted by browser',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTapToStartOverlay() {
    final isPermissionDenied = _errorMsg != null &&
        (_errorMsg!.contains('denied') || _errorMsg!.contains('NotAllowed'));

    return Container(
      color: Colors.black.withValues(alpha: 0.88),
      child: Align(
        alignment: const Alignment(0, -0.35),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFC8A53C).withValues(alpha: 0.15),
                  border: Border.all(
                    color: const Color(0xFFC8A53C).withValues(alpha: 0.4),
                  ),
                ),
                child: Icon(
                  isPermissionDenied
                      ? Icons.videocam_off_rounded
                      : Icons.camera_alt_rounded,
                  color: const Color(0xFFC8A53C),
                  size: 42,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isPermissionDenied
                    ? 'Camera Permission Required'
                    : 'Enable Live AR Camera',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isPermissionDenied
                    ? 'Camera access was blocked.\nPlease allow camera permissions in your browser settings and tap below.'
                    : (_errorMsg ?? 'Tap below to launch real-time camera view.'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                  height: 1.5,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: _onUserTapStart,
                icon: const Icon(Icons.videocam_rounded, size: 20),
                label: Text(
                  isPermissionDenied ? 'Grant Access & Retry' : 'Tap to Start Camera',
                  style: const TextStyle(
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
                  elevation: 6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
