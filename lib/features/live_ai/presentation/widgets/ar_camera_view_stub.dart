/// Stub implementation of ARCameraView for non-web platforms.
/// The real implementation lives in ar_camera_view_web.dart.
library;

import 'package:flutter/material.dart';

class ARCameraView extends StatelessWidget {
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

  /// No-op on non-web platforms
  static void updateStone(String? assetPath, double opacity) {}
  static void updateOpacity(double opacity) {}
  static void showWallBoundary(bool show) {}
  static void stopCamera() {}

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off, color: Colors.white24, size: 52),
            SizedBox(height: 14),
            Text(
              'Live camera not available\non this platform.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white38,
                fontSize: 14,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
