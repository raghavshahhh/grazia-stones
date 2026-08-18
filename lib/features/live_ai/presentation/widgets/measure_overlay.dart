import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:grazia_stones/core/constants/app_colors.dart';

/// Tap-to-measure overlay for the live AR camera screen.
///
/// No device here has depth sensing (WebXR `immersive-ar` isn't supported on
/// iOS Safari, which is what this app runs in), so there's no way to get a
/// true depth-based measurement. Instead this uses a one-time manual
/// calibration: the user draws a line over something of known length (e.g. a
/// door, a floor tile) and enters its real size, giving a pixels-per-foot
/// ratio. Every line drawn after that is scaled by that ratio. Accuracy holds
/// as long as the calibrated object and the thing being measured are roughly
/// the same distance from the camera.
///
/// ponytail: single global scale factor, not a real per-plane homography —
/// good enough for "how many feet is this wall roughly" on a flat frontal
/// wall, upgrade to a homography from the detected wall corners if precision
/// matters later.
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

  @override
  Widget build(BuildContext context) {
    final feet = _pixelsPerFoot == null ? null : _totalPixelLength / _pixelsPerFoot!;

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: _onTapUp,
        child: Stack(
          children: [
            CustomPaint(
              painter: _MeasurePainter(points: _points, color: AppColors.goldWarm),
              size: Size.infinite,
            ),

            // Top instruction / calibration banner
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              left: 16,
              right: 16,
              child: _InfoBanner(
                text: _calibrating
                    ? 'Calibrate: tap two points along something of known length (a door, a tile, a paper edge), then enter its real length.'
                    : 'Tap points to draw along the wall. Distance updates live.',
              ),
            ),

            // Live length readout
            if (!_calibrating && _points.length >= 2)
              Positioned(
                top: MediaQuery.of(context).padding.top + 140,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.goldWarm.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      '${feet!.toStringAsFixed(2)} ft',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _calibrationLengthController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Real length (ft)',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                isDense: true,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: _undo,
            icon: const Icon(Icons.undo, color: Colors.white70),
          ),
          ElevatedButton(
            onPressed: _finishCalibration,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.goldWarm,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Set'),
          ),
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildMeasureControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          TextButton.icon(
            onPressed: _undo,
            icon: const Icon(Icons.undo, color: Colors.white70, size: 18),
            label: const Text('Undo', style: TextStyle(color: Colors.white70)),
          ),
          TextButton.icon(
            onPressed: _clear,
            icon: const Icon(Icons.refresh, color: Colors.white70, size: 18),
            label: const Text('Clear', style: TextStyle(color: Colors.white70)),
          ),
          TextButton.icon(
            onPressed: () => setState(() {
              _calibrating = true;
              _points.clear();
            }),
            icon: const Icon(Icons.straighten, color: Colors.white70, size: 18),
            label: const Text('Recalibrate', style: TextStyle(color: Colors.white70)),
          ),
          TextButton.icon(
            onPressed: widget.onClose,
            icon: Icon(Icons.check_circle, color: AppColors.goldWarm, size: 20),
            label: Text('Done', style: TextStyle(color: AppColors.goldWarm, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String text;
  const _InfoBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.3),
      ),
    );
  }
}

class _MeasurePainter extends CustomPainter {
  final List<Offset> points;
  final Color color;
  _MeasurePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final dotPaint = Paint()..color = color;
    final dotBorder = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (var i = 1; i < points.length; i++) {
      canvas.drawLine(points[i - 1], points[i], linePaint);
    }
    for (final p in points) {
      canvas.drawCircle(p, 6, dotPaint);
      canvas.drawCircle(p, 6, dotBorder);
    }
  }

  @override
  bool shouldRepaint(covariant _MeasurePainter oldDelegate) => oldDelegate.points != points;
}
