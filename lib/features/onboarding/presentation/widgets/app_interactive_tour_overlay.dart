import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grazia_stones/core/services/storage_service.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/widgets/grazia_bottom_nav.dart';

/// True spotlight overlay that highlights the actual on-screen widgets
/// with dynamic transparent punch-out cutouts, pulsing gold halos,
/// and anchored contextual tooltips pointing directly to the active feature.
class AppInteractiveTourOverlay extends StatefulWidget {
  final VoidCallback onDismiss;
  final LuxuryPalette palette;
  final GlobalKey? arKey;
  final GlobalKey? addKey;

  const AppInteractiveTourOverlay({
    super.key,
    required this.onDismiss,
    required this.palette,
    this.arKey,
    this.addKey,
  });

  @override
  State<AppInteractiveTourOverlay> createState() => _AppInteractiveTourOverlayState();
}

class _AppInteractiveTourOverlayState extends State<AppInteractiveTourOverlay>
    with SingleTickerProviderStateMixin {
  static const gold = Color(0xFFD4AF37);
  int _currentStep = 0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final List<Map<String, dynamic>> _steps = [
    {
      'stepNum': '1 OF 4',
      'category': 'AI WALL ARCHITECTURE',
      'title': 'AI Room Visualizer Studio',
      'subtitle':
          'Tap this glowing gold center button anytime to upload a photo of your room or facade. Our AI instantly renders real natural stone textures onto your walls in seconds.',
      'icon': Icons.auto_awesome_rounded,
      'targetType': 'ai_center',
      'targetLabel': 'Center Floating AI Studio Button',
    },
    {
      'stepNum': '2 OF 4',
      'category': 'IMMERSIVE AR CAMERA',
      'title': 'Live Augmented Reality (AR)',
      'subtitle':
          'Tap [AR] on any stone to launch live camera mode and preview authentic stone wall patterns directly on your physical room walls at 1:1 architectural scale.',
      'icon': Icons.view_in_ar_rounded,
      'targetType': 'ar_button',
      'targetLabel': 'AR Live Camera Button on Stone Card',
    },
    {
      'stepNum': '3 OF 4',
      'category': 'SAMPLE & PROJECT ORDERING',
      'title': 'Instant Sample & Project Cart',
      'subtitle':
          'Tap [+ Add] to order physical hand-carved stone samples delivered directly to your site, or calculate square-foot requirements for your project.',
      'icon': Icons.shopping_bag_outlined,
      'targetType': 'add_button',
      'targetLabel': '+ Add to Cart & Sample Ordering',
    },
    {
      'stepNum': '4 OF 4',
      'category': 'CURATED ARCHITECTURE',
      'title': '36+ Curated Collections',
      'subtitle':
          'Explore all 36 bespoke design series — from 3D fluted relief and monolithic split ledges to Egyptian and Roman heritage stones.',
      'icon': Icons.grid_view_rounded,
      'targetType': 'collections_tab',
      'targetLabel': 'Collections Tab in Bottom Navigation',
    },
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _finishTour() {
    HapticFeedback.mediumImpact();
    StorageService.instance.setHasSeenAppTour(true);
    widget.onDismiss();
  }

  void _nextStep() {
    HapticFeedback.lightImpact();
    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
    } else {
      _finishTour();
    }
  }

  /// Calculates the spotlight punch-out rect for the active step.
  _SpotlightTarget _getTarget(Size screenSize, double bottomPadding) {
    final navY = screenSize.height - (bottomPadding > 0 ? bottomPadding + 6 : 14) - 32;

    switch (_currentStep) {
      case 0:
        // Center AI Studio button
        final aiBox = GraziaBottomNav.aiStudioKey.currentContext?.findRenderObject() as RenderBox?;
        if (aiBox != null && aiBox.hasSize) {
          final pos = aiBox.localToGlobal(Offset.zero);
          final rect = Rect.fromLTWH(pos.dx - 4, pos.dy - 4, aiBox.size.width + 8, aiBox.size.height + 8);
          return _SpotlightTarget(
            rect: rect,
            isCircle: true,
            borderRadius: rect.width / 2,
            pointerDirection: _PointerDirection.down,
            tooltipPosition: _TooltipPlacement.aboveTarget,
            targetCenter: rect.center,
          );
        }
        final center = Offset(screenSize.width / 2, navY);
        return _SpotlightTarget(
          rect: Rect.fromCircle(center: center, radius: 28),
          isCircle: true,
          borderRadius: 28,
          pointerDirection: _PointerDirection.down,
          tooltipPosition: _TooltipPlacement.aboveTarget,
          targetCenter: center,
        );

      case 1:
        // AR Button on the first product card
        final box = widget.arKey?.currentContext?.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize) {
          final pos = box.localToGlobal(Offset.zero);
          final rect = Rect.fromLTWH(pos.dx - 4, pos.dy - 3, box.size.width + 8, box.size.height + 6);
          final isAbove = pos.dy > screenSize.height * 0.42;
          return _SpotlightTarget(
            rect: rect,
            isCircle: false,
            borderRadius: 14,
            pointerDirection: isAbove ? _PointerDirection.down : _PointerDirection.up,
            tooltipPosition: isAbove ? _TooltipPlacement.aboveTarget : _TooltipPlacement.belowTarget,
            targetCenter: rect.center,
          );
        }
        // Responsive fallback
        final fallbackRect = Rect.fromLTWH(22, screenSize.height * 0.58, 52, 26);
        return _SpotlightTarget(
          rect: fallbackRect,
          isCircle: false,
          borderRadius: 14,
          pointerDirection: _PointerDirection.down,
          tooltipPosition: _TooltipPlacement.aboveTarget,
          targetCenter: fallbackRect.center,
        );

      case 2:
        // + Add button on the first product card
        final box = widget.addKey?.currentContext?.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize) {
          final pos = box.localToGlobal(Offset.zero);
          final rect = Rect.fromLTWH(pos.dx - 4, pos.dy - 3, box.size.width + 8, box.size.height + 6);
          final isAbove = pos.dy > screenSize.height * 0.42;
          return _SpotlightTarget(
            rect: rect,
            isCircle: false,
            borderRadius: 14,
            pointerDirection: isAbove ? _PointerDirection.down : _PointerDirection.up,
            tooltipPosition: isAbove ? _TooltipPlacement.aboveTarget : _TooltipPlacement.belowTarget,
            targetCenter: rect.center,
          );
        }
        final fallbackRect = Rect.fromLTWH(screenSize.width * 0.35, screenSize.height * 0.58, 68, 26);
        return _SpotlightTarget(
          rect: fallbackRect,
          isCircle: false,
          borderRadius: 14,
          pointerDirection: _PointerDirection.down,
          tooltipPosition: _TooltipPlacement.aboveTarget,
          targetCenter: fallbackRect.center,
        );

      case 3:
        // Collections Tab on bottom nav
        final collBox = GraziaBottomNav.collectionsKey.currentContext?.findRenderObject() as RenderBox?;
        if (collBox != null && collBox.hasSize) {
          final pos = collBox.localToGlobal(Offset.zero);
          final rect = Rect.fromLTWH(pos.dx - 4, pos.dy - 4, collBox.size.width + 8, collBox.size.height + 8);
          return _SpotlightTarget(
            rect: rect,
            isCircle: true,
            borderRadius: rect.width / 2,
            pointerDirection: _PointerDirection.down,
            tooltipPosition: _TooltipPlacement.aboveTarget,
            targetCenter: rect.center,
          );
        }
        final navWidth = screenSize.width - 36;
        final collectionsX = 18 + navWidth * (2.0 / 6.0);
        final collCenter = Offset(collectionsX, navY);
        return _SpotlightTarget(
          rect: Rect.fromCircle(center: collCenter, radius: 26),
          isCircle: true,
          borderRadius: 26,
          pointerDirection: _PointerDirection.down,
          tooltipPosition: _TooltipPlacement.aboveTarget,
          targetCenter: collCenter,
        );

      default:
        return _SpotlightTarget(
          rect: Rect.fromCircle(center: Offset(screenSize.width / 2, navY), radius: 28),
          isCircle: true,
          borderRadius: 28,
          pointerDirection: _PointerDirection.down,
          tooltipPosition: _TooltipPlacement.aboveTarget,
          targetCenter: Offset(screenSize.width / 2, navY),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final step = _steps[_currentStep];
    final isLast = _currentStep == _steps.length - 1;
    final target = _getTarget(screenSize, bottomPadding);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // 1. Semi-transparent backdrop with true punch-out hole over the physical button
          Positioned.fill(
            child: GestureDetector(
              onTap: _nextStep,
              behavior: HitTestBehavior.opaque,
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _SpotlightHolePainter(
                      target: target,
                      pulseValue: _pulseAnimation.value,
                      overlayColor: Colors.black.withValues(alpha: 0.70),
                      glowColor: gold,
                    ),
                  );
                },
              ),
            ),
          ),

          // 2. Top Header Bar (Guide Badge & Skip Tour Button)
          Positioned(
            top: topPadding + 10,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Interactive Guide Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1A18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: gold.withValues(alpha: 0.7),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.touch_app_rounded, size: 14, color: gold),
                      const SizedBox(width: 6),
                      Text(
                        'INTERACTIVE TOUR',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: gold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Skip Tour Button
                GestureDetector(
                  onTap: _finishTour,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1A18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Skip Tour',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.close_rounded, size: 14, color: Colors.white70),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Anchored Contextual Tooltip Card
          _buildContextualTooltip(
            screenSize: screenSize,
            bottomPadding: bottomPadding,
            target: target,
            step: step,
            isLast: isLast,
            gold: gold,
          ),
        ],
      ),
    );
  }

  Widget _buildContextualTooltip({
    required Size screenSize,
    required double bottomPadding,
    required _SpotlightTarget target,
    required Map<String, dynamic> step,
    required bool isLast,
    required Color gold,
  }) {
    final isAbove = target.tooltipPosition == _TooltipPlacement.aboveTarget;
    // Card has left: 16, right: 16. Arrow width is 20 (half-width = 10).
    final arrowLeft = (target.targetCenter.dx - 16 - 10).clamp(20.0, screenSize.width - 32 - 40.0);

    return Positioned(
      left: 16,
      right: 16,
      bottom: isAbove
          ? (screenSize.height - target.rect.top + 14)
          : null,
      top: !isAbove
          ? (target.rect.bottom + 14)
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Arrow pointing UP to target above
          if (!isAbove) ...[
            Padding(
              padding: EdgeInsets.only(left: arrowLeft),
              child: CustomPaint(
                size: const Size(20, 10),
                painter: _TrianglePainter(
                  isUp: true,
                  color: const Color(0xFF181615),
                  strokeColor: gold.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],

          // Luxury Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF181615),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: gold.withValues(alpha: 0.55),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.65),
                  blurRadius: 28,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: gold.withValues(alpha: 0.12),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Category & Step Pills
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: gold.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: gold.withValues(alpha: 0.4)),
                          ),
                          child: Icon(step['icon'] as IconData, size: 15, color: gold),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          step['category'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                            color: gold,
                          ),
                        ),
                      ],
                    ),

                    // Step indicator dots
                    Row(
                      children: List.generate(_steps.length, (i) {
                        final isActive = i == _currentStep;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2.5),
                          width: isActive ? 18 : 6,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isActive ? gold : Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Title
                Text(
                  step['title'] as String,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),

                // Subtitle
                Text(
                  step['subtitle'] as String,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: const Color(0xFFD4CEBE),
                    height: 1.42,
                  ),
                ),
                const SizedBox(height: 14),

                // Target Label Chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.my_location_rounded, size: 11, color: gold),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          step['targetLabel'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Next Step Button
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _nextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: gold,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isLast ? 'Start Exploring Grazia ✨' : 'Next Step →',
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Arrow pointing DOWN to target below
          if (isAbove) ...[
            Padding(
              padding: EdgeInsets.only(left: arrowLeft),
              child: CustomPaint(
                size: const Size(20, 10),
                painter: _TrianglePainter(
                  isUp: false,
                  color: const Color(0xFF181615),
                  strokeColor: gold.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _TooltipPlacement { aboveTarget, belowTarget }
enum _PointerDirection { up, down }

class _SpotlightTarget {
  final Rect rect;
  final bool isCircle;
  final double borderRadius;
  final _PointerDirection pointerDirection;
  final _TooltipPlacement tooltipPosition;
  final Offset targetCenter;

  const _SpotlightTarget({
    required this.rect,
    required this.isCircle,
    required this.borderRadius,
    required this.pointerDirection,
    required this.tooltipPosition,
    required this.targetCenter,
  });
}

/// Paints the dimmed screen with a transparent cutout over the target widget
/// and glowing pulsing borders.
class _SpotlightHolePainter extends CustomPainter {
  final _SpotlightTarget target;
  final double pulseValue;
  final Color overlayColor;
  final Color glowColor;

  _SpotlightHolePainter({
    required this.target,
    required this.pulseValue,
    required this.overlayColor,
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Full screen path
    final screenPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // 2. Cutout target path
    final targetPath = Path();
    if (target.isCircle) {
      targetPath.addOval(target.rect);
    } else {
      targetPath.addRRect(
        RRect.fromRectAndRadius(target.rect, Radius.circular(target.borderRadius)),
      );
    }

    // 3. Subtract target from screen path (Punchout)
    final cutoutPath = Path.combine(PathOperation.difference, screenPath, targetPath);

    // 4. Fill darkened screen background
    final darkPaint = Paint()..color = overlayColor;
    canvas.drawPath(cutoutPath, darkPaint);

    // 5. Draw inner pulsing golden border
    final innerBorderPaint = Paint()
      ..color = glowColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    if (target.isCircle) {
      canvas.drawOval(target.rect, innerBorderPaint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(target.rect, Radius.circular(target.borderRadius)),
        innerBorderPaint,
      );
    }

    // 6. Draw outer beacon pulsing wave ring
    final waveOffset = 6.0 * pulseValue;
    final waveAlpha = (0.50 * (1.0 - pulseValue)).clamp(0.0, 1.0);
    final wavePaint = Paint()
      ..color = glowColor.withValues(alpha: waveAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final outerRect = target.rect.inflate(waveOffset);
    if (target.isCircle) {
      canvas.drawOval(outerRect, wavePaint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(outerRect, Radius.circular(target.borderRadius + waveOffset)),
        wavePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpotlightHolePainter oldDelegate) => true;
}

class _TrianglePainter extends CustomPainter {
  final bool isUp;
  final Color color;
  final Color strokeColor;

  _TrianglePainter({
    required this.isUp,
    required this.color,
    required this.strokeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (isUp) {
      path.moveTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
      path.close();
    } else {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width / 2, size.height);
      path.close();
    }

    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) => false;
}
