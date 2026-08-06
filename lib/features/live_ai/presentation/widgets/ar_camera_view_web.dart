/// Web implementation of ARCameraView.
/// Uses dart:html + dart:js to bridge to the GraziaAR JavaScript engine.
// ignore_for_file: avoid_web_libraries_in_flutter
library;

import 'dart:async';
// ignore: uri_does_not_exist
import 'dart:html' as html;
// ignore: uri_does_not_exist
import 'dart:js' as js;
// ignore: uri_does_not_exist
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ── Platform view registration ──────────────────────────────────────────────

const _kViewType = 'grazia-ar-camera-v1';
bool _registered = false;

void _ensureRegistered() {
  if (_registered) return;
  _registered = true;
  ui_web.platformViewRegistry.registerViewFactory(_kViewType, (int viewId) {
    final div = html.DivElement()
      ..id = 'grazia-ar-container'
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
    return js.context.callMethod('eval', [expr]);
  } catch (e) {
    if (kDebugMode) debugPrint('[GraziaAR] JS error: $e');
    return null;
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
    } else {
      _jsEval('GraziaAR.setTexture("$assetPath")');
    }
  }

  static void updateOpacity(double opacity) {
    // Opacity is now part of the rendering pipeline, no separate control
  }

  static void updateScale(double scale) {
    // Scale is now part of perspective transform
  }

  static void updatePosition(Offset position) {
    // Position is now auto-detected via wall detection
  }

  static void updateRotation(double rotation) {
    // Rotation is now part of perspective transform
  }

  static void showWallBoundary(bool show) {
    // Wall boundary is automatically shown when detected
  }

  static void stopCamera() {
    _jsEval('GraziaAR.stopCamera()');
  }

  @override
  State<ARCameraView> createState() => _ARCameraViewState();
}

class _ARCameraViewState extends State<ARCameraView> {
  bool _cameraReady = false;
  bool _requiresTap = false;
  String? _errorMsg;
  Timer? _pollTimer;
  int _initAttempts = 0;

  @override
  void initState() {
    super.initState();
    _ensureRegistered();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startInitSequence());
  }

  void _startInitSequence() {
    _initAttempts = 0;
    _tryInitContainerAndCamera();
  }

  void _tryInitContainerAndCamera() {
    _initAttempts++;
    final initResult = _jsEval('GraziaAR.init("grazia-ar-container")');

    if (initResult == true) {
      _startCameraStream();
    } else if (_initAttempts < 15) {
      // Retry waiting for Shadow DOM/Platform View mount
      Future.delayed(const Duration(milliseconds: 200), () {
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
    _pollTimer = Timer.periodic(const Duration(milliseconds: 250), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }

      final ready = js.context['_graziaARReady'];
      final err = js.context['_graziaARError'];

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
          // If Safari block/gesture issue or permission needed, offer direct tap button
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
    _startInitSequence();
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
    ARCameraView.stopCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Real camera feed via HtmlElementView ──
        const HtmlElementView(viewType: _kViewType),

        // ── Interactive overlay for Safari gesture / error state ──
        if (_errorMsg != null || _requiresTap)
          _buildTapToStartOverlay(),

        // ── Loading state ──
        if (!_cameraReady && _errorMsg == null && !_requiresTap)
          _buildLoadingState(),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
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
              'Allow camera access when prompted by Safari / browser',
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
    );
  }

  Widget _buildTapToStartOverlay() {
    final isPermissionDenied = _errorMsg != null &&
        (_errorMsg!.contains('denied') || _errorMsg!.contains('NotAllowed'));

    return Container(
      color: Colors.black.withValues(alpha: 0.90),
      child: Center(
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
                isPermissionDenied ? 'Camera Permission Required' : 'Enable Live AR Camera',
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
                    ? 'Safari blocked camera access.\nPlease allow camera permissions in Safari / iOS Settings and tap below.'
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
