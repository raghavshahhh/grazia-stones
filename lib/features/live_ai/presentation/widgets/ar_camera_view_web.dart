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
  });

  final VoidCallback? onReady;
  final VoidCallback? onError;
  final String? stoneImagePath;
  final double opacity;

  // ── Static control API (callable from anywhere in the screen) ──

  /// Update the stone texture overlaid on the camera feed.
  /// [assetPath] is the Flutter asset path, e.g. 'assets/images/foo.png'.
  /// Pass null to clear the overlay.
  static void updateStone(String? assetPath, double opacity) {
    if (assetPath == null) {
      _jsEval('GraziaAR.setStoneTexture(null, 0)');
    } else {
      _jsEval('GraziaAR.setStoneTexture("$assetPath", $opacity)');
    }
  }

  static void updateOpacity(double opacity) {
    _jsEval('GraziaAR.setOpacity($opacity)');
  }

  static void showWallBoundary(bool show) {
    _jsEval('GraziaAR.showWallDetection(${show.toString()})');
  }

  static void stopCamera() {
    _jsEval('GraziaAR.stopCamera()');
  }

  @override
  State<ARCameraView> createState() => _ARCameraViewState();
}

class _ARCameraViewState extends State<ARCameraView> {
  bool _cameraReady = false;
  String? _errorMsg;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _ensureRegistered();
    // Wait for the HtmlElementView to mount, then init camera
    WidgetsBinding.instance.addPostFrameCallback((_) => _initAR());
  }

  Future<void> _initAR() async {
    // 1. Init the GraziaAR container
    final initResult = _jsEval('GraziaAR.init("grazia-ar-container")');
    if (initResult == false) {
      setState(() => _errorMsg = 'AR container not found');
      widget.onError?.call();
      return;
    }

    // 2. Start camera — the promise updates window._graziaARReady / _graziaARError
    _jsEval(
      'GraziaAR.startCamera()'
      '.then(function(){ window._graziaARReady = true; })'
      '.catch(function(e){ window._graziaARError = e ? (e.message || e.toString()) : "Camera denied"; });',
    );

    // 3. Poll until ready or error
    _pollTimer = Timer.periodic(const Duration(milliseconds: 250), (t) {
      if (!mounted) { t.cancel(); return; }

      final ready = js.context['_graziaARReady'];
      final err   = js.context['_graziaARError'];

      if (ready == true) {
        t.cancel();
        setState(() => _cameraReady = true);
        widget.onReady?.call();
        // Apply initial stone if pre-selected
        if (widget.stoneImagePath != null) {
          ARCameraView.updateStone(widget.stoneImagePath, widget.opacity);
        }
        // Show wall boundary briefly
        ARCameraView.showWallBoundary(true);
      } else if (err != null && err.toString().isNotEmpty && err.toString() != 'null') {
        t.cancel();
        setState(() => _errorMsg = err.toString());
        widget.onError?.call();
      }
    });
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
        HtmlElementView(viewType: _kViewType),

        // ── Error overlay ──
        if (_errorMsg != null) _buildErrorState(_errorMsg!),

        // ── Waiting / permission overlay ──
        if (!_cameraReady && _errorMsg == null) _buildLoadingState(),
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
                strokeWidth: 2,
                color: Color(0xFFC8A53C),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Requesting camera…',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 15,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Allow camera access when prompted',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 12,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String msg) {
    return Container(
      color: Colors.black.withValues(alpha: 0.92),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined,
                  color: Color(0xFFC8A53C), size: 52),
              const SizedBox(height: 16),
              const Text(
                'Camera Unavailable',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 10),
              Text(
                msg.contains('denied') || msg.contains('NotAllowed')
                    ? 'Camera permission was denied.\nPlease allow access in your browser settings.'
                    : 'Could not start the camera.\n$msg',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                  fontFamily: 'Inter',
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: () {
                  setState(() { _errorMsg = null; });
                  _jsEval('window._graziaARError = null; window._graziaARReady = false;');
                  _initAR();
                },
                icon: const Icon(Icons.refresh, color: Color(0xFFC8A53C)),
                label: const Text(
                  'Try Again',
                  style: TextStyle(color: Color(0xFFC8A53C), fontFamily: 'Inter'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
