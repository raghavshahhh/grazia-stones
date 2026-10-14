import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grazia_stones/core/services/ar_native_channel.dart';
import 'package:grazia_stones/core/utils/measure_format.dart';
import 'package:grazia_stones/core/widgets/animated_widgets.dart';
import 'package:grazia_stones/shared/widgets/luxury_toast.dart';
import 'package:grazia_stones/features/live_ai/presentation/widgets/real_level_tool.dart';

enum _MeasureMode { measure, level }

enum _TrackingGuideState { ready, searching, lost }

/// Authentic Apple iOS Measure App experience for Grazia Stones.
/// Faithfully reproduces Apple Measure HIG:
/// - 3D Perspective Reticle with solid white center dot
/// - Floating "Add a point" speech-bubble tooltip
/// - Triple Action Deck: Undo, large circular '+', and White Shutter button
/// - Ruler Line with graduated tick marks and floating measurement badge ("19 cm >")
/// - 2-Axis Interactive Spirit Level tool (vibrant Apple Green on 0°)
/// - Surface Guidance States ("Continue to move iPhone", "Return to previous area")
/// - LiDAR / ARKit depth raycasting on iOS with realistic camera fallback
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

class _ArMeasureOverlayState extends State<ArMeasureOverlay>
    with TickerProviderStateMixin {
  _MeasureMode _currentMode = _MeasureMode.measure;
  _TrackingGuideState _trackingState = _TrackingGuideState.ready;

  // Active Points & Measurements
  // Native anchor id + real-world (metres) position of each pin, from the native hit-test
  final List<String> _anchorIds = [];
  final List<List<double>> _worldPoints = [];
  final List<double> _segmentMeters = [];
  // Where each pin is on screen right now (null = behind the camera / not tracked), refreshed every ~60 ms
  List<Offset?> _pinScreen = [];
  // Live probe under the reticle: surface point and distance from the camera, null when no surface is found
  List<double>? _probeWorld;
  Offset? _probeScreen;
  double? _probeDistance;
  // Smoothed values the painter actually draws (eased toward the native targets every frame, like iOS Measure)
  List<Offset?> _pinShown = [];
  final List<int> _pinBornMs = [];
  double? _liveShown;
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);
  final Stopwatch _clock = Stopwatch()..start();
  Ticker? _ticker;
  Duration _lastTick = Duration.zero;
  bool _ticking = false;
  String _unit = 'cm';
  bool _busy = false;

  // Shutter Flash Animation
  late AnimationController _flashController;
  late Animation<double> _flashAnimation;

  // Reticle Pulse Animation
  late AnimationController _reticleController;
  late Animation<double> _reticleScale;

  @override
  void initState() {
    super.initState();

    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: 1.0, // resting state = flash finished (transparent)
    );
    _flashAnimation = Tween<double>(
      begin: 0.85,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _flashController, curve: Curves.easeOut));

    _reticleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _reticleScale = Tween<double>(begin: 0.98, end: 1.03).animate(
      CurvedAnimation(parent: _reticleController, curve: Curves.easeInOut),
    );

    _ticker = createTicker(_onFrame)..start();

    // Listen to native wall tracking state changes
    ARNativeChannel.onWallStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        if (state == 'SEARCHING') {
          _trackingState = _TrackingGuideState.searching;
        } else if (state == 'LOST') {
          _trackingState = _TrackingGuideState.lost;
        } else {
          _trackingState = _TrackingGuideState.ready;
        }
      });
    });
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _frame.dispose();
    _flashController.dispose();
    _reticleController.dispose();
    ARNativeChannel.clearMeasurement();
    super.dispose();
  }

  // ── Core Measurement Logic ───────────────────────────────────────────

  Offset get _centerReticleOffset {
    final size = MediaQuery.of(context).size;
    return Offset(size.width / 2, size.height / 2);
  }

  static double _dist(List<double> a, List<double> b) => math.sqrt(
    math.pow(a[0] - b[0], 2) +
        math.pow(a[1] - b[1], 2) +
        math.pow(a[2] - b[2], 2),
  );

  /// Length of the live segment from the last pin to whatever the reticle is on (null until both exist).
  double? get _liveMeters {
    if (_worldPoints.isEmpty || _probeWorld == null) return null;
    return _dist(_worldPoints.last, _probeWorld!);
  }

  double get _totalMeters => _segmentMeters.fold<double>(0, (a, b) => a + b);

  /// Every frame: ask the native side for fresh targets (one request in flight) and ease what is drawn toward them.
  void _onFrame(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (_currentMode != _MeasureMode.measure) return;
    _refreshLive();
    final k = 1 - math.exp(-dt.clamp(0.0, 0.1) * 22);
    final shown = <Offset?>[];
    for (var i = 0; i < _pinScreen.length; i++) {
      final target = _pinScreen[i];
      final prev = i < _pinShown.length ? _pinShown[i] : null;
      shown.add(
        target == null
            ? null
            : (prev == null ? target : Offset.lerp(prev, target, k)),
      );
    }
    _pinShown = shown;
    final live = _liveMeters;
    _liveShown = live == null
        ? null
        : (_liveShown == null ? live : _liveShown! + (live - _liveShown!) * k);
    _frame.value++;
  }

  /// Polls the native side: what real surface is under the reticle, and where each pin is on screen now.
  Future<void> _refreshLive() async {
    if (_ticking || !mounted) return;
    _ticking = true;
    try {
      final reticle = _centerReticleOffset;
      final probe = await ARNativeChannel.probeSurfaceAtScreenPoint(reticle);
      final pins = await ARNativeChannel.projectMeasurementAnchors(
        List.of(_anchorIds),
      );
      if (!mounted) return;
      final hadSurface = _probeWorld != null;
      _pinScreen = pins;
      if (probe == null) {
        _probeWorld = null;
        _probeScreen = null;
        _probeDistance = null;
      } else {
        _probeWorld = [
          (probe['x'] as num).toDouble(),
          (probe['y'] as num).toDouble(),
          (probe['z'] as num).toDouble(),
        ];
        _probeScreen = reticle;
        _probeDistance = (probe['distanceM'] as num?)?.toDouble();
      }
      // Rebuild widgets only when the discrete state changes; numbers and lines animate through _frame
      if (hadSurface != (_probeWorld != null)) setState(() {});
    } finally {
      _ticking = false;
    }
  }

  Future<void> _addPointAtReticle() async {
    if (_busy) return;
    HapticFeedback.mediumImpact();
    setState(() => _busy = true);

    // Raycast through native ARKit/ARCore (LiDAR mesh when available) and pin an anchor on the real surface
    final hit = await ARNativeChannel.hitTestWallAtScreenPoint(
      _centerReticleOffset,
    );
    if (!mounted) return;

    if (hit == null) {
      // No real surface under the reticle: never invent a distance
      setState(() => _busy = false);
      LuxuryToast.show(
        context,
        message:
            'No surface found. Aim at the object and move your phone slowly.',
      );
      return;
    }

    final world = [
      (hit['x'] as num).toDouble(),
      (hit['y'] as num).toDouble(),
      (hit['z'] as num).toDouble(),
    ];
    setState(() {
      if (_worldPoints.isNotEmpty) {
        _segmentMeters.add(_dist(world, _worldPoints.last));
      }
      _anchorIds.add(hit['anchorId'] as String);
      _worldPoints.add(world);
      _pinScreen = [..._pinScreen, _centerReticleOffset];
      _pinShown = [..._pinShown, _centerReticleOffset];
      _pinBornMs.add(_clock.elapsedMilliseconds);
      _busy = false;
    });
  }

  void _undoPoint() {
    if (_anchorIds.isEmpty) return;
    HapticFeedback.selectionClick();
    // The native anchor of the removed pin is dropped with the rest on Clear; a stale one is never drawn
    // because the overlay only projects ids it still holds.
    setState(() {
      _anchorIds.removeLast();
      _worldPoints.removeLast();
      if (_segmentMeters.isNotEmpty) _segmentMeters.removeLast();
      if (_pinScreen.isNotEmpty) {
        _pinScreen = _pinScreen.sublist(0, _pinScreen.length - 1);
        _pinShown = _pinShown.sublist(
          0,
          math.min(_pinShown.length, _pinScreen.length),
        );
        if (_pinBornMs.isNotEmpty) _pinBornMs.removeLast();
      }
    });
  }

  void _clearAllPoints() {
    HapticFeedback.heavyImpact();
    ARNativeChannel.clearMeasurement();
    setState(() {
      _anchorIds.clear();
      _worldPoints.clear();
      _segmentMeters.clear();
      _pinScreen = [];
      _pinShown = [];
      _pinBornMs.clear();
      _liveShown = null;
    });
  }

  String get _measurementText {
    final lines = [
      for (var i = 0; i < _segmentMeters.length; i++)
        'Segment ${i + 1}: ${formatMeasureLength(_segmentMeters[i], _unit)}',
      'Total: ${formatMeasureLength(_totalMeters, _unit)}',
    ];
    return 'Grazia Stones AR measurement\n${lines.join('\n')}';
  }

  void _takeShutterSnapshot() {
    HapticFeedback.heavyImpact();
    _flashController.forward(from: 0.0);

    if (_segmentMeters.isEmpty) {
      LuxuryToast.show(context, message: 'Add at least two points to measure');
      return;
    }
    // Copy the real measurements so they can be pasted into WhatsApp / quote notes
    Clipboard.setData(ClipboardData(text: _measurementText));
    LuxuryToast.show(
      context,
      message: 'Measurements copied',
      icon: Icons.check_circle_rounded,
      iconColor: const Color(0xFF28CD41),
    );
  }

  void _setUnit(String unit) {
    if (unit == _unit) return;
    HapticFeedback.selectionClick();
    setState(() => _unit = unit);
  }

  static const _feetPerMeter = 3.280839895;

  /// Wall width x height needs two real segments; with fewer there is nothing honest to report.
  bool get _canApplyAsWall => _segmentMeters.length >= 2;

  void _finishAndExport() {
    if (!_canApplyAsWall) return;
    final widthFt = _segmentMeters[0] * _feetPerMeter;
    final heightFt = _segmentMeters[1] * _feetPerMeter;
    final wallArea = widthFt * heightFt;

    final result = <String, dynamic>{
      'wallWidth': widthFt.toStringAsFixed(2),
      'wallHeight': heightFt.toStringAsFixed(2),
      'wallArea': wallArea.toStringAsFixed(2),
      'isCalibrated': true,
      'calibrationUnit': 'ft',
      'totalLengthMeters': _totalMeters,
    };

    final tw = widget.tileWidthMm;
    final th = widget.tileHeightMm;
    if (tw != null && th != null && tw > 0 && th > 0) {
      final tileWFt = tw / 304.8;
      final tileHFt = th / 304.8;
      final tileArea = tileWFt * tileHFt;
      const wastage = 15;
      final baseQty = (wallArea / tileArea).ceil();
      final recQty = (baseQty * 1.15).ceil();

      result.addAll({
        'tileWidth': tileWFt.toStringAsFixed(2),
        'tileHeight': tileHFt.toStringAsFixed(2),
        'tileArea': tileArea.toStringAsFixed(2),
        'baseQuantity': baseQty,
        'wastagePercent': wastage,
        'recommendedQuantity': recQty,
      });
    }

    widget.onComplete(result);
  }

  // ── Build Method ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Gesture detector for tap-to-measure on screen
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _addPointAtReticle,
              child: const SizedBox.expand(),
            ),

            // 2. Active Mode View: Measure vs Level
            if (_currentMode == _MeasureMode.measure) ...[
              // Ruler Painter: Ticks, Pins, and Connecting Lines
              CustomPaint(
                painter: _AppleRulerPainter(
                  repaint: _frame,
                  pins: () => _pinShown,
                  bornMs: () => _pinBornMs,
                  nowMs: () => _clock.elapsedMilliseconds,
                  reticle: () => _probeScreen,
                  unit: () => _unit,
                  segmentMeters: () => _segmentMeters,
                  liveMeters: () => _liveShown,
                ),
                size: Size.infinite,
              ),

              // 3D Apple Reticle Ring with Solid Center Dot
              Center(
                child: ScaleTransition(
                  scale: _reticleScale,
                  child: _AppleReticleWidget(locked: _probeWorld != null),
                ),
              ),

              // Surface Guidance States
              if (_trackingState == _TrackingGuideState.searching &&
                  _probeWorld == null)
                _buildSearchingGuidance(),
              if (_trackingState == _TrackingGuideState.lost)
                _buildLostTrackingGuidance(),
            ] else ...[
              // 2-Axis Interactive Spirit Level Mode
              const RealLevelTool(),
            ],

            // 3. Top Navigation Bar (List, Status, Trash, Close)
            _buildTopNavBar(),

            // 3b. Unit chips + live distance to the surface under the reticle
            if (_currentMode == _MeasureMode.measure) _buildUnitBar(),

            // 4. Floating Tooltip Balloon ("Add a point")
            if (_currentMode == _MeasureMode.measure &&
                _trackingState == _TrackingGuideState.ready)
              _buildAddPointTooltip(),

            // 5. Triple Action Deck (Undo, '+', Shutter)
            _buildActionControlDeck(),

            // 6. Bottom Segmented Capsule (Measure | Level)
            _buildBottomSegmentedPill(),

            // 7. Shutter Flash Overlay
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _flashAnimation,
                builder: (context, _) => Container(
                  color: Colors.white.withValues(alpha: _flashAnimation.value),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top Bar ──────────────────────────────────────────────────────────

  Widget _buildTopNavBar() {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 8,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Measurements History / Specs List
          _buildCircleIconButton(
            icon: Icons.format_list_bulleted_rounded,
            onTap: _showMeasurementsSummarySheet,
          ),

          // Center: Close / Done Pill
          ApplePressable(
            onTap: widget.onClose,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E).withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF28CD41),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _currentMode == _MeasureMode.measure
                            ? 'AR Ruler'
                            : 'Spirit Level',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Right: Trash / Clear Button
          _buildCircleIconButton(
            icon: Icons.delete_outline_rounded,
            onTap: _anchorIds.isNotEmpty ? _clearAllPoints : null,
          ),
        ],
      ),
    );
  }

  Widget _buildCircleIconButton({required IconData icon, VoidCallback? onTap}) {
    final isEnabled = onTap != null;
    return ApplePressable(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(
                0xFF1C1C1E,
              ).withValues(alpha: isEnabled ? 0.75 : 0.40),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: isEnabled ? 0.18 : 0.08),
                width: 0.8,
              ),
            ),
            child: Icon(
              icon,
              color: isEnabled ? Colors.white : Colors.white38,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  // ── Tooltip Balloon ("Add a point") ──────────────────────────────────

  Widget _buildAddPointTooltip() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    String label = 'Add a point';
    if (_anchorIds.length == 1) label = 'Aim & tap + for 2nd point';
    if (_anchorIds.length >= 2) label = 'Tap + to add segment';

    return Positioned(
      bottom: bottomPadding + 152,
      left: 0,
      right: 0,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E).withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                label,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // Downward Pointer Arrow
            CustomPaint(
              size: const Size(12, 6),
              painter: _TooltipArrowPainter(
                color: const Color(0xFF1C1C1E).withValues(alpha: 0.88),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Triple Action Deck (Undo, '+', Shutter) ──────────────────────────

  Widget _buildActionControlDeck() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Positioned(
      bottom: bottomPadding + 76,
      left: 28,
      right: 28,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Undo Button
          ApplePressable(
            onTap: _anchorIds.isNotEmpty ? _undoPoint : null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(
                      0xFF1C1C1E,
                    ).withValues(alpha: _anchorIds.isNotEmpty ? 0.85 : 0.45),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(
                        alpha: _anchorIds.isNotEmpty ? 0.20 : 0.08,
                      ),
                    ),
                  ),
                  child: Icon(
                    Icons.undo_rounded,
                    color: _anchorIds.isNotEmpty
                        ? Colors.white
                        : Colors.white30,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),

          // Center: Large Circular '+' Button
          ApplePressable(
            onTap: _currentMode == _MeasureMode.measure
                ? _addPointAtReticle
                : null,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2E).withValues(alpha: 0.94),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.28),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.add_rounded, color: Colors.white, size: 40),
              ),
            ),
          ),

          // Right: White Shutter Button
          ApplePressable(
            onTap: _takeShutterSnapshot,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3.5),
              ),
              padding: const EdgeInsets.all(4),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom Segmented Capsule (Measure | Level) ───────────────────────

  Widget _buildBottomSegmentedPill() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Positioned(
      bottom: bottomPadding > 0 ? bottomPadding : 14,
      left: 0,
      right: 0,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E).withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Measure Tab
                  _buildSegmentItem(
                    label: 'Measure',
                    icon: Icons.straighten_rounded,
                    isSelected: _currentMode == _MeasureMode.measure,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _currentMode = _MeasureMode.measure);
                    },
                  ),

                  // Level Tab
                  _buildSegmentItem(
                    label: 'Level',
                    icon: Icons.panorama_horizontal_select_rounded,
                    isSelected: _currentMode == _MeasureMode.level,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _currentMode = _MeasureMode.level);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentItem({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3A3A3C) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.white54,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: GoogleFonts.inter(
                color: isSelected ? Colors.white : Colors.white54,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Guidance States ──────────────────────────────────────────────────

  Widget _buildSearchingGuidance() {
    return Align(
      alignment: const Alignment(
        0,
        0.25,
      ), // below the reticle, never on top of it
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Move your phone slowly',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          _buildStartAgainPill(),
        ],
      ),
    );
  }

  Widget _buildLostTrackingGuidance() {
    return Align(
      alignment: const Alignment(
        0,
        0.25,
      ), // below the reticle, never on top of it
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Wireframe Perspective Plane with Phone
          CustomPaint(
            size: const Size(180, 80),
            painter: _PerspectivePlanePainter(),
          ),
          const SizedBox(height: 24),
          Text(
            'Return to the previous area to resume',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _buildStartAgainPill(),
        ],
      ),
    );
  }

  Widget _buildStartAgainPill() {
    return ApplePressable(
      onTap: _clearAllPoints,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Text(
          'Start Again',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ── Measurements Summary Modal Sheet ─────────────────────────────────

  void _showMeasurementsSummarySheet() {
    HapticFeedback.lightImpact();
    final areaSqFt = _canApplyAsWall
        ? _segmentMeters[0] * _segmentMeters[1] * _feetPerMeter * _feetPerMeter
        : null;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E).withValues(alpha: 0.94),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Measurements',
                  style: GoogleFonts.playfairDisplay(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                if (_segmentMeters.isEmpty)
                  Text(
                    'Aim at an object, tap + for the first point, move, tap + again.',
                    style: GoogleFonts.inter(
                      color: Colors.white60,
                      fontSize: 13,
                    ),
                  )
                else ...[
                  for (var i = 0; i < _segmentMeters.length; i++)
                    _buildSummaryRow(
                      'Segment ${i + 1}',
                      formatMeasureLength(_segmentMeters[i], _unit),
                    ),
                  const Divider(color: Colors.white12, height: 24),
                  _buildSummaryRow(
                    'Total',
                    formatMeasureLength(_totalMeters, _unit),
                  ),
                  for (final u in kMeasureUnits.where((u) => u != _unit))
                    _buildSummaryRow('', formatMeasureLength(_totalMeters, u)),
                  if (areaSqFt != null)
                    _buildSummaryRow(
                      'Area (seg 1 x seg 2)',
                      '${areaSqFt.toStringAsFixed(2)} sq.ft',
                    ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _sheetButton(
                        label: 'Copy',
                        filled: false,
                        enabled: _segmentMeters.isNotEmpty,
                        onTap: () {
                          Clipboard.setData(
                            ClipboardData(text: _measurementText),
                          );
                          Navigator.pop(ctx);
                          LuxuryToast.show(
                            context,
                            message: 'Measurements copied',
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _sheetButton(
                        label: 'Use as wall (W x H)',
                        filled: true,
                        enabled: _canApplyAsWall,
                        onTap: () {
                          Navigator.pop(ctx);
                          _finishAndExport();
                        },
                      ),
                    ),
                  ],
                ),
                if (!_canApplyAsWall && _segmentMeters.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      'Measure width and then height (2 segments) to use it as a wall.',
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheetButton({
    required String label,
    required bool filled,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return ApplePressable(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: filled
                ? const Color(0xFFC8A53C)
                : Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: filled ? Colors.black : Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Unit chips ───────────────────────────────────────────────────────

  Widget _buildUnitBar() {
    final top =
        MediaQuery.of(context).padding.top +
        66 +
        48; // below the top bar and the Back button
    final live = _liveMeters;
    final reading = live ?? (_anchorIds.isEmpty ? _probeDistance : null);
    return Positioned(
      top: top,
      left: 16,
      right: 16,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E).withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.14),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final u in kMeasureUnits)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _setUnit(u),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: u == _unit
                            ? const Color(0xFFC8A53C)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        u == 'in'
                            ? 'inch'
                            : u == 'ft'
                            ? 'feet'
                            : u,
                        style: GoogleFonts.inter(
                          color: u == _unit ? Colors.black : Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            live != null
                ? 'Tap + to add the next point'
                : (reading != null
                      ? 'Surface ${formatMeasureLength(reading, _unit)} away'
                      : 'Searching for a surface...'),
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              shadows: const [Shadow(blurRadius: 8, color: Colors.black87)],
            ),
          ),
          if (_segmentMeters.length > 1)
            Text(
              'Total ${formatMeasureLength(_totalMeters, _unit)}',
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 12,
                shadows: const [Shadow(blurRadius: 8, color: Colors.black87)],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(color: Colors.white60, fontSize: 13),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Painters ─────────────────────────────────────────────────────────────

/// Reticle: an open ring while searching, it eases into a tighter, brighter ring with a bigger dot once a real surface is locked.
class _AppleReticleWidget extends StatelessWidget {
  final bool locked;
  const _AppleReticleWidget({required this.locked});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: locked ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (_, t, _) => SizedBox(
        width: 140,
        height: 70,
        child: CustomPaint(painter: _ReticleShapePainter(t)),
      ),
    );
  }
}

class _ReticleShapePainter extends CustomPainter {
  final double lock; // 0 searching .. 1 locked on a surface
  _ReticleShapePainter(this.lock);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ring = Paint()
      ..color = Colors.white.withValues(alpha: 0.55 + 0.45 * lock)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4 + 0.8 * lock
      ..strokeCap = StrokeCap.round;
    final shrink = 1 - 0.16 * lock;
    final rect = Rect.fromCenter(
      center: center,
      width: (size.width - 6) * shrink,
      height: (size.height - 6) * shrink,
    );
    // The gaps close up as the ring locks
    final gap = 0.4 * (1 - lock);
    canvas.drawArc(rect, -0.4 + gap, 2.8 - 2 * gap, false, ring);
    canvas.drawArc(rect, 2.7 + gap, 2.8 - 2 * gap, false, ring);
    canvas.drawCircle(center, 4.0 + 2.0 * lock, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _ReticleShapePainter old) => old.lock != lock;
}

/// Ruler painter: pins and lines glued to the real object (screen positions come from the native anchors and are
/// eased every frame), a live line from the last pin to the reticle, real-world tick marks and a length badge per segment.
class _AppleRulerPainter extends CustomPainter {
  final List<Offset?> Function() pins;
  final List<int> Function() bornMs;
  final int Function() nowMs;
  final Offset? Function() reticle; // null when no surface is under the reticle
  final String Function() unit;
  final List<double> Function() segmentMeters;
  final double? Function() liveMeters;

  _AppleRulerPainter({
    required Listenable repaint,
    required this.pins,
    required this.bornMs,
    required this.nowMs,
    required this.reticle,
    required this.unit,
    required this.segmentMeters,
    required this.liveMeters,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final pts = pins();
    final segs = segmentMeters();
    final born = bornMs();
    final now = nowMs();
    final ret = reticle();
    final live = liveMeters();
    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..strokeWidth = 4.4
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i];
      final b = pts[i + 1];
      if (a == null || b == null || i >= segs.length) continue;
      _segment(
        canvas,
        a,
        b,
        segs[i],
        linePaint,
        shadow,
        fade: _pop(born, i + 1, now),
      );
    }
    // Live segment: last pin -> reticle
    final last = pts.isNotEmpty ? pts.last : null;
    if (last != null && ret != null && live != null) {
      _segment(canvas, last, ret, live, linePaint, shadow, isLive: true);
    }
    for (var i = 0; i < pts.length; i++) {
      final p = pts[i];
      if (p == null) continue;
      final k = _pop(born, i, now);
      canvas.drawCircle(
        p,
        9 * k,
        Paint()..color = Colors.black.withValues(alpha: 0.35),
      );
      canvas.drawCircle(p, 6.5 * k, Paint()..color = Colors.white);
    }
  }

  /// 0..1 pop-in (slight overshoot) for a pin that was just placed.
  double _pop(List<int> born, int i, int now) {
    if (i >= born.length) return 1;
    final t = ((now - born[i]) / 240).clamp(0.0, 1.0);
    return Curves.easeOutBack.transform(t);
  }

  /// Tick spacing that follows the real object: 1 mm / 5 mm / 1 cm / 5 cm / 10 cm ... whichever keeps ticks >= 8 px apart,
  /// so ticks stay put on the object while the phone moves instead of crawling.
  static double _stepMeters(double pxPerMeter) {
    for (final step in const [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1.0]) {
      if (step * pxPerMeter >= 8) return step;
    }
    return 1.0;
  }

  void _segment(
    Canvas canvas,
    Offset p1,
    Offset p2,
    double meters,
    Paint line,
    Paint shadow, {
    bool isLive = false,
    double fade = 1,
  }) {
    canvas.drawLine(p1, p2, shadow);
    canvas.drawLine(p1, p2, line);
    final dist = (p2 - p1).distance;
    if (dist < 24 || meters <= 0) return;
    final dir = (p2 - p1) / dist;
    final perp = Offset(-dir.dy, dir.dx);
    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 1.4;
    final step = _stepMeters(dist / meters);
    final count = (meters / step).floor();
    if (count <= 150) {
      for (var t = 1; t <= count; t++) {
        final c = p1 + dir * (dist * (t * step) / meters);
        if ((c - p2).distance < 6) continue;
        final major = t % 5 == 0;
        final len = major ? 7.0 : 4.0;
        canvas.drawLine(c - perp * len, c + perp * len, tickPaint);
      }
    }
    final text = formatMeasureLength(meters, unit());
    if (isLive) {
      // Live reading rides next to the reticle, never on top of the line's own ends
      _drawMeasurementBadge(canvas, p2 + const Offset(0, 62), text, 1);
    } else {
      _drawMeasurementBadge(canvas, (p1 + p2) / 2, text, fade);
    }
  }

  void _drawMeasurementBadge(
    Canvas canvas,
    Offset center,
    String text,
    double scale,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          fontFamily: 'Inter',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale.clamp(0.0, 1.2));
    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset.zero,
        width: textPainter.width + 18,
        height: textPainter.height + 10,
      ),
      const Radius.circular(16),
    );
    canvas.drawShadow(
      Path()..addRRect(rrect),
      Colors.black.withValues(alpha: 0.5),
      4,
      false,
    );
    canvas.drawRRect(rrect, Paint()..color = Colors.white);
    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -textPainter.height / 2),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AppleRulerPainter old) => true;
}

class _TooltipArrowPainter extends CustomPainter {
  final Color color;
  const _TooltipArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PerspectivePlanePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Perspective floor / wall wireframe trapezoid
    final path = Path()
      ..moveTo(size.width * 0.2, 0)
      ..lineTo(size.width * 0.8, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paint);

    // Phone outline in perspective
    final phoneRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width * 0.55, size.height * 0.5),
        width: 24,
        height: 48,
      ),
      const Radius.circular(5),
    );
    canvas.drawRRect(phoneRect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
