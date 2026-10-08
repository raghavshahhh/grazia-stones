import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/core/providers/stone_providers.dart';
import 'package:grazia_stones/core/services/pdf_service.dart';
import 'package:grazia_stones/features/cart/presentation/cart_screen.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/shared/widgets/luxury_toast.dart';
import 'package:grazia_stones/shared/widgets/smart_stone_image.dart';

/// Next-Generation Interactive Proportional 3D Wall Visualizer & Tile Estimation Engine.
/// Upgraded with:
/// 1. True 6-Sided Architectural Slab Extrusion (Depth/Thickness, Chiseled Sides, Structural Back, Coping Top).
/// 2. Unconstrained 360° Orbit Rotation around the entire wall.
/// 3. High-Res Stone Texture with Exact Architectural Mortar Joints (Stacked, Brick Running Bond, Vertical).
/// 4. Tile Specifications Badge with Real mm/inch Dimensions, Grid Counts, and Packaging details.
/// 5. 1-Tap Immersive Studio Focus Mode (Tap wall to dismiss all UI for distraction-free 360° inspection).
/// 6. Comprehensive Wall Spec PDF Export and 1-Tap Cart Integration.
class TileWallVisualizerScreen extends ConsumerStatefulWidget {
  final String? initialStoneId;

  const TileWallVisualizerScreen({super.key, this.initialStoneId});

  @override
  ConsumerState<TileWallVisualizerScreen> createState() => _TileWallVisualizerScreenState();
}

