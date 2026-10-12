import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Available animated poses for Aarna AI character
enum AarnaPose {
  idle,         // Smiling head-shot / greeting
  searching,    // Holding magnifying glass inspecting / finding designs
  combinations, // Holding stone samples / palettes
  quote,        // Holding calculator / calculating price & estimate
  technical,    // Holding ruler / blueprints / 3D flutes
  waving,       // Waving both hands hello
}

/// A living, animated 3D character avatar widget for Aarna AI.
///
/// Real 3D Character Features:
/// 1. Continuous Hand Waving animation: The hand actively waves back & forth in real time!
/// 2. Conscious Eye Blink animation: Digital OLED screen eyes close and reopen every ~3.5s!
/// 3. True 3D Matrix4 perspective floating & gyro kinematics (pitch, yaw, roll levitation).
/// 4. Dynamic 3D holographic orbital gyro ring with depth-sorted orbiting photon bead.
/// 5. Continuous specular light sheen sweep highlighting 3D metallic marble contours.
/// 6. Active search radar sonar waves with horizontal inspection sweep.
/// 7. Interactive tactile 3D gyro tilt on drag / touch with spring-back physics.
class AarnaLivingAvatar extends StatefulWidget {
  final double size;
  final AarnaPose pose;
  final bool isSearching;
  final bool showRadarRings;
  final bool showSparkle;
  final bool showOnlineBadge;
  final bool showHologramRing;
  final bool enableInteractiveTilt;
  final BoxShape shape;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  const AarnaLivingAvatar({
    super.key,
    this.size = 48,
    this.pose = AarnaPose.idle,
    this.isSearching = false,
    this.showRadarRings = false,
    this.showSparkle = true,
    this.showOnlineBadge = true,
    this.showHologramRing = true,
    this.enableInteractiveTilt = true,
    this.shape = BoxShape.circle,
    this.borderRadius,
    this.onTap,
  });

  @override
  State<AarnaLivingAvatar> createState() => _AarnaLivingAvatarState();
}

