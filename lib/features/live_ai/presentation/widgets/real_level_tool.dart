import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grazia_stones/core/utils/level_math.dart';
import 'package:sensors_plus/sensors_plus.dart';

const _kLevelGreen = Color(0xFF28CD41);

/// Spirit level driven by the phone's accelerometer (no camera, works on every phone).
/// Lay the phone flat for a 2-axis bubble, or stand it on an edge / hold it against a wall for a single angle.
class RealLevelTool extends StatefulWidget {
  const RealLevelTool({super.key});

  @override
  State<RealLevelTool> createState() => _RealLevelToolState();
}

class _RealLevelToolState extends State<RealLevelTool> {
  StreamSubscription<AccelerometerEvent>? _sub;
  Timer? _noDataTimer;
  double _x = 0, _y = 0, _z = 9.80665;
  bool _gotData = false;
  bool _failed = false;
  bool _wasLevel = false;

  @override
  void initState() {
    super.initState();
    _sub = accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval).listen(
      (e) {
        // Low-pass filter so the bubble is calm but still responsive.
        const a = 0.22;
        if (!mounted) return;
        setState(() {
          if (!_gotData) {
            _x = e.x;
            _y = e.y;
            _z = e.z;
          } else {
            _x += a * (e.x - _x);
            _y += a * (e.y - _y);
            _z += a * (e.z - _z);
          }
          _gotData = true;
        });
        final level = readLevel(_x, _y, _z).isLevel;
        if (level && !_wasLevel) HapticFeedback.selectionClick();
        _wasLevel = level;
      },
      onError: (_) {
        if (mounted) setState(() => _failed = true);
      },
    );
    _noDataTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && !_gotData) setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _noDataTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed && !_gotData) {
      return Container(
        color: Colors.black87,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Text(
          'This device has no motion sensor, so the level cannot work here.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
        ),
      );
    }
    final r = readLevel(_x, _y, _z);
    final shown = r.degrees.abs();
    final label = shown < 10 ? shown.toStringAsFixed(1) : shown.round().toString();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      color: r.isLevel ? _kLevelGreen : Colors.black87,
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            SizedBox(
              width: 240,
              height: 240,
              child: r.flat ? _FlatBubble(reading: r) : _UprightLine(reading: r),
            ),
            const SizedBox(height: 28),
            Text(
              '$label°',
              style: GoogleFonts.inter(color: Colors.white, fontSize: 64, fontWeight: FontWeight.w300),
            ),
            const SizedBox(height: 6),
            Text(
              r.isLevel ? 'LEVEL' : (r.flat ? 'Flat on a surface' : 'Held upright'),
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, letterSpacing: 1.6, fontWeight: FontWeight.w600),
            ),
            const Spacer(flex: 3),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 120),
              child: Text(
                'Lay the phone flat on a surface, or stand it on its edge against a wall or frame.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 12, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlatBubble extends StatelessWidget {
  final LevelReading reading;
  const _FlatBubble({required this.reading});

  @override
  Widget build(BuildContext context) {
    final ring = reading.isLevel ? Colors.white : Colors.white54;
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ring, width: 2)),
        ),
        Container(width: 64, height: 64, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ring, width: 1.5))),
        Container(width: 1, height: 240, color: Colors.white24),
        Container(width: 240, height: 1, color: Colors.white24),
        Transform.translate(
          offset: Offset(reading.bubbleX * 88, reading.bubbleY * 88),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: reading.isLevel ? 0.95 : 0.35),
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _UprightLine extends StatelessWidget {
  final LevelReading reading;
  const _UprightLine({required this.reading});

  @override
  Widget build(BuildContext context) {
    final ring = reading.isLevel ? Colors.white : Colors.white70;
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(width: 240, height: 3, color: Colors.white24), // true horizontal reference
        Transform.rotate(
          angle: -reading.degrees * math.pi / 180,
          child: Container(
            width: 220,
            height: 6,
            decoration: BoxDecoration(color: ring, borderRadius: BorderRadius.circular(3)),
          ),
        ),
        Container(width: 14, height: 14, decoration: BoxDecoration(shape: BoxShape.circle, color: ring)),
      ],
    );
  }
}
