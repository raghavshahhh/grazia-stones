import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grazia_stones/core/services/storage_service.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/widgets/grazia_bottom_nav.dart';

/// Ultra-luxury Apple-grade interactive tour overlay.
/// 
/// Highlights live on-screen widgets with precision cutout apertures,
/// luminous double-ring gold halo pulses, frosted glassmorphic cards,
/// segmented progress indicators, and fluid step-by-step navigation.
class AppInteractiveTourOverlay extends StatefulWidget {
  final VoidCallback onDismiss;
  final LuxuryPalette palette;
  final GlobalKey? arKey;
  final GlobalKey? addKey;
  final GlobalKey? mayaKey;
  final GlobalKey? collectionsKey;

  const AppInteractiveTourOverlay({
    super.key,
    required this.onDismiss,
    required this.palette,
    this.arKey,
    this.addKey,
    this.mayaKey,
    this.collectionsKey,
  });

  @override
  State<AppInteractiveTourOverlay> createState() => _AppInteractiveTourOverlayState();
}

class _AppInteractiveTourOverlayState extends State<AppInteractiveTourOverlay>
    with SingleTickerProviderStateMixin {
  static const gold = Color(0xFFD4AF37);
  static const goldLuminous = Color(0xFFFFD700);

  int _currentStep = 0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final List<Map<String, dynamic>> _steps = [
    {
      'stepNum': '1 OF 4',
      'category': 'AI WALL ARCHITECTURE',
      'badge': 'AI STUDIO',
      'title': 'AI Room Visualizer Studio',
      'subtitle':
          'Tap this glowing gold center button anytime to upload a photo of your room or facade. Our AI instantly renders real natural stone textures onto your walls in seconds.',
      'icon': Icons.auto_awesome_rounded,
      'targetType': 'ai_center',
      'targetLabel': 'Center Floating AI Studio Button',
      'chips': ['📸 Room Photo', '✨ Instant 4K Render', '⚡ Real Textures'],
    },
    {
      'stepNum': '2 OF 4',
      'category': 'MEET MAYA • ARCHITECTURAL CONSULTANT',
      'badge': '24/7 AI GUIDE',
      'title': 'Meet Maya — Your AI Design Consultant',
      'subtitle':
          'Namaste! Main hoon Maya — Grazia Stones ki 24/7 AI Architectural Consultant. Poochiye mujhse Hindi ya English me — "living room ke liye premium stone designs", "villa exterior cladding", ya "budget estimates". Main 35 collections me se perfect design recommend karungi!',
      'icon': Icons.smart_toy_rounded,
      'targetType': 'maya_app_bar',
      'targetLabel': 'Maya AI in Top Navigation Bar',
      'chips': ['🛋️ Living Room Wall', '🏛️ Villa Facade', '📐 3D Fluted Panels'],
    },
    {
      'stepNum': '3 OF 4',
      'category': 'CURATED ARCHITECTURE',
      'badge': '35 SERIES',
      'title': '35 Curated Design Collections',
      'subtitle':
          'Explore all 35 bespoke design series — from 3D fluted relief and monolithic split ledges to Egyptian and Roman heritage stones.',
      'icon': Icons.grid_view_rounded,
      'targetType': 'curated_collections',
      'targetLabel': 'Curated Collections (35 Series)',
      'chips': ['🏛️ 35 Bespoke Series', '🏺 Heritage Split Ledge', '📐 Monolithic Flutes'],
    },
    {
      'stepNum': '4 OF 4',
      'category': 'REAL-TIME 3D & AR',
      'badge': 'SPATIAL AR',
      'title': 'Live AR Wall Visualizer',
      'subtitle':
          'Experience real-scale stone slabs projected onto your physical walls in real-time with camera detection and LiDAR accuracy.',
      'icon': Icons.view_in_ar_rounded,
      'targetType': 'ar_tab',
      'targetLabel': 'AR Tab in Bottom Navigation',
      'chips': ['📱 Real-Scale 3D', '📐 LiDAR Wall Detection', '🔄 360° Material Rotation'],
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

  void _prevStep() {
    HapticFeedback.lightImpact();
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  void _openMaya() {
    HapticFeedback.mediumImpact();
    _finishTour();
    context.push('/maya-ai');
  }

  /// Calculates the spotlight punch-out rect for the active step.
  _SpotlightTarget _getTarget(Size screenSize, double bottomPadding) {
    final navY = screenSize.height - (bottomPadding > 0 ? bottomPadding + 6 : 14) - 32;
    final topPadding = MediaQuery.of(context).padding.top;

    switch (_currentStep) {
      case 0:
        // Step 1: Center AI Studio button
        final aiBox = GraziaBottomNav.aiStudioKey.currentContext?.findRenderObject() as RenderBox?;
        if (aiBox != null && aiBox.hasSize) {
          final pos = aiBox.localToGlobal(Offset.zero);
          if (pos.dy > 0 && pos.dy < screenSize.height) {
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
        // Step 2: Maya AI Assistant Avatar in top AppBar
        final box = widget.mayaKey?.currentContext?.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize) {
          final pos = box.localToGlobal(Offset.zero);
          final center = Offset(pos.dx + box.size.width / 2, pos.dy + box.size.height / 2);
          final rect = Rect.fromCircle(center: center, radius: 25);
          return _SpotlightTarget(
            rect: rect,
            isCircle: true,
            borderRadius: 25,
            pointerDirection: _PointerDirection.up,
            tooltipPosition: _TooltipPlacement.belowTarget,
            targetCenter: center,
          );
        }
        // Fallback: Top right AppBar action button area
        final fallbackCenter = Offset(screenSize.width - 150, topPadding + 28);
        return _SpotlightTarget(
          rect: Rect.fromCircle(center: fallbackCenter, radius: 25),
          isCircle: true,
          borderRadius: 25,
          pointerDirection: _PointerDirection.up,
          tooltipPosition: _TooltipPlacement.belowTarget,
          targetCenter: fallbackCenter,
        );

      case 2:
        // Step 3: Curated Collections (35 Series)
        final box = (widget.collectionsKey ?? GraziaBottomNav.collectionsKey).currentContext?.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize) {
          final pos = box.localToGlobal(Offset.zero);
          if (pos.dy > 0 && pos.dy < screenSize.height) {
            final center = Offset(pos.dx + box.size.width / 2, pos.dy + box.size.height / 2);
            final rect = Rect.fromCircle(center: center, radius: 28);
            return _SpotlightTarget(
              rect: rect,
              isCircle: true,
              borderRadius: 28,
              pointerDirection: _PointerDirection.down,
              tooltipPosition: _TooltipPlacement.aboveTarget,
              targetCenter: center,
            );
          }
        }
        final navWidth = screenSize.width - 36;
        final collX = 18 + navWidth * (1.5 / 5.0);
        final collCenter = Offset(collX, navY);
        return _SpotlightTarget(
          rect: Rect.fromCircle(center: collCenter, radius: 28),
          isCircle: true,
          borderRadius: 28,
          pointerDirection: _PointerDirection.down,
          tooltipPosition: _TooltipPlacement.aboveTarget,
          targetCenter: collCenter,
        );

      case 3:
      default:
        // Step 4: Live AR View tab
        final box = (widget.arKey ?? GraziaBottomNav.arKey).currentContext?.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize) {
          final pos = box.localToGlobal(Offset.zero);
          if (pos.dy > 0 && pos.dy < screenSize.height) {
            final center = Offset(pos.dx + box.size.width / 2, pos.dy + box.size.height / 2);
            final rect = Rect.fromCircle(center: center, radius: 28);
            return _SpotlightTarget(
              rect: rect,
              isCircle: true,
              borderRadius: 28,
              pointerDirection: _PointerDirection.down,
              tooltipPosition: _TooltipPlacement.aboveTarget,
              targetCenter: center,
            );
          }
        }
        final navWidth = screenSize.width - 36;
        final arX = 18 + navWidth * (3.5 / 5.0);
        final arCenter = Offset(arX, navY);
        return _SpotlightTarget(
          rect: Rect.fromCircle(center: arCenter, radius: 28),
          isCircle: true,
          borderRadius: 28,
          pointerDirection: _PointerDirection.down,
          tooltipPosition: _TooltipPlacement.aboveTarget,
          targetCenter: arCenter,
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
                      overlayColor: Colors.black.withValues(alpha: 0.74),
                      glowColor: gold,
                      luminousColor: goldLuminous,
                    ),
                  );
                },
              ),
            ),
          ),

          // 2. Top Header Bar (Frosted Apple Capsule & Skip Button)
          _buildTopHeaderBar(topPadding),

          // 3. Anchored Contextual Tooltip Card
          _buildContextualTooltip(
            screenSize: screenSize,
            topPadding: topPadding,
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

  Widget _buildTopHeaderBar(double topPadding) {
    final isMayaStep = _currentStep == 1;

    return Positioned(
      top: topPadding + 10,
      left: 16,
      right: isMayaStep ? null : 16,
      child: Row(
        mainAxisAlignment: isMayaStep ? MainAxisAlignment.start : MainAxisAlignment.spaceBetween,
        children: [
          // Frosted Glass Guide Pill
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1A18).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: gold.withValues(alpha: 0.65),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome_rounded, size: 12, color: gold),
                    const SizedBox(width: 5),
                    Text(
                      'TOUR ${_currentStep + 1} OF ${_steps.length}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: gold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (isMayaStep) const SizedBox(width: 8),

          // Skip Tour Button
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: GestureDetector(
                onTap: _finishTour,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1A18).withValues(alpha: 0.80),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Skip',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.close_rounded, size: 12, color: Colors.white60),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContextualTooltip({
    required Size screenSize,
    required double topPadding,
    required double bottomPadding,
    required _SpotlightTarget target,
    required Map<String, dynamic> step,
    required bool isLast,
    required Color gold,
  }) {
    final isAbove = target.tooltipPosition == _TooltipPlacement.aboveTarget;
    final isMayaStep = _currentStep == 1;

    double? cardTop;
    double? cardBottom;

    if (isAbove) {
      cardBottom = screenSize.height - target.rect.top + 14;
    } else {
      cardTop = target.rect.bottom + 14;
    }

    final arrowLeft = (target.targetCenter.dx - 26).clamp(24.0, screenSize.width - 56.0);

    return Positioned(
      left: 16,
      right: 16,
      bottom: cardBottom,
      top: cardTop,
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
                  strokeColor: gold.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],

          // Ultra-Luxury Frosted Glass Card with Animated Transitions
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF171514).withValues(alpha: 0.90),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: gold.withValues(alpha: 0.50),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.65),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: gold.withValues(alpha: 0.14),
                      blurRadius: 24,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.05),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey<int>(_currentStep),
                    child: isMayaStep
                        ? _buildMayaCardContent(gold)
                        : _buildStandardCardContent(step, isLast, gold),
                  ),
                ),
              ),
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
                  strokeColor: gold.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Apple-Style Segmented Step Progress Bar at top of card
  Widget _buildSegmentedProgressBar(Color gold) {
    return Row(
      children: List.generate(_steps.length, (i) {
        final isFilled = i <= _currentStep;
        final isCurrent = i == _currentStep;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < _steps.length - 1 ? 5 : 0),
            height: 3.5,
            decoration: BoxDecoration(
              color: isCurrent
                  ? gold
                  : (isFilled ? gold.withValues(alpha: 0.70) : Colors.white12),
              borderRadius: BorderRadius.circular(2),
              boxShadow: isCurrent
                  ? [
                      BoxShadow(
                        color: gold.withValues(alpha: 0.6),
                        blurRadius: 6,
                        spreadRadius: 0.5,
                      ),
                    ]
                  : null,
            ),
          ),
        );
      }),
    );
  }

  /// Specialized Luxury Card for Introducing Maya AI
  Widget _buildMayaCardContent(Color gold) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 0. Top Segmented Progress Bar
        _buildSegmentedProgressBar(gold),
        const SizedBox(height: 14),

        // 1. Maya Identity Header with Glowing Portrait & Active Status
        Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: gold, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: gold.withValues(alpha: 0.45),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/maya_avatar.jpg',
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.auto_awesome_rounded,
                        color: gold,
                        size: 26,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 1,
                  right: 1,
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF181615),
                        width: 2.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4CAF50).withValues(alpha: 0.6),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'MAYA AI ARCHITECT',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                          color: gold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2),
                        decoration: BoxDecoration(
                          color: gold.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'ONLINE',
                          style: GoogleFonts.inter(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            color: gold,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Meet Maya AI Consultant',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 17.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    'Bilingual • Hindi & English Voice/Chat',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFFB0AAA0),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // 2. Personalized Hindi/English Greeting
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Text(
            'Poochiye Maya se Hindi ya English me — "living room ke liye premium stone designs", "villa exterior facades", ya "budget calculation". Maya aapko Grazia ke 35 collections me se perfect design recommend karegi!',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: const Color(0xFFE4DFD3),
              height: 1.45,
            ),
          ),
        ),

        const SizedBox(height: 12),

        // 3. Sample Query Prompts
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _buildSamplePromptChip('🛋️ Living Room Wall', gold),
            _buildSamplePromptChip('🏛️ Villa Facade', gold),
            _buildSamplePromptChip('📐 3D Fluted Panels', gold),
          ],
        ),

        const SizedBox(height: 16),

        // 4. Action Row (Back, Chat with Maya Now & Next Step)
        Row(
          children: [
            // Back Button
            if (_currentStep > 0) ...[
              _buildBackPillButton(),
              const SizedBox(width: 8),
            ],

            // Chat with Maya Now (Primary Luxury Action)
            Expanded(
              flex: 6,
              child: SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: _openMaya,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gold,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.chat_bubble_rounded, size: 14, color: Colors.black),
                        const SizedBox(width: 5),
                        Text(
                          'Talk to Maya Now',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Next Step
            Expanded(
              flex: 4,
              child: SizedBox(
                height: 44,
                child: OutlinedButton(
                  onPressed: _nextStep,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Next Step →',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSamplePromptChip(String text, Color gold) {
    return GestureDetector(
      onTap: _openMaya,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: gold.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: gold.withValues(alpha: 0.32)),
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: gold,
          ),
        ),
      ),
    );
  }

  /// Standard Card Content for Steps 1, 3, 4
  Widget _buildStandardCardContent(Map<String, dynamic> step, bool isLast, Color gold) {
    final chips = (step['chips'] as List<String>?) ?? [];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 0. Top Segmented Progress Bar
        _buildSegmentedProgressBar(gold),
        const SizedBox(height: 14),

        // 1. Top Category & Badge Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: gold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: gold.withValues(alpha: 0.45)),
                  ),
                  child: Icon(step['icon'] as IconData, size: 16, color: gold),
                ),
                const SizedBox(width: 9),
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: Text(
                step['badge'] as String,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Colors.white70,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 2. Headline
        Text(
          step['title'] as String,
          style: GoogleFonts.playfairDisplay(
            fontSize: 18.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),

        // 3. Subtitle / Narrative
        Text(
          step['subtitle'] as String,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            color: const Color(0xFFD4CEBE),
            height: 1.42,
          ),
        ),
        const SizedBox(height: 12),

        // 4. Feature Pills
        if (chips.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: chips.map((c) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: Text(
                c,
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFE2DDD5),
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 16),
        ] else ...[
          const SizedBox(height: 6),
        ],

        // 5. Action Row (Back + Next Step Buttons)
        Row(
          children: [
            if (_currentStep > 0) ...[
              _buildBackPillButton(),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gold,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBackPillButton() {
    return SizedBox(
      width: 44,
      height: 44,
      child: OutlinedButton(
        onPressed: _prevStep,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white70,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.20)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: EdgeInsets.zero,
        ),
        child: const Icon(Icons.arrow_back_rounded, size: 16, color: Colors.white70),
      ),
    );
  }
}

enum _PointerDirection { up, down }
enum _TooltipPlacement { aboveTarget, belowTarget }

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

class _SpotlightHolePainter extends CustomPainter {
  final _SpotlightTarget target;
  final double pulseValue;
  final Color overlayColor;
  final Color glowColor;
  final Color luminousColor;

  _SpotlightHolePainter({
    required this.target,
    required this.pulseValue,
    required this.overlayColor,
    required this.glowColor,
    required this.luminousColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final screenPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final holePath = Path();
    if (target.isCircle) {
      holePath.addOval(target.rect);
    } else {
      holePath.addRRect(RRect.fromRectAndRadius(target.rect, Radius.circular(target.borderRadius)));
    }

    final cutoutPath = Path.combine(PathOperation.difference, screenPath, holePath);

    // Deep dim backdrop
    final dimPaint = Paint()..color = overlayColor;
    canvas.drawPath(cutoutPath, dimPaint);

    // Inner sharp gold rim
    final innerRimPaint = Paint()
      ..color = luminousColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    if (target.isCircle) {
      canvas.drawOval(target.rect, innerRimPaint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(target.rect, Radius.circular(target.borderRadius)),
        innerRimPaint,
      );
    }

    // Outer pulsating radiant halo
    final pulseScale = 1.0 + (pulseValue * 0.16);
    final glowRect = Rect.fromCenter(
      center: target.targetCenter,
      width: target.rect.width * pulseScale,
      height: target.rect.height * pulseScale,
    );

    final glowPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.45 * (1.0 - pulseValue * 0.6))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    if (target.isCircle) {
      canvas.drawOval(glowRect, glowPaint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(glowRect, Radius.circular(target.borderRadius * pulseScale)),
        glowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpotlightHolePainter oldDelegate) {
    return oldDelegate.pulseValue != pulseValue || oldDelegate.target != target;
  }
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
    } else {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width / 2, size.height);
    }
    path.close();

    final fillPaint = Paint()..color = color;
    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) => false;
}