class _AarnaLivingAvatarState extends State<AarnaLivingAvatar>
    with TickerProviderStateMixin {
  // 1. Kinetic floating & breathing levitation (2.4s)
  late final AnimationController _floatController;

  // 2. 3D Gyro perspective tilt (pitch, yaw, roll - 3.4s)
  late final AnimationController _gyroController;

  // 3. Hand wave motion controller (1.0s loop - waves hand back and forth!)
  late final AnimationController _waveController;

  // 4. Eye blink cycle (3.6s loop - blinks for ~180ms)
  late final AnimationController _blinkController;

  // 5. 3D Holographic orbital gyro ring & photon bead (2.8s)
  late final AnimationController _orbitController;

  // 6. Specular golden sheen light sweep (2.6s)
  late final AnimationController _sheenController;

  // 7. Active search & inspection scanner motion (1.3s)
  late final AnimationController _searchController;

  // 8. Expanding golden radar sonar waves (1.8s)
  late final AnimationController _radarController;

  // 9. Sparkling ambient star twinkle (3.0s)
  late final AnimationController _sparkleController;

  // 10. Interactive touch-drag tilt spring-back
  double _touchPitch = 0.0;
  double _touchYaw = 0.0;
  AnimationController? _springController;
  Animation<double>? _springPitchAnim;
  Animation<double>? _springYawAnim;

  @override
  void initState() {
    super.initState();

    // 1. Kinetic floating levitation (rhythmic up/down bobbing)
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    // 2. 3D Gyro rotation (continuous natural looking-around motion)
    _gyroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    )..repeat(reverse: true);

    // 3. Active hand wave motion (1.0s loop, reverse: true gives natural oscillation)
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    // 4. Conscious eye blink cycle (3.6s loop)
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();

    // 5. 3D Holographic orbital gyro ring
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();

    // 6. Specular golden sheen sweep
    _sheenController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();

    // 7. Active search sweep
    _searchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);

    // 8. Sonar radar waves
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    // 9. Sparkle twinkle
    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    // 10. Spring controller for tactile touch return
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _floatController.dispose();
    _gyroController.dispose();
    _waveController.dispose();
    _blinkController.dispose();
    _orbitController.dispose();
    _sheenController.dispose();
    _searchController.dispose();
    _radarController.dispose();
    _sparkleController.dispose();
    _springController?.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!widget.enableInteractiveTilt) return;
    setState(() {
      _touchYaw = (_touchYaw + details.delta.dx * 0.008).clamp(-0.28, 0.28);
      _touchPitch = (_touchPitch - details.delta.dy * 0.008).clamp(-0.24, 0.24);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (!widget.enableInteractiveTilt) return;
    final startPitch = _touchPitch;
    final startYaw = _touchYaw;

    _springPitchAnim = Tween<double>(begin: startPitch, end: 0.0).animate(
      CurvedAnimation(parent: _springController!, curve: Curves.elasticOut),
    );
    _springYawAnim = Tween<double>(begin: startYaw, end: 0.0).animate(
      CurvedAnimation(parent: _springController!, curve: Curves.elasticOut),
    );

    _springController!.reset();
    _springController!.forward();

    _springController!.addListener(() {
      if (mounted) {
        setState(() {
          _touchPitch = _springPitchAnim?.value ?? 0.0;
          _touchYaw = _springYawAnim?.value ?? 0.0;
        });
      }
    });
  }

  String _getAssetForPose(AarnaPose pose, double size, bool isBlinking) {
    if (pose == AarnaPose.idle || pose == AarnaPose.waving) {
      if (size >= 80) {
        return isBlinking
            ? 'assets/images/aarna/aarna_character_blink.png'
            : 'assets/images/aarna/aarna_character_clean.png';
      } else {
        return isBlinking
            ? 'assets/images/aarna/aarna_avatar_head_blink.png'
            : 'assets/images/aarna/aarna_avatar_head.png';
      }
    }

    switch (pose) {
      case AarnaPose.searching:
        return 'assets/images/aarna/aarna_pose_designs.png';
      case AarnaPose.combinations:
        return 'assets/images/aarna/aarna_pose_combinations.png';
      case AarnaPose.quote:
        return 'assets/images/aarna/aarna_pose_quote.png';
      case AarnaPose.technical:
        return 'assets/images/aarna/aarna_pose_technical.png';
      default:
        return 'assets/images/aarna/aarna_character_clean.png';
    }
  }

  Alignment _getAlignmentForPose(AarnaPose pose, double size) {
    switch (pose) {
      case AarnaPose.searching:
        return const Alignment(0.12, -0.05);
      case AarnaPose.combinations:
        return const Alignment(0.08, 0.0);
      case AarnaPose.quote:
        return const Alignment(0.08, 0.0);
      case AarnaPose.technical:
        return Alignment.center;
      case AarnaPose.waving:
      case AarnaPose.idle:
      default:
        if (size >= 80) {
          return const Alignment(0.0, -0.15); // Show expressive head & torso
        }
        return Alignment.center;
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectivePose = widget.isSearching ? AarnaPose.searching : widget.pose;
    final isSearchActive = widget.isSearching || widget.pose == AarnaPose.searching;

    final isCircle = widget.shape == BoxShape.circle;
    final r = widget.size / 2;
    final effectiveBorderRadius = widget.borderRadius ??
        (isCircle ? BorderRadius.circular(r) : BorderRadius.circular(16));

    final showHoloRing = widget.showHologramRing && widget.size >= 36;
    final isLargeDisplay = widget.size >= 80;

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        if (widget.onTap != null) {
          widget.onTap!();
        }
      },
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // ── 1. Expanding Golden Radar Sonar Rings (during active search) ──
            if ((widget.showRadarRings || isSearchActive) && isCircle)
              AnimatedBuilder(
                animation: _radarController,
                builder: (context, _) {
                  return CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: _RadarWavePainter(
                      progress: _radarController.value,
                      baseRadius: r,
                    ),
                  );
                },
              ),

            // ── 2. Ambient 3D Backlight / Radial Aura ──
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _floatController,
                builder: (context, _) {
                  final auraPulse = 0.75 + (math.sin(_floatController.value * math.pi) * 0.25);
                  return Container(
                    decoration: BoxDecoration(
                      shape: widget.shape,
                      borderRadius: isCircle ? null : effectiveBorderRadius,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD4AF37).withValues(
                            alpha: (isSearchActive ? 0.65 : 0.40) * auraPulse,
                          ),
                          blurRadius: isSearchActive ? 22 : (widget.size > 70 ? 20 : 12),
                          spreadRadius: isSearchActive ? 3 : (widget.size > 70 ? 2 : 1),
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // ── 3. 3D Holographic Orbital Gyro Ring (Back Arc - passes behind character) ──
            if (showHoloRing)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _orbitController,
                  builder: (context, _) {
                    return CustomPaint(
                      size: Size(widget.size, widget.size),
                      painter: _HologramGyroPainter(
                        orbitProgress: _orbitController.value,
                        isFrontPass: false,
                        accentColor: const Color(0xFFFFDF73),
                      ),
                    );
                  },
                ),
              ),

            // ── 4. Main 3D Living Character Chamber & Frame ──
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: widget.shape,
                borderRadius: isCircle ? null : effectiveBorderRadius,
                gradient: const RadialGradient(
                  center: Alignment(-0.25, -0.3),
                  radius: 0.95,
                  colors: [
                    Color(0xFFFFF0B3), // Luminous champagne specular highlight
                    Color(0xFFD4AF37), // Regal Grazia Gold
                    Color(0xFF7A5207), // Deep antique bronze border
                  ],
                ),
              ),
              padding: EdgeInsets.all(widget.size > 60 ? 2.5 : 2.0),
              child: Container(
                decoration: BoxDecoration(
                  shape: widget.shape,
                  borderRadius: isCircle
                      ? null
                      : BorderRadius.circular(
                          math.max(0, effectiveBorderRadius.topLeft.x - 2.5),
                        ),
                  color: const Color(0xFF131316),
                ),
                clipBehavior: Clip.antiAlias,
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    _floatController,
                    _gyroController,
                    _waveController,
                    _blinkController,
                    _searchController,
                    _sheenController,
                  ]),
                  builder: (context, _) {
                    final floatVal = _floatController.value;
                    final gyroVal = _gyroController.value;
                    final waveVal = _waveController.value;
                    final blinkCycle = _blinkController.value;
                    final searchVal = _searchController.value;
                    final sheenVal = _sheenController.value;

                    // ── A. True 3D Floating Kinematics ──
                    final levitationDy = (math.sin(floatVal * math.pi * 2) * 5.2);
                    final breathingScale = 1.0 + (math.sin(floatVal * math.pi * 2) * 0.035);

                    // ── B. True 3D Gyro Perspective Rotation ──
                    final pitch = (math.sin(gyroVal * math.pi * 2) * 0.11) + _touchPitch;
                    final yaw = (math.cos(gyroVal * math.pi * 2) * 0.16) + _touchYaw;
                    final roll = (math.sin(gyroVal * math.pi * 2) * 0.045);

                    // Active Search Kinematics
                    final searchDx = isSearchActive
                        ? (math.sin(searchVal * math.pi * 2) * 4.8)
                        : 0.0;
                    final searchPitch = isSearchActive ? 0.08 : 0.0;
                    final searchYaw = isSearchActive
                        ? (0.12 + math.sin(searchVal * math.pi * 2) * 0.08)
                        : 0.0;

                    // ── C. Real Eye Blink Detection ──
                    // Natural 180ms blink every ~3.6s
                    final isBlinking = blinkCycle > 0.94 && blinkCycle < 0.985;
                    final assetPath = _getAssetForPose(effectivePose, widget.size, isBlinking);
                    final alignment = _getAlignmentForPose(effectivePose, widget.size);

                    // ── D. Continuous Hand Waving Kinematics ──
                    // Hand waves naturally with smooth sine wave rotation around the shoulder pivot
                    final waveAngle = math.sin(waveVal * math.pi * 2) * 0.18; // ~10 degrees wave
                    final waveDx = math.cos(waveVal * math.pi * 2) * 1.5;
                    final waveDy = math.sin(waveVal * math.pi * 2) * 2.0;

                    // Matrix4 with genuine 3D perspective depth (setEntry 3,2)
                    final matrix = Matrix4.identity()
                      ..setEntry(3, 2, 0.0022)
                      ..translate(searchDx, levitationDy, 0.0)
                      ..rotateX(pitch + searchPitch)
                      ..rotateY(yaw + searchYaw)
                      ..rotateZ(roll)
                      ..scale(breathingScale);

                    return Transform(
                      alignment: Alignment.center,
                      transform: matrix,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // 1. Main Character Body & Head (Blinks naturally!)
                          Image.asset(
                            assetPath,
                            key: ValueKey<String>(assetPath),
                            fit: BoxFit.cover,
                            alignment: alignment,
                            errorBuilder: (context, error, stackTrace) =>
                                Image.asset(
                              'assets/images/aarna/aarna_avatar_head.png',
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                              errorBuilder: (_, _, _) => Container(
                                color: const Color(0xFF16161A),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.auto_awesome,
                                  color: Color(0xFFD4AF37),
                                  size: 24,
                                ),
                              ),
                            ),
                          ),

                          // 2. Real Articulated Waving Hand Layer (for large character displays)
                          if (isLargeDisplay &&
                              (effectivePose == AarnaPose.idle ||
                                  effectivePose == AarnaPose.waving))
                            Positioned.fill(
                              child: Transform(
                                alignment: const Alignment(0.48, 0.38), // Shoulder joint pivot
                                transform: Matrix4.identity()
                                  ..translate(waveDx, waveDy, 0.0)
                                  ..rotateZ(waveAngle),
                                child: Image.asset(
                                  'assets/images/aarna/aarna_arm_layer.png',
                                  fit: BoxFit.cover,
                                  alignment: alignment,
                                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                                ),
                              ),
                            ),

                          // 3. Cinema 4D Specular Golden Light Sweep (Motion Graphics)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _SpecularLightSweepPainter(
                                  progress: sheenVal,
                                  glowColor: const Color(0xFFFFDF73),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            // ── 5. 3D Holographic Orbital Gyro Ring (Front Arc - passes in front of character) ──
            if (showHoloRing)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _orbitController,
                    builder: (context, _) {
                      return CustomPaint(
                        size: Size(widget.size, widget.size),
                        painter: _HologramGyroPainter(
                          orbitProgress: _orbitController.value,
                          isFrontPass: true,
                          accentColor: const Color(0xFFFFDF73),
                        ),
                      );
                    },
                  ),
                ),
              ),

            // ── 6. Golden Twinkling Sparkle Star (Top-Right) ──
            if (widget.showSparkle)
              Positioned(
                top: isCircle ? -1 : 2,
                right: isCircle ? -1 : 2,
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _sparkleController,
                    builder: (context, _) {
                      final t = _sparkleController.value;
                      final scale = 0.85 + (math.sin(t * 2 * math.pi) * 0.22);
                      final angle = t * 2 * math.pi;

                      return Transform.scale(
                        scale: scale,
                        child: Transform.rotate(
                          angle: angle,
                          child: Container(
                            padding: const EdgeInsets.all(2.5),
                            decoration: const BoxDecoration(
                              color: Color(0xFF141418),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xFFD4AF37),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.auto_awesome,
                              color: const Color(0xFFFFDF73),
                              size: widget.size > 60 ? 14 : 10,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

            // ── 7. Pulsing Emerald Online Intelligence Badge (Bottom-Right) ──
            if (widget.showOnlineBadge)
              Positioned(
                bottom: isCircle ? 1 : 2,
                right: isCircle ? 1 : 2,
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _floatController,
                    builder: (context, _) {
                      final pulse = 0.90 + (math.sin(_floatController.value * math.pi * 2) * 0.15);
                      final badgeSize = math.max(10.0, widget.size * 0.22);
                      return Transform.scale(
                        scale: pulse,
                        child: Container(
                          width: badgeSize,
                          height: badgeSize,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF141416),
                              width: 1.8,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withValues(alpha: 0.65),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 3D Holographic Gyro Ring Painter:
/// Renders an inclined 3D elliptical gyro orbit with depth sorting (front/back pass)
/// and a glowing golden orbiting photon bead.
class _HologramGyroPainter extends CustomPainter {
  final double orbitProgress; // 0.0 to 1.0
  final bool isFrontPass;
  final Color accentColor;

  _HologramGyroPainter({
    required this.orbitProgress,
    required this.isFrontPass,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final rx = (size.width / 2) + 6.0;
    final ry = rx * 0.45; // 3D tilt perspective compression

    // 3D Tilt angle for the gyro ring: -22 degrees inclination
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(-math.pi / 7.5);

    // Orbit angle in radians (0 to 2*pi)
    final angle = orbitProgress * 2 * math.pi;

    final isFrontHalf = math.sin(angle) >= 0;

    final rect = Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2);
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isFrontPass ? 1.4 : 0.9;

    if (isFrontPass) {
      ringPaint.shader = SweepGradient(
        colors: [
          accentColor.withValues(alpha: 0.0),
          accentColor.withValues(alpha: 0.6),
          const Color(0xFFFFFFFF).withValues(alpha: 0.9),
          accentColor.withValues(alpha: 0.2),
          accentColor.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
        transform: GradientRotation(angle),
      ).createShader(rect);

      canvas.drawArc(rect, 0, math.pi, false, ringPaint);

      if (isFrontHalf) {
        final bx = rx * math.cos(angle);
        final by = ry * math.sin(angle);
        final beadPos = Offset(bx, by);

        canvas.drawCircle(
          beadPos,
          3.8,
          Paint()..color = accentColor.withValues(alpha: 0.8),
        );
        canvas.drawCircle(
          beadPos,
          1.8,
          Paint()..color = Colors.white,
        );
      }
    } else {
      ringPaint.color = accentColor.withValues(alpha: 0.25);
      canvas.drawArc(rect, math.pi, math.pi, false, ringPaint);

      if (!isFrontHalf) {
        final bx = rx * math.cos(angle);
        final by = ry * math.sin(angle);
        final beadPos = Offset(bx, by);

        canvas.drawCircle(
          beadPos,
          2.0,
          Paint()..color = accentColor.withValues(alpha: 0.4),
        );
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HologramGyroPainter oldDelegate) {
    return oldDelegate.orbitProgress != orbitProgress ||
        oldDelegate.isFrontPass != isFrontPass;
  }
}

/// Specular Light Sheen Painter:
/// Sweeps a brilliant diagonal 3D metallic light sheen across the character.
class _SpecularLightSweepPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final Color glowColor;

  _SpecularLightSweepPainter({
    required this.progress,
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final sweepOffset = -w + (progress * 2.5 * w);

    final rect = Rect.fromLTWH(0, 0, w, h);
    final paint = Paint()
      ..blendMode = BlendMode.screen
      ..shader = LinearGradient(
        begin: const Alignment(-1.0, -1.0),
        end: const Alignment(1.0, 1.0),
        colors: [
          Colors.transparent,
          glowColor.withValues(alpha: 0.05),
          const Color(0xFFFFFFFF).withValues(alpha: 0.42),
          glowColor.withValues(alpha: 0.15),
          Colors.transparent,
        ],
        stops: [
          (sweepOffset / (2 * w)).clamp(0.0, 1.0),
          ((sweepOffset + 18) / (2 * w)).clamp(0.0, 1.0),
          ((sweepOffset + 36) / (2 * w)).clamp(0.0, 1.0),
          ((sweepOffset + 54) / (2 * w)).clamp(0.0, 1.0),
          ((sweepOffset + 72) / (2 * w)).clamp(0.0, 1.0),
        ],
      ).createShader(rect);

    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _SpecularLightSweepPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Custom painter for golden scanning radar ripples around living Aarna
class _RadarWavePainter extends CustomPainter {
  final double progress;
  final double baseRadius;

  _RadarWavePainter({required this.progress, required this.baseRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (int i = 0; i < 2; i++) {
      final p = (progress + (i * 0.5)) % 1.0;
      final radius = baseRadius + (p * 14.0);
      final alpha = ((1.0 - p) * 0.50).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = const Color(0xFFD4AF37).withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3 * (1.0 - p);

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarWavePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
