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
import 'package:grazia_stones/shared/widgets/smart_stone_image.dart';

/// Next-Generation Proportional 2D/3D Wall Visualizer & Tile Estimation Engine.
/// Allows architects and clients to:
/// 1. Enter precise wall dimensions with any unit (ft, in, m, cm).
/// 2. View proportional wall tiling at exact scale in 2D Plan or 3D Spatial Perspective.
/// 3. Toggle tile layout patterns: Stacked Grid, Running Bond (Brick), and Vertical Stack.
/// 4. Adjust wastage (5% - 20%) with real-time box count and financial calculation.
/// 5. 1-Tap Export Architectural Specification & Tile Calculation PDF.
/// 6. 1-Tap Add Required Boxes to Cart or Request Factory Quote.
class TileWallVisualizerScreen extends ConsumerStatefulWidget {
  final String? initialStoneId;

  const TileWallVisualizerScreen({super.key, this.initialStoneId});

  @override
  ConsumerState<TileWallVisualizerScreen> createState() => _TileWallVisualizerScreenState();
}

class _TileWallVisualizerScreenState extends ConsumerState<TileWallVisualizerScreen> {
  final _widthController = TextEditingController(text: '12');
  final _heightController = TextEditingController(text: '10');
  String _unit = 'ft';
  double _wastagePercent = 10;
  Stone? _selectedStone;
  bool _is3DView = false;
  String _layoutPattern = 'stacked'; // 'stacked', 'brick', 'vertical'
  bool _isExportingPdf = false;
  final TransformationController _viewerController = TransformationController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    _viewerController.dispose();
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

  void _resetView() {
    _viewerController.value = Matrix4.identity();
    HapticFeedback.selectionClick();
  }

