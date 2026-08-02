import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Web camera view using conditional import for web-only APIs.
class WebCameraView extends StatefulWidget {
  final Function(String)? onFrameCaptured;
  final VoidCallback? onReady;
  final VoidCallback? onError;
  final double width;
  final double height;

  const WebCameraView({
    super.key,
    this.onFrameCaptured,
    this.onReady,
    this.onError,
    this.width = 640,
    this.height = 480,
  });

  @override
  State<WebCameraView> createState() => _WebCameraViewState();
}

class _WebCameraViewState extends State<WebCameraView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onReady?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return _buildWebCamera();
    }
    return _buildFallback();
  }

  Widget _buildWebCamera() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam, color: Colors.white54, size: 48),
            SizedBox(height: 8),
            Text(
              'Camera Preview',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Icon(Icons.videocam_off, color: Colors.white24, size: 48),
      ),
    );
  }
}
