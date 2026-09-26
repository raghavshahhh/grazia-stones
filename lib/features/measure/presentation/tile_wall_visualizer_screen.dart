import 'dart:math' as math;
import 'package:flutter/material.dart';
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
/// Allows architects and clients to:
/// 1. Enter precise wall dimensions with any unit (ft, in, m, cm).
/// 2. Freely orbit, rotate, tilt, and pinch-to-zoom in full 3D with realistic slab depth & thickness.
/// 3. Inspect high-res stone texture, grout lines, specular lighting, and architectural dimensions.
/// 4. Switch between camera presets (Front 2D, Perspective 3D, Isometric, Side 45°).
/// 5. Toggle tile layout patterns: Stacked Grid, Running Bond (Brick), and Vertical Stack.
/// 6. Adjust wastage (5% - 20%) with real-time box count and financial calculation.
/// 7. 1-Tap Export Architectural Specification & Tile Calculation PDF.
/// 8. 1-Tap Add Required Boxes to Cart or Request Factory Quote.
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
  double _wastagePercent = 10;
  Stone? _selectedStone;
  bool _is3DView = true;
  String _layoutPattern = 'stacked'; // 'stacked', 'brick', 'vertical'
  bool _isExportingPdf = false;

  // 3D Camera & Transform parameters
  double _rotX = 0.12; // pitch in radians
  double _rotY = -0.26; // yaw in radians
  double _scale = 1.0;
  Offset _panOffset = Offset.zero;

  double _startRotX = 0.12;
  double _startRotY = -0.26;
  double _startScale = 1.0;
  Offset _startPan = Offset.zero;

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
      duration: const Duration(milliseconds: 380),
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

  void _resetView() {
    _animateToCamera(
      targetRotX: 0.12,
      targetRotY: -0.26,
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

  Future<void> _exportPdfSpecSheet(double widthFt, double heightFt, double netArea, double grossArea, int? boxes, int? totalTiles, double cost) async {
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

    if (validDimensions) {
      boxesRequired = (grossAreaSqFt / effectiveCoverage).ceil();
      estimatedCost = grossAreaSqFt * effectivePrice;

      final lenCm = _selectedStone?.lengthCm;
      final widCm = _selectedStone?.widthCm;
      if (lenCm != null && widCm != null && lenCm > 0 && widCm > 0) {
        final tileW = lenCm / 30.48;
        final tileH = widCm / 30.48;
        final cols = (widthFt / tileW).ceil();
        final rows = (heightFt / tileH).ceil();
        totalTiles = (cols * rows * (1 + _wastagePercent / 100)).ceil();
      } else {
        totalTiles = (grossAreaSqFt / 8.0).ceil();
      }
    }

    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
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
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Interactive 3D Architectural Geometry',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: palette.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          // 2D / 3D Toggle
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () {
                if (_is3DView) {
                  _animateToCamera(targetRotX: 0.0, targetRotY: 0.0, targetScale: 1.0, is3D: false);
                } else {
                  _animateToCamera(targetRotX: 0.12, targetRotY: -0.26, targetScale: 1.0, is3D: true);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _is3DView ? palette.primary : palette.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _is3DView ? palette.primary : palette.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _is3DView ? Icons.view_in_ar_rounded : Icons.crop_square_rounded,
                      size: 13,
                      color: _is3DView ? Colors.black : palette.textPrimary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _is3DView ? '3D Orbit' : '2D Plan',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _is3DView ? Colors.black : palette.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.restart_alt_rounded, color: palette.textSecondary, size: 20),
            tooltip: 'Reset Camera',
            onPressed: _resetView,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Column(
          children: [
            // Dimension Controls & Wastage Header
            _buildDimensionControls(palette, isDark),

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
                            palette: palette,
                            isDark: isDark,
                          ),
                  ),

                  // Top Left: 3D Orbit Guide Badge
                  Positioned(
                    top: 12,
                    left: 14,
                    child: _buildGuideBadge(palette, isDark),
                  ),

                  // Top Right Controls (Dimension toggle & reset)
                  Positioned(
                    top: 12,
                    right: 14,
                    child: _buildTopCanvasControls(palette, isDark),
                  ),

                  // Center Right Floating Zoom Controls (+, %, -)
                  Positioned(
                    right: 14,
                    top: 60,
                    child: _buildZoomFloatingControls(palette, isDark),
                  ),

                  // Bottom Center: Pattern Selector & Camera Presets
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 10,
                    child: Column(
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

            // Instant Calculations Summary Card
            if (validDimensions)
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

            // Material Stone Carousel Strip
            if (!isKeyboardOpen)
              stonesAsync.when(
                data: (stones) {
                  if (_selectedStone == null && stones.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && _selectedStone == null) {
                        Stone? match;
                        if (widget.initialStoneId != null) {
                          match = stones.where((s) => s.id == widget.initialStoneId).firstOrNull;
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
    );
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
    required dynamic palette,
    required bool isDark,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: (details) {
        _startRotX = _rotX;
        _startRotY = _rotY;
        _startScale = _scale;
        _startPan = _panOffset;
      },
      onScaleUpdate: (details) {
        setState(() {
          if (details.pointerCount == 1) {
            // 1 finger touch: Free 3D Orbit Rotate
            _is3DView = true;
            _rotY = (_rotY + details.focalPointDelta.dx * 0.0075).clamp(-1.3, 1.3);
            _rotX = (_rotX - details.focalPointDelta.dy * 0.0075).clamp(-0.65, 0.65);
          } else if (details.pointerCount >= 2) {
            // 2 fingers: Zoom & Pan
            _scale = (_startScale * details.scale).clamp(0.5, 3.5);
            _panOffset += details.focalPointDelta;
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

          // 2. The 3D Proportional Extruded Wall Object
          Center(
            child: _buildProportional3DWall(
              widthFt: widthFt,
              heightFt: heightFt,
              palette: palette,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProportional3DWall({
    required double widthFt,
    required double heightFt,
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

    final lenCm = _selectedStone?.lengthCm;
    final widCm = _selectedStone?.widthCm;
    final hasRealDimensions = lenCm != null && widCm != null && lenCm > 0 && widCm > 0;

    final int columns;
    final int rows;
    if (hasRealDimensions) {
      final tileWFt = lenCm / 30.48;
      final tileHFt = widCm / 30.48;
      columns = (widthFt / tileWFt).ceil().clamp(1, 24);
      rows = (heightFt / tileHFt).ceil().clamp(1, 24);
    } else {
      columns = 4;
      rows = 4;
    }

    // 3D Perspective Matrix
    final activeRotX = _is3DView ? _rotX : 0.0;
    final activeRotY = _is3DView ? _rotY : 0.0;

    final matrix = Matrix4.identity()
      ..setEntry(3, 2, 0.0012) // perspective distortion
      ..translate(_panOffset.dx, _panOffset.dy)
      ..scale(_scale)
      ..rotateX(activeRotX)
      ..rotateY(activeRotY);

    // Dynamic depth thickness (revealed as wall rotates)
    const wallDepth = 22.0; // architectural slab depth in pt
    final sideVisible = activeRotY.abs() > 0.01;
    final showRightSide = activeRotY < -0.01;
    final showLeftSide = activeRotY > 0.01;
    final sideWidth = (wallDepth * math.sin(activeRotY.abs())).clamp(3.0, wallDepth);

    final topVisible = activeRotX > 0.02;
    final topHeight = (wallDepth * math.sin(activeRotX)).clamp(2.5, wallDepth);

    return Transform(
      transform: matrix,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Architectural Dimension Line (if enabled)
          if (_showDimensions)
            _buildWidthDimensionTag(renderWidth, widthFt, palette),

          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left Architectural Dimension Line (if enabled)
              if (_showDimensions)
                _buildHeightDimensionTag(renderHeight, heightFt, palette),

              // The Extruded 3D Stone Wall Body
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // A. Floor Shadow Beneath Wall
                  Positioned(
                    bottom: -18,
                    left: -18,
                    right: -18,
                    height: 24,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.25),
                            blurRadius: 18,
                            spreadRadius: 2,
                            offset: Offset(showRightSide ? 10 : (showLeftSide ? -10 : 0), 8),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // B. 3D Side Depth Slab (Right side extrusion when rotated)
                  if (sideVisible && showRightSide)
                    Positioned(
                      top: 0,
                      bottom: 0,
                      right: -sideWidth + 1,
                      width: sideWidth,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Color(0xFF22201E),
                              Color(0xFF141312),
                            ],
                          ),
                          border: Border(
                            top: BorderSide(color: palette.primary.withValues(alpha: 0.3), width: 0.6),
                            right: BorderSide(color: palette.primary.withValues(alpha: 0.4), width: 0.8),
                            bottom: BorderSide(color: palette.primary.withValues(alpha: 0.2), width: 0.6),
                          ),
                        ),
                        child: CustomPaint(
                          painter: _SideMortarTexturePainter(),
                        ),
                      ),
                    ),

                  // B2. 3D Side Depth Slab (Left side extrusion when rotated)
                  if (sideVisible && showLeftSide)
                    Positioned(
                      top: 0,
                      bottom: 0,
                      left: -sideWidth + 1,
                      width: sideWidth,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.centerRight,
                            end: Alignment.centerLeft,
                            colors: [
                              Color(0xFF2E2C2A),
                              Color(0xFF1C1B1A),
                            ],
                          ),
                          border: Border(
                            top: BorderSide(color: palette.primary.withValues(alpha: 0.3), width: 0.6),
                            left: BorderSide(color: palette.primary.withValues(alpha: 0.4), width: 0.8),
                            bottom: BorderSide(color: palette.primary.withValues(alpha: 0.2), width: 0.6),
                          ),
                        ),
                        child: CustomPaint(
                          painter: _SideMortarTexturePainter(),
                        ),
                      ),
                    ),

                  // C. 3D Top Coping Edge (Header slab when tilted downward)
                  if (topVisible)
                    Positioned(
                      top: -topHeight + 1,
                      left: showLeftSide ? -sideWidth + 1 : 0,
                      right: showRightSide ? -sideWidth + 1 : 0,
                      height: topHeight,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Color(0xFF3E3B38),
                              Color(0xFF55524E),
                            ],
                          ),
                          border: Border(
                            top: BorderSide(color: palette.primary.withValues(alpha: 0.5), width: 0.8),
                          ),
                        ),
                      ),
                    ),

                  // D. Main Front Wall Face
                  Container(
                    width: renderWidth,
                    height: renderHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    foregroundDecoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.75),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(1.5),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // 1. Tiled Stone Pattern
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
                              : _buildTiledPattern(
                                  imageUrl: _selectedStone!.arTextureUrl ?? _selectedStone!.imageUrl,
                                  columns: columns,
                                  rows: rows,
                                  renderWidth: renderWidth,
                                  renderHeight: renderHeight,
                                ),

                          // 2. Dynamic Specular Light Glint (shifts with rotation angle!)
                          if (_is3DView)
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment(-0.8 + (activeRotY * 1.6), -0.8 + (activeRotX * 1.6)),
                                  end: Alignment(0.8 + (activeRotY * 1.6), 0.8 + (activeRotX * 1.6)),
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

                          // 3. Subtle Inner Vignette for Relief Depth
                          Container(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: Alignment.center,
                                radius: 0.95,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.25),
                                ],
                                stops: const [0.65, 1.0],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Depth indicator badge
          if (_showDimensions && _is3DView)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.4), width: 0.8),
                ),
                child: Text(
                  'Wall Depth: 4" (100mm) Architectural Slab',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFD4AF37),
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
        ],
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
                '${heightFt.toStringAsFixed(1)} ft',
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
    return Container(
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
          Icon(Icons.view_in_ar_rounded, size: 13, color: palette.primary),
          const SizedBox(width: 5),
          Text(
            _is3DView ? '3D Orbit • Drag & Pinch' : '2D Plan View',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: palette.textPrimary,
            ),
          ),
        ],
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
              setState(() => _scale = (_scale + 0.25).clamp(0.5, 3.5));
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
              setState(() => _scale = (_scale - 0.25).clamp(0.5, 3.5));
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
          _buildPatternChip('Stacked', 'stacked', palette),
          const SizedBox(width: 4),
          _buildPatternChip('Brick Bond', 'brick', palette),
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
            _animateToCamera(targetRotX: 0.12, targetRotY: -0.26, targetScale: 1.0, is3D: true);
          }, _is3DView && _rotY.abs() < 0.40, palette),
          const SizedBox(width: 3),
          _buildCameraChip('Iso', () {
            _animateToCamera(targetRotX: 0.26, targetRotY: -0.45, targetScale: 0.95, is3D: true);
          }, false, palette),
          const SizedBox(width: 3),
          _buildCameraChip('Side 45°', () {
            _animateToCamera(targetRotX: 0.05, targetRotY: -0.68, targetScale: 1.05, is3D: true);
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

  Widget _buildTiledPattern({
    required String? imageUrl,
    required int columns,
    required int rows,
    required double renderWidth,
    required double renderHeight,
  }) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(color: const Color(0xFFC4B5A5));
    }

    final cellW = renderWidth / columns;
    final cellH = renderHeight / rows;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(rows, (rowIndex) {
        final isOffset = _layoutPattern == 'brick' && rowIndex.isOdd;
        return ClipRect(
          child: SizedBox(
            width: renderWidth,
            height: cellH,
            child: OverflowBox(
              minWidth: 0,
              maxWidth: renderWidth + (isOffset ? cellW : 0),
              alignment: Alignment.centerLeft,
              child: Transform.translate(
                offset: Offset(isOffset ? -cellW / 2 : 0, 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(columns + (isOffset ? 1 : 0), (colIndex) {
                    return Container(
                      width: cellW,
                      height: cellH,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.22),
                          width: 0.6,
                        ),
                      ),
                      child: SmartStoneImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        fallbackColor: const Color(0xFFC4B5A5),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        );
      }),
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
                boxesRequired != null ? '$boxesRequired boxes' : 'Coverage unavailable',
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
              width: 145,
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

/// Textured Mortar for Wall 3D Side Depth
class _SideMortarTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..strokeWidth = 1.0;
    for (double y = 14; y < size.height; y += 18) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