  Future<void> _exportPdfSpecSheet(double widthFt, double heightFt, double netArea, double grossArea, int boxes, int totalTiles, double cost) async {
    if (_selectedStone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a stone material first to export specification sheet.'),
          behavior: SnackBarBehavior.floating,
        ),
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
        boxesRequired: boxes,
        totalTiles: totalTiles,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to generate PDF: $e'),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  void _addBoxesToCart(double grossArea) {
    if (_selectedStone == null) return;
    ref.read(cartProvider.notifier).addItem(_selectedStone!, quantity: grossArea.ceil());
    HapticFeedback.heavyImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${grossArea.toStringAsFixed(0)} sq.ft of ${_selectedStone!.name} to Project Cart!'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'View Cart',
          textColor: Colors.white,
          onPressed: () => context.push('/cart'),
        ),
      ),
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

    int boxesRequired = 0;
    int totalTiles = 0;
    double estimatedCost = 0.0;

    if (_selectedStone != null && validDimensions) {
      final coverage = _selectedStone!.sqftPerBox > 0 ? _selectedStone!.sqftPerBox : 4.5;
      boxesRequired = (grossAreaSqFt / coverage).ceil();
      final tileW = (_selectedStone!.lengthCm ?? 60.0) / 30.48;
      final tileH = (_selectedStone!.widthCm ?? 30.0) / 30.48;
      final cols = (widthFt / tileW).ceil();
      final rows = (heightFt / tileH).ceil();
      totalTiles = (cols * rows * (1 + _wastagePercent / 100)).ceil();
      estimatedCost = grossAreaSqFt * _selectedStone!.pricePerSqFt;
    }

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: palette.textPrimary, size: 18),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '3D Wall & Tile Calculator',
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
            Text(
              'Precision Proportional Geometry',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: palette.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          // 2D / 3D Toggle
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              avatar: Icon(
                _is3DView ? Icons.view_in_ar_rounded : Icons.crop_square_rounded,
                size: 14,
                color: palette.primary,
              ),
              label: Text(
                _is3DView ? '3D View' : '2D Plan',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: palette.primary,
                ),
              ),
              backgroundColor: palette.primary.withValues(alpha: 0.12),
              side: BorderSide(color: palette.primary.withValues(alpha: 0.3)),
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() => _is3DView = !_is3DView);
              },
            ),
          ),
          IconButton(
            icon: Icon(Icons.restart_alt_rounded, color: palette.textSecondary, size: 20),
            tooltip: 'Reset Zoom',
            onPressed: _resetView,
          ),
        ],
      ),
      body: Column(
        children: [
          // Dimension Controls & Wastage Header
          _buildDimensionControls(palette, isDark),

          // Interactive Proportional Wall Canvas Viewport
          Expanded(
            child: Stack(
              children: [
                Container(
                  color: isDark ? const Color(0xFF141416) : const Color(0xFFF1EFEA),
                  child: !validDimensions
                      ? Center(
                          child: Text(
                            'Enter wall dimensions above to visualize tiling.',
                            style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 13),
                          ),
                        )
                      : InteractiveViewer(
                          transformationController: _viewerController,
                          minScale: 0.4,
                          maxScale: 6.0,
                          child: Center(
                            child: _buildProportionalWall(
                              widthFt: widthFt,
                              heightFt: heightFt,
                              palette: palette,
                              isDark: isDark,
                            ),
                          ),
                        ),
                ),

                // Pattern Switcher Overlay (Bottom Left of Canvas)
                Positioned(
                  left: 14,
                  bottom: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E1E1E).withValues(alpha: 0.9)
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
          stonesAsync.when(
            data: (stones) {
              if (_selectedStone == null && stones.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _selectedStone == null) {
                    setState(() => _selectedStone = stones.first);
                  }
                });
              }
              return _buildProductStrip(stones, palette, isDark);
            },
            loading: () => const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildDimensionControls(dynamic palette, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Width Input
              Expanded(
                child: TextField(
                  controller: _widthController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: palette.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Wall Width',
                    labelStyle: GoogleFonts.inter(fontSize: 11, color: palette.textSecondary),
                    prefixIcon: Icon(Icons.straighten_rounded, size: 16, color: palette.primary),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),

              // Height Input
              Expanded(
                child: TextField(
                  controller: _heightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: palette.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Wall Height',
                    labelStyle: GoogleFonts.inter(fontSize: 11, color: palette.textSecondary),
                    prefixIcon: Icon(Icons.height_rounded, size: 16, color: palette.primary),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),

              // Unit Selector Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: palette.border),
                  color: palette.background,
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

          // Wastage Slider
          Row(
            children: [
              Text(
                'Wastage: ${_wastagePercent.toInt()}%',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: palette.textSecondary),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    thumbColor: palette.primary,
                    activeTrackColor: palette.primary,
                    inactiveTrackColor: palette.primary.withValues(alpha: 0.2),
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
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

  Widget _buildPatternChip(String label, String value, dynamic palette) {
    final isSelected = _layoutPattern == value;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _layoutPattern = value);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? palette.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.black : palette.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildProportionalWall({
    required double widthFt,
    required double heightFt,
    required dynamic palette,
    required bool isDark,
  }) {
    const maxRenderSize = 340.0;
    final aspect = widthFt / heightFt;
    final renderWidth = aspect >= 1 ? maxRenderSize : maxRenderSize * aspect;
    final renderHeight = aspect >= 1 ? maxRenderSize / aspect : maxRenderSize;

    final tileWFt = (_selectedStone?.lengthCm ?? 60.0) / 30.48;
    final tileHFt = (_selectedStone?.widthCm ?? 30.0) / 30.48;

    final columns = (widthFt / tileWFt).ceil().clamp(1, 150);
    final rows = (heightFt / tileHFt).ceil().clamp(1, 150);

    return Transform(
      transform: _is3DView
          ? (Matrix4.identity()
            ..setEntry(3, 2, 0.0015)
            ..rotateY(-0.18)
            ..rotateX(0.08))
          : Matrix4.identity(),
      alignment: Alignment.center,
      child: Container(
        width: renderWidth,
        height: renderHeight,
        decoration: BoxDecoration(
          border: Border.all(
            color: palette.primary.withValues(alpha: 0.6),
            width: 2.5,
          ),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _is3DView ? 0.35 : 0.15),
              blurRadius: _is3DView ? 24 : 12,
              offset: Offset(_is3DView ? 14 : 0, _is3DView ? 12 : 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: _selectedStone == null
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

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rows,
      itemBuilder: (context, rowIndex) {
        final isOffset = _layoutPattern == 'brick' && rowIndex.isOdd;
        return SizedBox(
          height: cellH,
          child: Row(
            children: List.generate(columns + (isOffset ? 1 : 0), (colIndex) {
              return Container(
                width: cellW,
                height: cellH,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.15),
                    width: 0.6,
                  ),
                ),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: const Color(0xFFC4B5A5)),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildCalculationSummary({
    required dynamic palette,
    required bool isDark,
    required double widthFt,
    required double heightFt,
    required double netAreaSqFt,
    required double grossAreaSqFt,
    required int boxesRequired,
    required int totalTiles,
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
              _buildStatMetric('Boxes Needed', '$boxesRequired boxes', palette, isHighlight: true),
              _buildStatMetric('Est. Value', '₹${estimatedCost.toStringAsFixed(0)}', palette, isGold: true),
            ],
          ),
          const SizedBox(height: 12),

          // Action Buttons: PDF Export, Add to Cart, Get Quote
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
                      : const Icon(Icons.picture_as_pdf_rounded, size: 16),
                  label: Text(
                    'Export PDF',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Add to Cart Button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _addBoxesToCart(grossAreaSqFt),
                  icon: const Icon(Icons.shopping_bag_rounded, size: 16, color: Colors.black),
                  label: Text(
                    'Add to Cart',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.primary,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Get Factory Quote
              IconButton.filledTonal(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  context.push('/quotes/new?stoneId=${_selectedStone?.id ?? ''}');
                },
                icon: const Icon(Icons.request_quote_rounded, size: 18),
                tooltip: 'Get Factory Quote',
              ),
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
      height: 94,
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: isDark ? const Color(0xFF161616) : Colors.white,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        scrollDirection: Axis.horizontal,
        itemCount: stones.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final stone = stones[index];
          final isSelected = _selectedStone?.id == stone.id;

          return InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedStone = stone);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 130,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected
                    ? palette.primary.withValues(alpha: 0.12)
                    : palette.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? palette.primary : palette.border,
                  width: isSelected ? 1.8 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 44,
                      height: 44,
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
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: palette.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹${stone.pricePerSqFt.toStringAsFixed(0)}/sqft',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: palette.primary,
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
