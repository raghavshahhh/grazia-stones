import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:grazia_stones/core/constants/app_colors.dart';

/// Tap-to-measure overlay for web & fallback platforms, styled to
/// Apple iOS Measure design standards.
class MeasureOverlay extends StatefulWidget {
  final VoidCallback onClose;

  const MeasureOverlay({super.key, required this.onClose});

  @override
  State<MeasureOverlay> createState() => _MeasureOverlayState();
}

class _MeasureOverlayState extends State<MeasureOverlay> {
  double? _pixelsPerFoot;
  final List<Offset> _points = [];
  final _calibrationLengthController = TextEditingController();
  bool _calibrating = true;
  bool _useMetric = true; // cm vs ft

  @override
  void dispose() {
    _calibrationLengthController.dispose();
    super.dispose();
  }

  void _onTapUp(TapUpDetails details) {
    HapticFeedback.selectionClick();
    setState(() => _points.add(details.localPosition));
  }

  double get _totalPixelLength {
    double total = 0;
    for (var i = 1; i < _points.length; i++) {
      total += (_points[i] - _points[i - 1]).distance;
    }
    return total;
  }

  void _undo() {
    if (_points.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _points.removeLast());
  }

  void _clear() => setState(() => _points.clear());

  void _finishCalibration() {
    final realFeet = double.tryParse(_calibrationLengthController.text);
    if (_points.length < 2 || realFeet == null || realFeet <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draw a line on a known object and enter its real length in feet')),
      );
      return;
    }
    setState(() {
      _pixelsPerFoot = _totalPixelLength / realFeet;
      _calibrating = false;
      _points.clear();
    });
  }

  String _formatMeasurement(double totalFeet) {
    if (_useMetric) {
      final cm = (totalFeet * 30.48).round();
      return '$cm cm';
    } else {
      final inches = totalFeet * 12;
      if (inches < 12) {
        return '${inches.toStringAsFixed(1)} in';
      }
      return "${totalFeet.toStringAsFixed(1)} ft";
    }
  }

  @override
  Widget build(BuildContext context) {
    final feet = _pixelsPerFoot == null ? null : _totalPixelLength / _pixelsPerFoot!;

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: _onTapUp,
        child: Stack(
          children: [
            // Apple Ruler lines with graduated ticks and endpoints
            CustomPaint(
              painter: _AppleWebRulerPainter(
                points: _points,
                totalDistanceText: feet != null ? _formatMeasurement(feet) : null,
              ),
              size: Size.infinite,
            ),

            // Subtle Apple reticle center aid when no points or placed
            if (_points.isEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.6),
                          width: 1.8,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Top Apple Frosted Guidance Banner
            Positioned(
              top: MediaQuery.of(context).padding.top + 50,
              left: 20,
              right: 20,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _calibrating ? Icons.tune_rounded : Icons.straighten_rounded,
                            size: 15,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _calibrating
                                  ? 'Tap 2 points on a known reference to calibrate scale'
                                  : 'Tap anywhere on the surface to measure length',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Live floating badge in center if measured
            if (!_calibrating && _points.length >= 2 && feet != null)
              Positioned(
                top: MediaQuery.of(context).padding.top + 105,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () => setState(() => _useMetric = !_useMetric),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _formatMeasurement(feet),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 16,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Bottom controls
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 24,
              left: 16,
              right: 16,
              child: _calibrating ? _buildCalibrationControls() : _buildMeasureControls(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalibrationControls() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 0.8),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _calibrationLengthController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Known length (e.g. 3.0 ft)',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 13),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: _undo,
                icon: const Icon(Icons.undo_rounded, color: Colors.white),
              ),
              ElevatedButton(
                onPressed: _finishCalibration,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text('Set Scale', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: widget.onClose,
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMeasureControls() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 0.8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildAppleActionButton(
                icon: Icons.undo_rounded,
                label: 'Undo',
                onTap: _undo,
              ),
              _buildAppleActionButton(
                icon: Icons.refresh_rounded,
                label: 'Clear',
                onTap: _clear,
              ),
              _buildAppleActionButton(
                icon: Icons.tune_rounded,
                label: 'Recalibrate',
                onTap: () => setState(() {
                  _calibrating = true;
                  _points.clear();
                }),
              ),
              _buildAppleActionButton(
                icon: Icons.check_circle_rounded,
                label: 'Done',
                onTap: widget.onClose,
                color: AppColors.goldWarm,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppleActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        color: Colors.transparent,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppleWebRulerPainter extends CustomPainter {
  final List<Offset> points;
  final String? totalDistanceText;

  _AppleWebRulerPainter({
    required this.points,
    this.totalDistanceText,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.95)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.square;

    final majorTickPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.square;

    final dotFill = Paint()..color = Colors.white;
    final dotShadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    for (var i = 1; i < points.length; i++) {
      final p1 = points[i - 1];
      final p2 = points[i];
      final segLength = (p2 - p1).distance;
      if (segLength < 1.0) continue;

      // Draw ruler line
      canvas.drawLine(p1, p2, linePaint);

      // Draw graduated tick marks
      final dir = (p2 - p1) / segLength;
      final perp = Offset(-dir.dy, dir.dx);
      const tickSpacing = 14.0;
      final count = (segLength / tickSpacing).floor();

      for (var k = 1; k <= count; k++) {
        final fraction = (k * tickSpacing) / segLength;
        if (fraction >= 0.95) break;
        final markCenter = Offset.lerp(p1, p2, fraction)!;
        final isMajor = (k % 5 == 0);
        final tickLength = isMajor ? 6.0 : 3.5;
        final start = markCenter - perp * tickLength;
        final end = markCenter + perp * tickLength;
        canvas.drawLine(start, end, isMajor ? majorTickPaint : tickPaint);
      }
    }

    // Draw solid circular white endpoints
    for (final p in points) {
      canvas.drawCircle(p + const Offset(0, 1.5), 8, dotShadow);
      canvas.drawCircle(p, 7.5, dotFill);
    }
  }

  @override
  bool shouldRepaint(covariant _AppleWebRulerPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.totalDistanceText != totalDistanceText;
}
