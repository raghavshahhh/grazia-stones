import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:grazia_stones/core/constants/app_colors.dart';
import 'package:grazia_stones/core/services/ar_native_channel.dart';

enum _ArMeasureStage { width, height, done }

/// Real ARKit world-anchor measurement. Every point placed is resolved via
/// [ARNativeChannel.hitTestWallAtScreenPoint], which ray-casts the tap
/// against the tracked wall plane and stores an ARAnchor — never a screen
/// coordinate. Distances come straight from ARKit's world-space anchors.
class ArMeasureOverlay extends StatefulWidget {
  final VoidCallback onClose;
  final void Function(Map<String, dynamic> result) onComplete;
  final double? tileWidthMm;
  final double? tileHeightMm;

  const ArMeasureOverlay({
    super.key,
    required this.onClose,
    required this.onComplete,
    this.tileWidthMm,
    this.tileHeightMm,
  });

  @override
  State<ArMeasureOverlay> createState() => _ArMeasureOverlayState();
}

class _ArMeasureOverlayState extends State<ArMeasureOverlay> {
  _ArMeasureStage _stage = _ArMeasureStage.width;
  int _tapsInStage = 0;
  double? _widthMeters;
  double? _heightMeters;
  final String _unit = 'ft';
  bool _busy = false;

  Future<void> _onTapUp(TapUpDetails details) async {
    if (_busy || _stage == _ArMeasureStage.done) return;
    setState(() => _busy = true);

    final hit = await ARNativeChannel.hitTestWallAtScreenPoint(details.localPosition);
    if (hit == null) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tap directly on the detected wall')),
        );
      }
      return;
    }

    HapticFeedback.selectionClick();
    _tapsInStage++;

    if (_tapsInStage == 2) {
      final distance = await ARNativeChannel.getMeasurementDistance();
      HapticFeedback.mediumImpact();

      if (_stage == _ArMeasureStage.width) {
        _widthMeters = distance;
        await ARNativeChannel.clearMeasurement();
        if (mounted) {
          setState(() {
            _stage = _ArMeasureStage.height;
            _tapsInStage = 0;
          });
        }
      } else {
        _heightMeters = distance;
        if (mounted) setState(() => _stage = _ArMeasureStage.done);
        _finish();
        return;
      }
    }

    if (mounted) setState(() => _busy = false);
  }

  void _finish() {
    final w = _widthMeters;
    final h = _heightMeters;
    if (w == null || h == null) return;

    final widthUnit = _metersTo(w, _unit);
    final heightUnit = _metersTo(h, _unit);
    final wallArea = widthUnit * heightUnit;

    final result = <String, dynamic>{
      'wallWidth': widthUnit.toStringAsFixed(2),
      'wallHeight': heightUnit.toStringAsFixed(2),
      'wallArea': wallArea.toStringAsFixed(2),
      'isCalibrated': true,
      'calibrationUnit': _unit,
    };

    final tw = widget.tileWidthMm;
    final th = widget.tileHeightMm;
    if (tw != null && th != null && tw > 0 && th > 0) {
      final tileWUnit = _mmTo(tw, _unit);
      final tileHUnit = _mmTo(th, _unit);
      final tileArea = tileWUnit * tileHUnit;
      const wastagePercent = 10;
      final baseQty = (wallArea / tileArea).ceil();
      final recommended = (baseQty * (1 + wastagePercent / 100)).ceil();

      result.addAll({
        'tileWidth': tileWUnit.toStringAsFixed(2),
        'tileHeight': tileHUnit.toStringAsFixed(2),
        'tileArea': tileArea.toStringAsFixed(2),
        'baseQuantity': baseQty,
        'wastagePercent': wastagePercent,
        'recommendedQuantity': recommended,
      });
    } else {
      // No tile selected yet — still report the real wall measurement.
      result.addAll({
        'tileArea': '0.00',
        'baseQuantity': 0,
        'wastagePercent': 10,
        'recommendedQuantity': 0,
      });
    }

    widget.onComplete(result);
  }

  double _metersTo(double meters, String unit) {
    switch (unit) {
      case 'ft':
        return meters * 3.280839895;
      case 'in':
        return meters * 39.3700787;
      case 'cm':
        return meters * 100;
      default:
        return meters;
    }
  }

  double _mmTo(double mm, String unit) {
    switch (unit) {
      case 'ft':
        return mm / 304.8;
      case 'in':
        return mm / 25.4;
      case 'cm':
        return mm / 10;
      default:
        return mm / 1000;
    }
  }

  @override
  void dispose() {
    ARNativeChannel.clearMeasurement();
    super.dispose();
  }

  String _instructionText() {
    if (_stage == _ArMeasureStage.width) {
      return _tapsInStage == 0
          ? 'Tap the LEFT edge of the wall'
          : 'Now tap the RIGHT edge of the wall';
    }
    if (_stage == _ArMeasureStage.height) {
      return _tapsInStage == 0
          ? 'Tap the BOTTOM edge of the wall'
          : 'Now tap the TOP edge of the wall';
    }
    return 'Measurement complete';
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: _onTapUp,
        child: Stack(
          children: [
            Positioned(
              top: MediaQuery.of(context).padding.top + 130,
              left: 16,
              right: 16,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.goldWarm.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    _busy ? 'Placing world anchor…' : _instructionText(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 40,
              left: 16,
              right: 16,
              child: ElevatedButton(
                onPressed: () {
                  ARNativeChannel.clearMeasurement();
                  widget.onClose();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Cancel', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
