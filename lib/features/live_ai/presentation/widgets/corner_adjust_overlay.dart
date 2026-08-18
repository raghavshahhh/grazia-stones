import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:grazia_stones/core/constants/app_colors.dart';
import 'ar_camera_view.dart';

/// Lets the user drag the 4 wall corners onto the real wall outline.
///
/// The local edge-detection heuristic only ever finds an axis-aligned
/// rectangle, so an angled wall never renders correctly — this manual
/// override is the pragmatic fix: drag corners once, texture perspective-warps
/// to match from then on (`_drawTextureWithPerspective` already supports
/// arbitrary quads).
///
/// ponytail: corner coordinates come from the AR canvas's CSS-pixel backing
/// store, assumed 1:1 with this overlay's local Offset space. Holds on
/// standard displays; revisit if drag handles drift on some browser/DPR combo.
class CornerAdjustOverlay extends StatefulWidget {
  final VoidCallback onClose;

  const CornerAdjustOverlay({super.key, required this.onClose});

  @override
  State<CornerAdjustOverlay> createState() => _CornerAdjustOverlayState();
}

class _CornerAdjustOverlayState extends State<CornerAdjustOverlay> {
  Map<String, Offset> _corners = {};

  @override
  void initState() {
    super.initState();
    final current = ARCameraView.getWallCorners();
    if (current != null) _corners = current;
  }

  void _dragCorner(String name, Offset newPosition) {
    setState(() => _corners[name] = newPosition);
    ARCameraView.setManualCorner(name, newPosition);
  }

  void _resetToAuto() {
    HapticFeedback.selectionClick();
    ARCameraView.clearManualCorners();
    final current = ARCameraView.getWallCorners();
    setState(() => _corners = current ?? {});
  }

  @override
  Widget build(BuildContext context) {
    if (_corners.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: Stack(
        children: [
          // Quad outline connecting the 4 corners
          CustomPaint(
            painter: _QuadPainter(corners: _corners),
            size: Size.infinite,
          ),

          // Top instruction banner
          Positioned(
            top: MediaQuery.of(context).padding.top + 70,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Drag the 4 dots onto the corners of the wall so the texture matches its real angle.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 12.5, height: 1.3),
              ),
            ),
          ),

          // Draggable corner handles
          for (final entry in _corners.entries)
            Positioned(
              left: entry.value.dx - 16,
              top: entry.value.dy - 16,
              child: GestureDetector(
                onPanUpdate: (details) =>
                    _dragCorner(entry.key, entry.value + details.delta),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.goldWarm.withValues(alpha: 0.85),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Bottom controls
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 24,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: _resetToAuto,
                    icon: const Icon(Icons.refresh, color: Colors.white70, size: 18),
                    label: const Text('Reset', style: TextStyle(color: Colors.white70)),
                  ),
                  TextButton.icon(
                    onPressed: widget.onClose,
                    icon: Icon(Icons.check_circle, color: AppColors.goldWarm, size: 20),
                    label: Text('Done',
                        style: TextStyle(color: AppColors.goldWarm, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuadPainter extends CustomPainter {
  final Map<String, Offset> corners;
  _QuadPainter({required this.corners});

  @override
  void paint(Canvas canvas, Size size) {
    final tl = corners['tl'], tr = corners['tr'], bl = corners['bl'], br = corners['br'];
    if (tl == null || tr == null || bl == null || br == null) return;

    final paint = Paint()
      ..color = AppColors.goldWarm.withValues(alpha: 0.8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(tl.dx, tl.dy)
      ..lineTo(tr.dx, tr.dy)
      ..lineTo(br.dx, br.dy)
      ..lineTo(bl.dx, bl.dy)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _QuadPainter oldDelegate) => oldDelegate.corners != corners;
}