class _TileWallVisualizerScreenState extends ConsumerState<TileWallVisualizerScreen>
    with SingleTickerProviderStateMixin {
  final _widthController = TextEditingController(text: '12');
  final _heightController = TextEditingController(text: '10');
  String _unit = 'ft';
  double _wastagePercent = 15;
  Stone? _selectedStone;
  bool _is3DView = true;
  String _layoutPattern = 'brick'; // 'brick' (Running Bond), 'stacked', 'vertical'
  bool _isExportingPdf = false;
  bool _isFocusMode = false; // Immersive full-screen 360° mode

  // 3D Camera & Transform parameters
  double _rotX = 0.12; // pitch in radians
  double _rotY = -0.32; // yaw in radians (unconstrained 360°)
  double _scale = 1.0;
  Offset _panOffset = Offset.zero;

  double _startScale = 1.0;
  bool _showDimensions = true;

  late AnimationController _cameraAnimController;
  Animation<double>? _animRotX;
  Animation<double>? _animRotY;
  Animation<double>? _animScale;
  Animation<Offset>? _animPan;

  @override
  void initState() {
    super.initState();
    _cameraAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..addListener(() {
        setState(() {
          if (_animRotX != null) _rotX = _animRotX!.value;
          if (_animRotY != null) _rotY = _animRotY!.value;
          if (_animScale != null) _scale = _animScale!.value;
          if (_animPan != null) _panOffset = _animPan!.value;
        });
      });
  }

  @override
  void dispose() {
    _cameraAnimController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  double? get _widthValue => double.tryParse(_widthController.text);
  double? get _heightValue => double.tryParse(_heightController.text);

  double _toFeet(double value) {
    switch (_unit) {
      case 'in':
        return value / 12;
      case 'm':
        return value * 3.28084;
      case 'cm':
        return value * 0.0328084;
      default:
        return value;
    }
  }

  void _stepWidth(double delta) {
    HapticFeedback.lightImpact();
    final cur = double.tryParse(_widthController.text.trim()) ?? 12.0;
    final next = (cur + delta).clamp(1.0, 500.0);
    _widthController.text = next == next.roundToDouble() ? next.toInt().toString() : next.toStringAsFixed(1);
    setState(() {});
  }

  void _stepHeight(double delta) {
    HapticFeedback.lightImpact();
    final cur = double.tryParse(_heightController.text.trim()) ?? 10.0;
    final next = (cur + delta).clamp(1.0, 500.0);
    _heightController.text = next == next.roundToDouble() ? next.toInt().toString() : next.toStringAsFixed(1);
    setState(() {});
  }

  void _applyWallPreset(String w, String h) {
    HapticFeedback.selectionClick();
    _widthController.text = w;
    _heightController.text = h;
    _unit = 'ft';
    setState(() {});
  }

  void _toggleFocusMode() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isFocusMode = !_isFocusMode;
    });
  }

  void _resetView() {
    _animateToCamera(
      targetRotX: 0.12,
      targetRotY: -0.32,
      targetScale: 1.0,
      targetPan: Offset.zero,
      is3D: true,
    );
  }

  void _animateToCamera({
    required double targetRotX,
    required double targetRotY,
    double targetScale = 1.0,
    Offset targetPan = Offset.zero,
    bool is3D = true,
  }) {
    HapticFeedback.selectionClick();
    _cameraAnimController.stop();

    _animRotX = Tween<double>(begin: _rotX, end: targetRotX).animate(
      CurvedAnimation(parent: _cameraAnimController, curve: Curves.easeOutCubic),
    );
    _animRotY = Tween<double>(begin: _rotY, end: targetRotY).animate(
      CurvedAnimation(parent: _cameraAnimController, curve: Curves.easeOutCubic),
    );
    _animScale = Tween<double>(begin: _scale, end: targetScale).animate(
      CurvedAnimation(parent: _cameraAnimController, curve: Curves.easeOutCubic),
    );
    _animPan = Tween<Offset>(begin: _panOffset, end: targetPan).animate(
      CurvedAnimation(parent: _cameraAnimController, curve: Curves.easeOutCubic),
    );

    _cameraAnimController.reset();
    _cameraAnimController.forward();

    setState(() {
      _is3DView = is3D;
    });
  }

  Future<void> _exportPdfSpecSheet(
      double widthFt, double heightFt, double netArea, double grossArea, int? boxes, int? totalTiles, double cost) async {
    if (_selectedStone == null) {
      LuxuryToast.show(
        context,
        message: 'Please select a stone material first to export specification sheet.',
      );
      return;
    }

    setState(() => _isExportingPdf = true);
    HapticFeedback.mediumImpact();

    try {
      final pdfBytes = await PDFService.instance.generateWallSpecPDF(
        stone: _selectedStone!,
        wallWidthFt: widthFt,
        wallHeightFt: heightFt,
        unit: _unit,
        wastagePercent: _wastagePercent,
        boxesRequired: boxes ?? 0,
        totalTiles: totalTiles ?? 0,
        netAreaSqFt: netArea,
        grossAreaSqFt: grossArea,
        estimatedCost: cost,
      );

      if (!mounted) return;
      await Printing.layoutPdf(
        onLayout: (_) => pdfBytes,
        name: 'Grazia_Wall_Spec_${_selectedStone!.name.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      LuxuryToast.show(
        context,
        message: 'Unable to generate PDF: $e',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  void _addBoxesToCart(double grossArea) {
    if (_selectedStone == null) return;
    ref.read(cartProvider.notifier).addItem(_selectedStone!, quantity: grossArea.ceil());
    HapticFeedback.heavyImpact();

    LuxuryToast.show(
      context,
      message: 'Added ${grossArea.toStringAsFixed(0)} sq.ft of ${_selectedStone!.name} to Project Cart!',
      actionLabel: 'View Cart',
      onAction: () => context.push('/cart'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);
    final isDark = ref.watch(themePaletteProvider.notifier).isDarkMode;
    final stonesAsync = ref.watch(allStonesProvider);
    if (_selectedStone == null && stonesAsync.hasValue && stonesAsync.value != null && stonesAsync.value!.isNotEmpty) {
      final stones = stonesAsync.value!;
      Stone? match;
      if (widget.initialStoneId != null) {
        final q = widget.initialStoneId!.toLowerCase().trim();
        match = stones.where((s) =>
            s.id.toLowerCase() == q ||
            s.name.toLowerCase() == q ||
            s.name.toLowerCase().contains(q) ||
            s.productCode.toLowerCase() == q).firstOrNull;
      }
      _selectedStone = match ?? stones.first;
    }

    final widthFt = _widthValue != null ? _toFeet(_widthValue!) : null;
    final heightFt = _heightValue != null ? _toFeet(_heightValue!) : null;
    final validDimensions = widthFt != null && heightFt != null && widthFt > 0 && heightFt > 0;

    final netAreaSqFt = validDimensions ? widthFt * heightFt : 0.0;
    final grossAreaSqFt = netAreaSqFt * (1 + _wastagePercent / 100);

    int? boxesRequired;
    int? totalTiles;
    double estimatedCost = 0.0;

    final effectiveCoverage = (_selectedStone != null && _selectedStone!.sqftPerBox > 0)
        ? _selectedStone!.sqftPerBox
        : 10.5;
    final effectivePrice = (_selectedStone != null && _selectedStone!.pricePerSqFt > 0)
        ? _selectedStone!.pricePerSqFt
        : 385.0;

    int columns = 6;
    int rows = 12;

    if (validDimensions) {
      boxesRequired = (grossAreaSqFt / effectiveCoverage).ceil();
      estimatedCost = grossAreaSqFt * effectivePrice;

      final lenCm = _selectedStone?.lengthCm;
      final widCm = _selectedStone?.widthCm;
      if (lenCm != null && widCm != null && lenCm > 0 && widCm > 0) {
        final tileWFt = lenCm / 30.48;
        final tileHFt = widCm / 30.48;
        columns = (widthFt / tileWFt).ceil().clamp(1, 30);
        rows = (heightFt / tileHFt).ceil().clamp(1, 40);
        totalTiles = (columns * rows * (1 + _wastagePercent / 100)).ceil();
      } else {
        columns = (widthFt / 1.6).ceil().clamp(2, 20);
        rows = (heightFt / 0.8).ceil().clamp(2, 25);
        totalTiles = (grossAreaSqFt / 8.0).ceil();
      }
    }

    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: _isFocusMode
          ? null
          : AppBar(
              backgroundColor: palette.background,
              elevation: 0,
              scrolledUnderElevation: 0,
              titleSpacing: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: palette.textPrimary, size: 18),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home');
                  }
                },
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Wall & Tile Visualizer',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'True 3D Architectural Thickness & 360° Studio',
                    style: GoogleFonts.inter(
                      fontSize: 9.5,
                      color: palette.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              actions: [
                // 1-Tap Focus Studio Full-Screen
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: palette.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: palette.primary.withValues(alpha: 0.35), width: 0.8),
                    ),
                    child: Icon(Icons.fullscreen_rounded, size: 16, color: palette.primary),
                  ),
                  tooltip: '360° Studio Mode',
                  onPressed: _toggleFocusMode,
                ),

                // 2D / 3D Toggle
                GestureDetector(
                  onTap: () {
                    if (_is3DView) {
                      _animateToCamera(targetRotX: 0.0, targetRotY: 0.0, targetScale: 1.0, is3D: false);
                    } else {
                      _animateToCamera(targetRotX: 0.12, targetRotY: -0.32, targetScale: 1.0, is3D: true);
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: _is3DView ? palette.primary : palette.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _is3DView ? palette.primary : palette.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _is3DView ? Icons.view_in_ar_rounded : Icons.crop_square_rounded,
                          size: 12,
                          color: _is3DView ? Colors.black : palette.textPrimary,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _is3DView ? '3D' : '2D',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: _is3DView ? Colors.black : palette.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.restart_alt_rounded, color: palette.textSecondary, size: 18),
                  tooltip: 'Reset Camera',
                  onPressed: _resetView,
                ),
                const SizedBox(width: 2),
              ],
            ),
      body: SafeArea(
        top: _isFocusMode,
        bottom: !_isFocusMode,
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: Column(
            children: [
              // Dimension Controls & Wastage Header (Collapsed during focus mode)
              AnimatedCrossFade(
                firstChild: _buildDimensionControls(palette, isDark),
                secondChild: const SizedBox.shrink(),
                crossFadeState: _isFocusMode ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 260),
              ),

              // Interactive Proportional Wall Canvas Viewport with Touch 3D & Zoom
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 1.15,
                          colors: isDark
                              ? const [Color(0xFF221F1C), Color(0xFF100F0E)]
                              : [palette.surfaceDark, palette.background],
                        ),
                      ),
                      child: !validDimensions
                          ? Center(
                              child: Text(
                                'Enter wall dimensions above to visualize tiling.',
                                style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 13),
                              ),
                            )
                          : _buildInteractive3DCanvas(
                              widthFt: widthFt,
                              heightFt: heightFt,
                              columns: columns,
                              rows: rows,
                              palette: palette,
                              isDark: isDark,
                            ),
                    ),

                    // Top Left: Guide Badge OR Focus Mode Back Header
                    Positioned(
                      top: 12,
                      left: 14,
                      child: _isFocusMode
                          ? _buildFocusHeaderPill(palette, isDark)
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildGuideBadge(palette, isDark),
                                const SizedBox(height: 5),
                                _buildStoneSpecBadge(palette, isDark, columns, rows),
                              ],
                            ),
                    ),

                    // Top Right Controls (Dimension toggle & reset)
                    if (!_isFocusMode)
                      Positioned(
                        top: 12,
                        right: 14,
                        child: _buildTopCanvasControls(palette, isDark),
                      ),

                    // Center Right Floating Zoom Controls (+, %, -)
                    Positioned(
                      right: 14,
                      top: _isFocusMode ? 14 : 58,
                      child: _buildZoomFloatingControls(palette, isDark),
                    ),

                    // Bottom Floating Strip: Focus Mode Specs OR Standard Controls
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 10,
                      child: _isFocusMode
                          ? _buildFocusBottomFloatingBar(
                              columns: columns,
                              rows: rows,
                              palette: palette,
                              isDark: isDark,
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                _buildPatternSelector(palette, isDark),
                                const SizedBox(height: 6),
                                _buildCameraPresetSelector(palette, isDark),
                              ],
                            ),
                    ),
                  ],
                ),
              ),

              // Instant Calculations Summary Card (Collapsed in Focus Mode)
              if (validDimensions && !_isFocusMode)
                _buildCalculationSummary(
                  palette: palette,
                  isDark: isDark,
                  widthFt: widthFt,
                  heightFt: heightFt,
                  netAreaSqFt: netAreaSqFt,
                  grossAreaSqFt: grossAreaSqFt,
                  boxesRequired: boxesRequired,
                  totalTiles: totalTiles,
                  estimatedCost: estimatedCost,
                ),

              // Material Stone Carousel Strip (Collapsed in Focus Mode & Keyboard)
              if (!isKeyboardOpen && !_isFocusMode)
                stonesAsync.when(
                  data: (stones) {
                    if (_selectedStone == null && stones.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && _selectedStone == null) {
                          Stone? match;
                          if (widget.initialStoneId != null) {
                            final q = widget.initialStoneId!.toLowerCase().trim();
                            match = stones
                                .where((s) =>
                                    s.id.toLowerCase() == q ||
                                    s.name.toLowerCase() == q ||
                                    s.name.toLowerCase().contains(q) ||
                                    s.productCode.toLowerCase() == q)
                                .firstOrNull;
                          }
                          setState(() => _selectedStone = match ?? stones.first);
                        }
                      });
                    }
                    return _buildProductStrip(stones, palette, isDark);
                  },
                  loading: () => const SizedBox(
                    height: 94,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, _) => const SizedBox.shrink(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFocusHeaderPill(dynamic palette, bool isDark) {
    return GestureDetector(
      onTap: _toggleFocusMode,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.6), width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_back_rounded, size: 14, color: Color(0xFFD4AF37)),
            const SizedBox(width: 6),
            Text(
              '360° Studio Mode • Tap Wall to Exit',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'LIVE',
                style: GoogleFonts.inter(
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFocusBottomFloatingBar({
    required int columns,
    required int rows,
    required dynamic palette,
    required bool isDark,
  }) {
    final yawDeg = ((_rotY * 180 / math.pi) % 360).round();
    final stone = _selectedStone;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.5), width: 0.9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFD4AF37), width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: SmartStoneImage(
                    imageUrl: stone?.imageUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stone?.name ?? 'Grazia Stone',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _getFormattedStoneSpecs(stone, columns, rows),
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        color: const Color(0xFFD4AF37),
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF22201D),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24, width: 0.6),
                ),
                child: Text(
                  'Yaw: $yawDeg°',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Quick Angle Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStudioQuickAngleChip('Front 0°', 0.0, 0.0),
              _buildStudioQuickAngleChip('Right 90°', 0.05, -math.pi / 2),
              _buildStudioQuickAngleChip('Back 180°', 0.05, -math.pi),
              _buildStudioQuickAngleChip('Left 270°', 0.05, math.pi / 2),
              _buildStudioQuickAngleChip('Iso 3D', 0.24, -0.55),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudioQuickAngleChip(String label, double rotX, double rotY) {
    return InkWell(
      onTap: () {
        _animateToCamera(targetRotX: rotX, targetRotY: rotY, is3D: true);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
        decoration: BoxDecoration(
          color: const Color(0xFF262420),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.35), width: 0.7),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFD4AF37),
          ),
        ),
      ),
    );
  }

  String _getFormattedStoneSpecs(Stone? stone, int columns, int rows) {
    if (stone == null) return '$columns cols × $rows rows';
    final lenMm = stone.lengthCm != null ? (stone.lengthCm! * 10).round() : 490;
    final widMm = stone.widthCm != null ? (stone.widthCm! * 10).round() : 100;
    final thkMm = stone.thicknessMm != null ? stone.thicknessMm!.round() : 35;

    return '$lenMm×$widMm×$thkMm mm • $columns cols × $rows rows (${columns * rows} pcs)';
  }

  Widget _buildDimensionControls(dynamic palette, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1-Tap Quick Architectural Presets (Minimizes clicks!)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildQuickPresetChip("10' × 10' Accent", '10', '10', palette),
                _buildQuickPresetChip("12' × 10' Standard", '12', '10', palette),
                _buildQuickPresetChip("16' × 12' Feature", '16', '12', palette),
                _buildQuickPresetChip("20' × 14' Façade", '20', '14', palette),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Stepper-Enabled Dimension Inputs
          Row(
            children: [
              // Width with [-] and [+]
              Expanded(
                child: _buildDimStepperField(
                  controller: _widthController,
                  label: 'Wall Width',
                  icon: Icons.straighten_rounded,
                  palette: palette,
                  onMinus: () => _stepWidth(-1),
                  onPlus: () => _stepWidth(1),
                ),
              ),
              const SizedBox(width: 8),

              // Height with [-] and [+]
              Expanded(
                child: _buildDimStepperField(
                  controller: _heightController,
                  label: 'Wall Height',
                  icon: Icons.height_rounded,
                  palette: palette,
                  onMinus: () => _stepHeight(-1),
                  onPlus: () => _stepHeight(1),
                ),
              ),
              const SizedBox(width: 8),

              // Unit Selector Dropdown
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.border),
                  color: palette.surfaceDark,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _unit,
                    items: const ['ft', 'in', 'm', 'cm']
                        .map((u) => DropdownMenuItem(
                              value: u,
                              child: Text(u, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                            ))
                        .toList(),
                    onChanged: (u) {
                      if (u != null) {
                        HapticFeedback.selectionClick();
                        setState(() => _unit = u);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Wastage row with 1-tap quick chips & slider
          Row(
            children: [
              Text(
                'Wastage: ',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: palette.textSecondary),
              ),
              ...[5, 10, 15, 20].map((w) {
                final isSel = _wastagePercent.toInt() == w;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _wastagePercent = w.toDouble());
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isSel ? palette.primary : palette.surfaceDark,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSel ? palette.primary : palette.border,
                        ),
                      ),
                      child: Text(
                        '$w%',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: isSel ? Colors.black : palette.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              }),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    thumbColor: palette.primary,
                    activeTrackColor: palette.primary,
                    inactiveTrackColor: palette.primary.withValues(alpha: 0.2),
                    trackHeight: 2.5,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                  ),
                  child: Slider(
                    value: _wastagePercent,
                    min: 5,
                    max: 20,
                    divisions: 3,
                    onChanged: (v) => setState(() => _wastagePercent = v),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDimStepperField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required dynamic palette,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: palette.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            onPressed: onMinus,
            icon: Icon(Icons.remove_circle_outline_rounded, color: palette.textSecondary, size: 18),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: palette.textPrimary),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            onPressed: onPlus,
            icon: Icon(Icons.add_circle_outline_rounded, color: palette.primary, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPresetChip(String title, String w, String h, dynamic palette) {
    final isSelected = _widthController.text == w && _heightController.text == h && _unit == 'ft';
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => _applyWallPreset(w, h),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? palette.primary.withValues(alpha: 0.15) : palette.surfaceDark,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? palette.primary : palette.border,
              width: isSelected ? 1.4 : 1.0,
            ),
          ),
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? palette.primary : palette.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInteractive3DCanvas({
    required double widthFt,
    required double heightFt,
    required int columns,
    required int rows,
    required dynamic palette,
    required bool isDark,
  }) {
    return Listener(
      // Mouse wheel / trackpad zoom (web & desktop support)
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          setState(() {
            _scale = (_scale * (event.scrollDelta.dy > 0 ? 0.92 : 1.08)).clamp(0.4, 4.0);
          });
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleFocusMode, // 1-Tap toggles distraction-free 360° Studio!
        onScaleStart: (details) {
          _startScale = _scale;
        },
        onScaleUpdate: (details) {
          setState(() {
            if (details.pointerCount == 1) {
              // 1 finger touch: Full Unconstrained 360° Orbit Rotation
              _is3DView = true;
              _rotY = (_rotY + details.focalPointDelta.dx * 0.0085);
              _rotX = (_rotX - details.focalPointDelta.dy * 0.0075).clamp(-0.75, 0.75);
            } else if (details.pointerCount >= 2) {
              // 2 fingers: Zoom & Pan
              _scale = (_startScale * details.scale).clamp(0.4, 4.0);
              final next = _panOffset + details.focalPointDelta;
              _panOffset = Offset(next.dx.clamp(-280.0, 280.0), next.dy.clamp(-320.0, 320.0));
            }
          });
        },
        onDoubleTap: _resetView,
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            // 1. Studio Perspective Floor & Horizon Grid
            CustomPaint(
              painter: _StudioFloorPainter(
                isDark: isDark,
                accentColor: palette.primary,
                rotX: _is3DView ? _rotX : 0.0,
                rotY: _is3DView ? _rotY : 0.0,
              ),
            ),

            // 2. The True 6-Sided Proportional 3D Wall Prism
            Center(
              child: _buildTrue3DWallPrism(
                widthFt: widthFt,
                heightFt: heightFt,
                columns: columns,
                rows: rows,
                palette: palette,
                isDark: isDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrue3DWallPrism({
    required double widthFt,
    required double heightFt,
    required int columns,
    required int rows,
    required dynamic palette,
    required bool isDark,
  }) {
    const maxRenderW = 270.0;
    const maxRenderH = 250.0;
    final aspect = (widthFt > 0 && heightFt > 0) ? widthFt / heightFt : 1.2;
    double renderWidth;
    double renderHeight;

    if (aspect >= 1) {
      renderWidth = maxRenderW;
      renderHeight = (maxRenderW / aspect).clamp(110.0, maxRenderH);
    } else {
      renderHeight = maxRenderH;
      renderWidth = (maxRenderH * aspect).clamp(110.0, maxRenderW);
    }

    // Realistic architectural slab thickness based on stone specs
    final double stoneThk = _selectedStone?.thicknessMm ?? 35.0;
    final double wallDepth = ((stoneThk / 10.0) * 8.0).clamp(24.0, 42.0);

    // 3D Perspective Matrix
    final activeRotX = _is3DView ? _rotX : 0.0;
    final activeRotY = _is3DView ? _rotY : 0.0;

    final matrix = Matrix4.identity()
      ..setEntry(3, 2, 0.0012) // camera perspective distortion
      ..translate(_panOffset.dx, _panOffset.dy)
      ..scale(_scale)
      ..rotateX(activeRotX)
      ..rotateY(activeRotY);

    // Normal vectors & camera depth calculation for 6-sided Painter's algorithm
    final cosX = math.cos(activeRotX);
    final sinX = math.sin(activeRotX);
    final cosY = math.cos(activeRotY);
    final sinY = math.sin(activeRotY);

    // Projected Z distances of face centers
    final frontZ = (wallDepth / 2) * cosY * cosX;
    final backZ = -(wallDepth / 2) * cosY * cosX;
    final rightZ = -(renderWidth / 2) * sinY * cosX;
    final leftZ = (renderWidth / 2) * sinY * cosX;
    final topZ = (renderHeight / 2) * sinX;
    final bottomZ = -(renderHeight / 2) * sinX;

    // Dot product with view vector for back-face culling
    final frontVisible = (cosY * cosX) > -0.05;
    final backVisible = (-cosY * cosX) > -0.05;
    final rightVisible = (-sinY * cosX) > -0.05;
    final leftVisible = (sinY * cosX) > -0.05;
    final topVisible = sinX > -0.05;
    final bottomVisible = -sinX > -0.05;

    // Dynamic ground contact shadow beneath the wall
    final shadowShiftX = math.sin(activeRotY) * 22.0;
    final shadowShiftY = (math.cos(activeRotX) * 12.0) + 12.0;

    final List<_FaceData> faces = [];

    // Front Face (Real Stone Texture + Architectural Mortar Joints + Relief Shading)
    if (frontVisible) {
      faces.add(_FaceData(
        frontZ,
        Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()..translate(0.0, 0.0, wallDepth / 2),
          child: _buildFrontFace(
            renderWidth: renderWidth,
            renderHeight: renderHeight,
            columns: columns,
            rows: rows,
            palette: palette,
            isDark: isDark,
            activeRotX: activeRotX,
            activeRotY: activeRotY,
          ),
        ),
      ));
    }

    // Back Face (Reinforced Architectural Substrate Grid & Technical Cert)
    if (backVisible) {
      faces.add(_FaceData(
        backZ,
        Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..translate(0.0, 0.0, -wallDepth / 2)
            ..rotateY(math.pi),
          child: _buildBackFace(
            renderWidth: renderWidth,
            renderHeight: renderHeight,
            palette: palette,
            isDark: isDark,
          ),
        ),
      ));
    }

    // Right Side Face (Extruded Profile with Mortar Joints & Chiseled Strata)
    if (rightVisible) {
      faces.add(_FaceData(
        rightZ,
        Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..translate(renderWidth / 2, 0.0, 0.0)
            ..rotateY(math.pi / 2),
          child: _buildSideFace(
            isRight: true,
            wallDepth: wallDepth,
            renderHeight: renderHeight,
            rows: rows,
            palette: palette,
          ),
        ),
      ));
    }

    // Left Side Face (Extruded Profile with Mortar Joints & Chiseled Strata)
    if (leftVisible) {
      faces.add(_FaceData(
        leftZ,
        Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..translate(-renderWidth / 2, 0.0, 0.0)
            ..rotateY(-math.pi / 2),
          child: _buildSideFace(
            isRight: false,
            wallDepth: wallDepth,
            renderHeight: renderHeight,
            rows: rows,
            palette: palette,
          ),
        ),
      ));
    }

    // Top Coping Slab Face (Honed Stone Finish)
    if (topVisible) {
      faces.add(_FaceData(
        topZ,
        Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..translate(0.0, -renderHeight / 2, 0.0)
            ..rotateX(-math.pi / 2),
          child: _buildTopCopingFace(
            renderWidth: renderWidth,
            wallDepth: wallDepth,
            palette: palette,
          ),
        ),
      ));
    }

    // Bottom Base Face
    if (bottomVisible) {
      faces.add(_FaceData(
        bottomZ,
        Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..translate(0.0, renderHeight / 2, 0.0)
            ..rotateX(math.pi / 2),
          child: _buildBottomBaseFace(
            renderWidth: renderWidth,
            wallDepth: wallDepth,
            palette: palette,
          ),
        ),
      ));
    }

    // Painter's algorithm: sort faces from back to front (lowest depth first)
    faces.sort((a, b) => a.depth.compareTo(b.depth));

    return Transform(
      transform: matrix,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Architectural Dimension Line (when enabled and not in focus mode)
          if (_showDimensions && !_isFocusMode)
            _buildWidthDimensionTag(renderWidth, widthFt, palette),

          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left Architectural Dimension Line (when enabled and not in focus mode)
              if (_showDimensions && !_isFocusMode)
                _buildHeightDimensionTag(renderHeight, heightFt, palette),

              // The 6-Sided 3D Extruded Wall Box
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // Contact Shadow Beneath Wall
                  Positioned(
                    bottom: -20,
                    left: -20,
                    right: -20,
                    height: 28,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.70 : 0.35),
                            blurRadius: 22,
                            spreadRadius: 3,
                            offset: Offset(shadowShiftX, shadowShiftY),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Sized Box bounding all 6 faces
                  SizedBox(
                    width: renderWidth,
                    height: renderHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: faces.map((f) => f.widget).toList(),
                    ),
                  ),
                ],
              ),
            ],
          ),

        ],
      ),
    );
  }

  Widget _buildFrontFace({
    required double renderWidth,
    required double renderHeight,
    required int columns,
    required int rows,
    required dynamic palette,
    required bool isDark,
    required double activeRotX,
    required double activeRotY,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2.0),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. High-Resolution Stone Texture across the surface
          _selectedStone == null
              ? Container(
                  color: Colors.grey.shade400,
                  child: Center(
                    child: Text(
                      'Select a stone below',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  ),
                )
              : SmartStoneImage(
                  imageUrl: _selectedStone!.arTextureUrl ?? _selectedStone!.imageUrl,
                  fit: BoxFit.cover,
                  fallbackColor: const Color(0xFFC4B5A5),
                ),

          // 2. Custom Architectural Mortar Joints & Seam Painter
          CustomPaint(
            size: Size(renderWidth, renderHeight),
            painter: _ArchitecturalTileJointPainter(
              columns: columns,
              rows: rows,
              layoutPattern: _layoutPattern,
              groutColor: isDark ? const Color(0xFF141312) : const Color(0xFF282522),
              reliefIntensity: 0.30,
            ),
          ),

          // 3. Dynamic Specular Light Glint (shifts with rotation angle!)
          if (_is3DView)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(-0.8 + (activeRotY * 1.5), -0.8 + (activeRotX * 1.5)),
                  end: Alignment(0.8 + (activeRotY * 1.5), 0.8 + (activeRotX * 1.5)),
                  colors: [
                    Colors.white.withValues(alpha: 0.22),
                    Colors.white.withValues(alpha: 0.05),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.35),
                  ],
                  stops: const [0.0, 0.25, 0.60, 1.0],
                ),
              ),
            ),

          // 4. Subtle Inner Vignette for natural relief depth
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.95,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.25),
                ],
                stops: const [0.70, 1.0],
              ),
            ),
          ),

          // 5. Architectural Precision Gold Beveled Border
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.80),
                width: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackFace({
    required double renderWidth,
    required double renderHeight,
    required dynamic palette,
    required bool isDark,
  }) {
    return Container(
      width: renderWidth,
      height: renderHeight,
      decoration: BoxDecoration(
        color: const Color(0xFF1B1A18),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.60),
          width: 1.2,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Technical Substrate Grid
          CustomPaint(
            size: Size(renderWidth, renderHeight),
            painter: _BackWallStructuralGridPainter(),
          ),

          // Central Architectural Substrate Plate
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.50),
                  width: 0.8,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.architecture_rounded, size: 14, color: Color(0xFFD4AF37)),
                      const SizedBox(width: 6),
                      Text(
                        'GRAZIA ARCHITECTURAL SUBSTRATE',
                        style: GoogleFonts.cinzel(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFD4AF37),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '100mm Structural Core • Precision Anchor Grid',
                    style: GoogleFonts.inter(
                      fontSize: 8,
                      color: Colors.white70,
                      letterSpacing: 0.3,
                    ),
                  ),
                  if (_selectedStone != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Material: ${_selectedStone!.name} (${_selectedStone!.productCode})',
                      style: GoogleFonts.inter(
                        fontSize: 7.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFD4AF37),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // 4 Corner Structural Mounting Fasteners
          ...[
            Alignment.topLeft,
            Alignment.topRight,
            Alignment.bottomLeft,
            Alignment.bottomRight,
          ].map((alignment) => Align(
                alignment: alignment,
                child: Container(
                  margin: const EdgeInsets.all(7),
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF33312E),
                    border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.5), width: 0.8),
                  ),
                  child: Center(
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildSideFace({
    required bool isRight,
    required double wallDepth,
    required double renderHeight,
    required int rows,
    required dynamic palette,
  }) {
    return Container(
      width: wallDepth,
      height: renderHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: isRight ? Alignment.centerLeft : Alignment.centerRight,
          end: isRight ? Alignment.centerRight : Alignment.centerLeft,
          colors: const [
            Color(0xFF282624),
            Color(0xFF141312),
          ],
        ),
        border: Border(
          top: BorderSide(color: palette.primary.withValues(alpha: 0.35), width: 0.6),
          bottom: BorderSide(color: palette.primary.withValues(alpha: 0.35), width: 0.6),
          right: isRight ? BorderSide(color: palette.primary.withValues(alpha: 0.5), width: 0.8) : BorderSide.none,
          left: !isRight ? BorderSide(color: palette.primary.withValues(alpha: 0.5), width: 0.8) : BorderSide.none,
        ),
      ),
      child: CustomPaint(
        painter: _SideChiselTexturePainter(
          rows: rows,
          wallDepth: wallDepth,
          renderHeight: renderHeight,
        ),
      ),
    );
  }

  Widget _buildTopCopingFace({
    required double renderWidth,
    required double wallDepth,
    required dynamic palette,
  }) {
    return Container(
      width: renderWidth,
      height: wallDepth,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Color(0xFF3E3B38),
            Color(0xFF56534E),
          ],
        ),
        border: Border(
          top: BorderSide(color: palette.primary.withValues(alpha: 0.6), width: 0.8),
          bottom: BorderSide(color: palette.primary.withValues(alpha: 0.4), width: 0.6),
        ),
      ),
      child: CustomPaint(
        painter: _TopCopingGrainPainter(),
      ),
    );
  }

  Widget _buildBottomBaseFace({
    required double renderWidth,
    required double wallDepth,
    required dynamic palette,
  }) {
    return Container(
      width: renderWidth,
      height: wallDepth,
      color: const Color(0xFF121110),
    );
  }

  Widget _buildStoneSpecBadge(
    dynamic palette,
    bool isDark,
    int columns,
    int rows,
  ) {
    final stone = _selectedStone;
    final lenMm = stone?.lengthCm != null ? (stone!.lengthCm! * 10).round() : 490;
    final widMm = stone?.widthCm != null ? (stone!.widthCm! * 10).round() : 100;
    final thkMm = stone?.thicknessMm != null ? stone!.thicknessMm!.round() : 35;

    final patternName = _layoutPattern == 'brick'
        ? 'Running Bond'
        : _layoutPattern == 'stacked'
            ? 'Stacked'
            : 'Vertical';

    return GestureDetector(
      onTap: _toggleFocusMode,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.45), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.straighten_rounded, size: 11, color: Color(0xFFD4AF37)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                '$lenMm×$widMm×$thkMm mm • $columns×$rows ($patternName)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFD4AF37),
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWidthDimensionTag(double width, double widthFt, dynamic palette) {
    return Container(
      width: width,
      margin: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.arrow_left_rounded, size: 14, color: palette.primary),
          Expanded(
            child: Container(height: 1, color: palette.primary.withValues(alpha: 0.6)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '${widthFt.toStringAsFixed(1)} ft (${_widthController.text} $_unit)',
              style: GoogleFonts.inter(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: palette.primary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            child: Container(height: 1, color: palette.primary.withValues(alpha: 0.6)),
          ),
          Icon(Icons.arrow_right_rounded, size: 14, color: palette.primary),
        ],
      ),
    );
  }

  Widget _buildHeightDimensionTag(double height, double heightFt, dynamic palette) {
    return Container(
      height: height,
      margin: const EdgeInsets.only(right: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.arrow_drop_up_rounded, size: 14, color: palette.primary),
          Expanded(
            child: Container(width: 1, color: palette.primary.withValues(alpha: 0.6)),
          ),
          RotatedBox(
            quarterTurns: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '${heightFt.toStringAsFixed(1)} ft (${_heightController.text} $_unit)',
                style: GoogleFonts.inter(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: palette.primary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(width: 1, color: palette.primary.withValues(alpha: 0.6)),
          ),
          Icon(Icons.arrow_drop_down_rounded, size: 14, color: palette.primary),
        ],
      ),
    );
  }

  Widget _buildGuideBadge(dynamic palette, bool isDark) {
    return GestureDetector(
      onTap: _toggleFocusMode,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E).withValues(alpha: 0.88) : Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.border, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.threesixty_rounded, size: 14, color: palette.primary),
            const SizedBox(width: 5),
            Text(
              '360° Orbit • Tap wall to Focus',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: palette.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCanvasControls(dynamic palette, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Dimension Toggle
        InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _showDimensions = !_showDimensions);
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E).withValues(alpha: 0.88) : Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _showDimensions ? palette.primary : palette.border,
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.straighten_rounded,
                  size: 13,
                  color: _showDimensions ? palette.primary : palette.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Dims',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _showDimensions ? palette.primary : palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        // Reset Camera
        InkWell(
          onTap: _resetView,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E).withValues(alpha: 0.88) : Colors.white.withValues(alpha: 0.9),
              shape: BoxShape.circle,
              border: Border.all(color: palette.border, width: 0.8),
            ),
            child: Icon(Icons.restart_alt_rounded, size: 14, color: palette.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildZoomFloatingControls(dynamic palette, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E).withValues(alpha: 0.92) : Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Zoom In
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _scale = (_scale + 0.25).clamp(0.4, 4.0));
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              child: Icon(Icons.add_rounded, size: 16),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            child: Text(
              '${(_scale * 100).toInt()}%',
              style: GoogleFonts.inter(fontSize: 8.5, fontWeight: FontWeight.w700),
            ),
          ),
          // Zoom Out
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _scale = (_scale - 0.25).clamp(0.4, 4.0));
            },
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              child: Icon(Icons.remove_rounded, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatternSelector(dynamic palette, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E1E1E).withValues(alpha: 0.92)
            : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPatternChip('Brick Bond', 'brick', palette),
          const SizedBox(width: 4),
          _buildPatternChip('Stacked', 'stacked', palette),
          const SizedBox(width: 4),
          _buildPatternChip('Vertical', 'vertical', palette),
        ],
      ),
    );
  }

  Widget _buildPatternChip(String label, String value, dynamic palette) {
    final isSelected = _layoutPattern == value;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _layoutPattern = value);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? palette.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.black : palette.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildCameraPresetSelector(dynamic palette, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E).withValues(alpha: 0.92) : Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCameraChip('Front', () {
            _animateToCamera(targetRotX: 0.0, targetRotY: 0.0, targetScale: 1.0, is3D: false);
          }, !_is3DView, palette),
          const SizedBox(width: 3),
          _buildCameraChip('3D Orbit', () {
            _animateToCamera(targetRotX: 0.12, targetRotY: -0.32, targetScale: 1.0, is3D: true);
          }, _is3DView && _rotY.abs() < 0.40, palette),
          const SizedBox(width: 3),
          _buildCameraChip('Iso', () {
            _animateToCamera(targetRotX: 0.26, targetRotY: -0.55, targetScale: 0.95, is3D: true);
          }, false, palette),
          const SizedBox(width: 3),
          _buildCameraChip('Side 90°', () {
            _animateToCamera(targetRotX: 0.05, targetRotY: -math.pi / 2, targetScale: 1.05, is3D: true);
          }, false, palette),
          const SizedBox(width: 3),
          _buildCameraChip('Back 180°', () {
            _animateToCamera(targetRotX: 0.05, targetRotY: -math.pi, targetScale: 1.0, is3D: true);
          }, false, palette),
        ],
      ),
    );
  }

  Widget _buildCameraChip(String label, VoidCallback onTap, bool isSelected, dynamic palette) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? palette.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.black : palette.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildCalculationSummary({
    required dynamic palette,
    required bool isDark,
    required double widthFt,
    required double heightFt,
    required double netAreaSqFt,
    required double grossAreaSqFt,
    required int? boxesRequired,
    required int? totalTiles,
    required double estimatedCost,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Stat Metrics Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatMetric('Net Area', '${netAreaSqFt.toStringAsFixed(1)} sq.ft', palette),
              _buildStatMetric('With Wastage', '${grossAreaSqFt.toStringAsFixed(1)} sq.ft', palette),
              _buildStatMetric(
                'Boxes Needed',
                boxesRequired != null ? '$boxesRequired boxes' : 'Coverage unavail.',
                palette,
                isHighlight: boxesRequired != null,
              ),
              _buildStatMetric(
                'Est. Value',
                '₹${estimatedCost.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                palette,
                isGold: true,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Action Buttons: PDF Export, Add to Cart (if packaging known), Request Quote
          Row(
            children: [
              // PDF Export Button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isExportingPdf
                      ? null
                      : () => _exportPdfSpecSheet(
                            widthFt,
                            heightFt,
                            netAreaSqFt,
                            grossAreaSqFt,
                            boxesRequired,
                            totalTiles,
                            estimatedCost,
                          ),
                  icon: _isExportingPdf
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf_rounded, size: 15),
                  label: Text(
                    'Export PDF',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Add to Cart Button (Only if real packaging is available)
              if (boxesRequired != null) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _addBoxesToCart(grossAreaSqFt),
                    icon: const Icon(Icons.shopping_bag_rounded, size: 15, color: Colors.black),
                    label: Text(
                      'Add to Cart',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.primary,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Get Factory Quote
                OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    context.push('/quotes/new?stoneId=${_selectedStone?.id ?? ''}');
                  },
                  icon: Icon(Icons.request_quote_rounded, size: 15, color: palette.primary),
                  label: Text(
                    'Quote',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: palette.primary),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size.zero,
                    side: BorderSide(color: palette.primary.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ] else ...[
                // Packaging metadata missing: promote "Request Quote" as primary CTA
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.heavyImpact();
                      context.push('/quotes/new?stoneId=${_selectedStone?.id ?? ''}');
                    },
                    icon: const Icon(Icons.request_quote_rounded, size: 15, color: Colors.black),
                    label: Text(
                      'Request Quote',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.primary,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatMetric(String label, String value, dynamic palette, {bool isHighlight = false, bool isGold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 10, color: palette.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isGold
                ? palette.primary
                : (isHighlight ? const Color(0xFF10B981) : palette.textPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildProductStrip(List<Stone> stones, dynamic palette, bool isDark) {
    return Container(
      height: 98,
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: isDark ? const Color(0xFF141312) : Colors.white,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        scrollDirection: Axis.horizontal,
        itemCount: stones.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final stone = stones[index];
          final isSelected = _selectedStone?.id == stone.id;
          final stonePrice = stone.pricePerSqFt > 0 ? stone.pricePerSqFt : 385.0;

          return InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedStone = stone);
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 150,
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: isSelected
                    ? palette.primary.withValues(alpha: 0.14)
                    : palette.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? palette.primary : palette.border,
                  width: isSelected ? 1.8 : 1.0,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: palette.primary.withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: SmartStoneImage(
                        imageUrl: stone.imageUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          stone.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? palette.primary : palette.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹${stonePrice.toInt()}/sqft',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: palette.primary,
                          ),
                        ),
                        Text(
                          '~${stone.sqftPerBox > 0 ? stone.sqftPerBox : 10.5} sf/b',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            color: palette.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Helper model for 3D Face Painter's Algorithm Depth Sorting
class _FaceData {
  final double depth;
  final Widget widget;

  _FaceData(this.depth, this.widget);
}

/// High-Precision Architectural Tile Mortar Seam Painter with Relief Depth & Bevels
class _ArchitecturalTileJointPainter extends CustomPainter {
  final int columns;
  final int rows;
  final String layoutPattern; // 'brick', 'stacked', 'vertical'
  final Color groutColor;
  final double reliefIntensity;

  _ArchitecturalTileJointPainter({
    required this.columns,
    required this.rows,
    required this.layoutPattern,
    required this.groutColor,
    required this.reliefIntensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (columns <= 0 || rows <= 0) return;

    final cellW = size.width / columns;
    final cellH = size.height / rows;

    // A. Per-Tile Micro-Shading & Relief Variation (Simulates Natural Quarried Stone Variation)
    for (int r = 0; r < rows; r++) {
      final isStaggered = layoutPattern == 'brick' && r.isOdd;
      final startCol = isStaggered ? -1 : 0;
      final endCol = isStaggered ? columns : columns - 1;

      for (int c = startCol; c <= endCol; c++) {
        final left = c * cellW + (isStaggered ? cellW * 0.5 : 0.0);
        final tileRect = Rect.fromLTWH(left, r * cellH, cellW, cellH).intersect(Offset.zero & size);
        if (tileRect.isEmpty) continue;

        // Deterministic pseudo-random variation based on grid position
        final hash = math.sin((r * 17.31) + (c * 29.53) + 3.14);
        final alpha = (hash.abs() * 0.12 * reliefIntensity).clamp(0.0, 0.15);
        final shadeColor = hash > 0 ? Colors.white.withValues(alpha: alpha) : Colors.black.withValues(alpha: alpha);

        canvas.drawRect(tileRect, Paint()..color = shadeColor);

        // Tile Micro-Bevel (Subtle specular ridge on top/left, subtle shadow on bottom/right)
        final bevelLight = Paint()
          ..color = Colors.white.withValues(alpha: 0.12)
          ..strokeWidth = 0.8;
        canvas.drawLine(tileRect.topLeft, tileRect.topRight, bevelLight);
        canvas.drawLine(tileRect.topLeft, tileRect.bottomLeft, bevelLight);

        final bevelShadow = Paint()
          ..color = Colors.black.withValues(alpha: 0.22)
          ..strokeWidth = 0.8;
        canvas.drawLine(tileRect.bottomLeft, tileRect.bottomRight, bevelShadow);
        canvas.drawLine(tileRect.topRight, tileRect.bottomRight, bevelShadow);
      }
    }

    // B. Architectural Mortar Joints / Grout Recesses
    final groutPaint = Paint()
      ..color = groutColor.withValues(alpha: 0.88)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    final groutShadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    // 1. Horizontal Course Mortar Lines
    for (int r = 1; r < rows; r++) {
      final y = r * cellH;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), groutPaint);
      canvas.drawLine(Offset(0, y + 0.8), Offset(size.width, y + 0.8), groutShadow);
    }

    // 2. Vertical Mortar Joints (Pattern Dependent)
    if (layoutPattern == 'stacked' || layoutPattern == 'vertical') {
      for (int c = 1; c < columns; c++) {
        final x = c * cellW;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), groutPaint);
        canvas.drawLine(Offset(x + 0.8, 0), Offset(x + 0.8, size.height), groutShadow);
      }
    } else if (layoutPattern == 'brick') {
      // Running Bond (50% Staggered alternating courses)
      for (int r = 0; r < rows; r++) {
        final yTop = r * cellH;
        final yBottom = (r + 1) * cellH;
        final offset = r.isOdd ? cellW * 0.5 : 0.0;

        for (int c = 0; c <= columns; c++) {
          final x = (c * cellW) + offset;
          if (x > 0.5 && x < size.width - 0.5) {
            canvas.drawLine(Offset(x, yTop), Offset(x, yBottom), groutPaint);
            canvas.drawLine(Offset(x + 0.8, yTop), Offset(x + 0.8, yBottom), groutShadow);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ArchitecturalTileJointPainter oldDelegate) {
    return oldDelegate.columns != columns ||
        oldDelegate.rows != rows ||
        oldDelegate.layoutPattern != layoutPattern ||
        oldDelegate.groutColor != groutColor;
  }
}

/// Perspective Floor & Horizon Painter for Showroom Atmosphere
class _StudioFloorPainter extends CustomPainter {
  final bool isDark;
  final Color accentColor;
  final double rotX;
  final double rotY;

  _StudioFloorPainter({
    required this.isDark,
    required this.accentColor,
    required this.rotX,
    required this.rotY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final horizonY = center.dy + 85 + (rotX * 45);

    // Floor subtle depth gradient
    final floorRect = Rect.fromLTRB(0, horizonY, size.width, size.height);
    final floorPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [const Color(0xFF141416), const Color(0xFF0D0D0E)]
            : [const Color(0xFFE8E5DF), const Color(0xFFD8D4CC)],
      ).createShader(floorRect);
    canvas.drawRect(floorRect, floorPaint);

    // Horizon line
    final horizonPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, horizonY), Offset(size.width, horizonY), horizonPaint);

    // Perspective floor lines vanishing towards horizon
    final vanishingPoint = Offset(center.dx + (rotY * 90), horizonY - 100);
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04)
      ..strokeWidth = 0.8;

    for (double x = -size.width * 0.5; x <= size.width * 1.5; x += 55) {
      canvas.drawLine(vanishingPoint, Offset(x, size.height), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _StudioFloorPainter oldDelegate) {
    return oldDelegate.isDark != isDark ||
        oldDelegate.rotX != rotX ||
        oldDelegate.rotY != rotY;
  }
}

/// Textured Chisel Relief for 3D Wall Sides
class _SideChiselTexturePainter extends CustomPainter {
  final int rows;
  final double wallDepth;
  final double renderHeight;

  _SideChiselTexturePainter({
    required this.rows,
    required this.wallDepth,
    required this.renderHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Horizontal mortar cut lines continuing from the front wall face
    final rowH = size.height / (rows > 0 ? rows : 12);
    final linePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..strokeWidth = 1.0;

    for (int r = 1; r < rows; r++) {
      final y = r * rowH;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // 2. Chiseled vertical strata grain
    final strataPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 0.7;

    for (double x = 4; x < size.width; x += 6) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), strataPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SideChiselTexturePainter oldDelegate) {
    return oldDelegate.rows != rows;
  }
}

/// Honed Top Coping Stone Grain Painter
class _TopCopingGrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final grainPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 0.8;

    for (double x = 12; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x + 4, size.height), grainPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Structural Substrate Grid for Back of Architectural Wall
class _BackWallStructuralGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 0.6;

    const spacing = 24.0;
    for (double x = spacing; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = spacing; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
