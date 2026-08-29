import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/widgets/error_handler_widget.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';

class MeasureScreen extends ConsumerStatefulWidget {
  const MeasureScreen({super.key});

  @override
  ConsumerState<MeasureScreen> createState() => _MeasureScreenState();
}

class _MeasureScreenState extends ConsumerState<MeasureScreen> with TickerProviderStateMixin {
  final _lengthController = TextEditingController();
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();
  final _wastageController = TextEditingController(text: '10');

  String _unit = 'feet';
  String _shape = 'Rectangle';
  double? _totalArea;
  double? _totalWithWastage;
  double? _boxes;
  bool _hasResult = false;

  late AnimationController _resultController;
  late Animation<double> _resultAnimation;

  final List<String> _units = ['feet', 'meters', 'inches'];
  final List<String> _shapes = ['Rectangle', 'L-Shape', 'Circle'];

  @override
  void initState() {
    super.initState();
    _resultController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _resultAnimation = CurvedAnimation(parent: _resultController, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _lengthController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _wastageController.dispose();
    _resultController.dispose();
    super.dispose();
  }

  void _calculate() {
    final l = double.tryParse(_lengthController.text);
    final w = double.tryParse(_widthController.text);
    final wastage = double.tryParse(_wastageController.text) ?? 10;

    if (l == null || w == null || l <= 0 || w <= 0) {
      showErrorSnackbar(context, null, customMessage: 'Please enter valid room dimensions');
      return;
    }

    double area = l * w;
    if (_shape == 'Circle') {
      area = 3.141592653589793 * w * w; // w is radius
    } else if (_shape == 'L-Shape') {
      final cutout = double.tryParse(_heightController.text) ?? (l * 0.35);
      area = (l * w) - (cutout * (w * 0.35));
    }

    if (_unit == 'meters') area *= 10.764;
    if (_unit == 'inches') area /= 144;

    final withWastage = area * (1 + wastage / 100);
    final boxCount = (withWastage / 10.5).ceil();

    setState(() {
      _totalArea = area;
      _totalWithWastage = withWastage;
      _boxes = boxCount.toDouble();
      _hasResult = true;
    });

    HapticFeedback.mediumImpact();
    _resultController.forward(from: 0);
  }

  void _reset() {
    _lengthController.clear();
    _widthController.clear();
    _heightController.clear();
    setState(() => _hasResult = false);
    _resultController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: palette.textPrimary, size: 18),
        ),
        title: Text(
          'Area Estimator',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Intro Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: palette.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: palette.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.calculate_outlined, color: palette.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Precision Coverage Calculator',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: palette.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Estimate square footage, box requirements and recommended wastage.',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: palette.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Measurement Unit
            _buildSectionHeader('MEASUREMENT UNIT', palette),
            const SizedBox(height: 10),
            Row(
              children: _units.map((u) {
                final isSelected = _unit == u;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _unit = u);
                    },
                    child: Container(
                      margin: EdgeInsets.only(right: u != _units.last ? 8 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? palette.primary : palette.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? palette.primary : palette.border,
                        ),
                      ),
                      child: Text(
                        u.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.white : palette.textSecondary,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // Shape Selector
            _buildSectionHeader('ROOM GEOMETRY', palette),
            const SizedBox(height: 10),
            Row(
              children: _shapes.map((s) {
                final isSelected = _shape == s;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _shape = s);
                    },
                    child: Container(
                      margin: EdgeInsets.only(right: s != _shapes.last ? 8 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? palette.primary.withValues(alpha: 0.12) : palette.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? palette.primary : palette.border,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            s == 'Rectangle'
                                ? Icons.rectangle_outlined
                                : s == 'L-Shape'
                                    ? Icons.turn_right_outlined
                                    : Icons.circle_outlined,
                            color: isSelected ? palette.primary : palette.textTertiary,
                            size: 20,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            s,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? palette.primary : palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // Dimensions Input
            _buildSectionHeader('DIMENSIONS', palette),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildDimInput(
                    controller: _lengthController,
                    label: 'Length',
                    unit: _unit,
                    palette: palette,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDimInput(
                    controller: _widthController,
                    label: _shape == 'Circle' ? 'Radius' : 'Width',
                    unit: _unit,
                    palette: palette,
                  ),
                ),
              ],
            ),

            if (_shape == 'L-Shape') ...[
              const SizedBox(height: 12),
              _buildDimInput(
                controller: _heightController,
                label: 'Cutout Length',
                unit: _unit,
                palette: palette,
              ),
            ],

            const SizedBox(height: 20),

            // Wastage Buffer
            _buildSectionHeader('WASTAGE BUFFER', palette),
            const SizedBox(height: 10),
            Row(
              children: [5, 10, 15, 20].map((pct) {
                final isSelected = _wastageController.text == '$pct';
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _wastageController.text = '$pct');
                    },
                    child: Container(
                      margin: EdgeInsets.only(right: pct != 20 ? 8 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? palette.primary.withValues(alpha: 0.12) : palette.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isSelected ? palette.primary : palette.border),
                      ),
                      child: Text(
                        '$pct% ${pct == 10 ? '(Rec.)' : ''}',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? palette.primary : palette.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 28),

            // Calculate Button
            Row(
              children: [
                if (_hasResult)
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: _reset,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.textSecondary,
                        side: BorderSide(color: palette.border),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('Reset', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                if (_hasResult) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _calculate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: Text('Calculate Materials', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),

            // Results Card & 3D Interactive Wall Representation
            if (_hasResult) ...[
              const SizedBox(height: 24),
              AnimatedBuilder(
                animation: _resultAnimation,
                builder: (_, child) => Opacity(
                  opacity: _resultAnimation.value,
                  child: Transform.translate(
                    offset: Offset(0, 16 * (1 - _resultAnimation.value)),
                    child: child,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: palette.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.verified_outlined, color: palette.primary, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Estimated Material Breakdown',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: palette.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _buildResultCell('Net Area', '${_totalArea!.toStringAsFixed(1)} sq ft', palette),
                              _buildResultCell('With Buffer', '${_totalWithWastage!.toStringAsFixed(1)} sq ft', palette),
                              _buildResultCell('Boxes Needed', '${_boxes!.toInt()}', palette, isHighlight: true),
                            ],
                          ),
                          const Divider(height: 24),
                          Text(
                            '* Standard slab box coverage: ~10.5 sq ft per box.',
                            style: GoogleFonts.inter(fontSize: 11, color: palette.textTertiary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Proportional Interactive Wall Visualization Card
                    _build3DWallPreview(palette),
                  ],
                ),
              ),
            ],


            const SizedBox(height: 28),

            // AR Camera Bridge
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: palette.surfaceDark,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.view_in_ar_outlined, color: palette.primary, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Live Camera Measurement',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Point your device at your wall to automatically calculate perspective dimensions in real time.',
                    style: GoogleFonts.inter(fontSize: 12, color: palette.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/live-ai'),
                    icon: const Icon(Icons.videocam_outlined, size: 18),
                    label: const Text('Open Live AR Camera →'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, LuxuryPalette palette) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.8,
        color: palette.textTertiary,
      ),
    );
  }

  Widget _buildDimInput({
    required TextEditingController controller,
    required String label,
    required String unit,
    required LuxuryPalette palette,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: palette.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(fontSize: 12, color: palette.textSecondary),
        suffixText: unit == 'feet' ? 'ft' : unit == 'meters' ? 'm' : 'in',
        suffixStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: palette.textTertiary),
        filled: true,
        fillColor: palette.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.primary, width: 1.5),
        ),
      ),
    );
  }

  bool _is3DView = true;

  Widget _build3DWallPreview(LuxuryPalette palette) {
    final l = double.tryParse(_lengthController.text) ?? 10.0;
    final w = double.tryParse(_widthController.text) ?? 10.0;
    final unitLabel = _unit == 'feet' ? 'ft' : _unit == 'meters' ? 'm' : 'in';

    // Calculate proportional grid rows and columns (e.g. 2x1 ft tiles or slabs)
    final cols = (l / 2.0).clamp(3, 8).round();
    final rows = (w / 1.5).clamp(3, 6).round();
    final totalTiles = cols * rows;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.view_in_ar_rounded, color: palette.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Interactive Wall Layout',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                    ),
                  ),
                ],
              ),
              // 2D / 3D Toggle Pill
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: palette.surfaceDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: palette.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _is3DView = false);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: !_is3DView ? palette.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '2D Elevation',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: !_is3DView ? Colors.white : palette.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _is3DView = true);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _is3DView ? palette.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '3D Isometric',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: _is3DView ? Colors.white : palette.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Proportional Wall Grid with Dimension Labels
          Center(
            child: SizedBox(
              height: 220,
              width: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Top Dimension callout
                  Positioned(
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: palette.surfaceDark,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: palette.border),
                      ),
                      child: Text(
                        'Width: ${l.toStringAsFixed(1)} $unitLabel',
                        style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: palette.primary),
                      ),
                    ),
                  ),

                  // Left Dimension callout
                  Positioned(
                    left: 4,
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: palette.surfaceDark,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: palette.border),
                        ),
                        child: Text(
                          'Height: ${w.toStringAsFixed(1)} $unitLabel',
                          style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: palette.primary),
                        ),
                      ),
                    ),
                  ),

                  // The Wall Representation
                  Padding(
                    padding: const EdgeInsets.only(left: 36, top: 24, right: 12, bottom: 8),
                    child: Transform(
                      transform: _is3DView
                          ? (Matrix4.identity()
                              ..setEntry(3, 2, 0.0015)
                              ..rotateX(0.25)
                              ..rotateY(-0.25)
                              ..rotateZ(0.04))
                          : Matrix4.identity(),
                      alignment: Alignment.center,
                      child: Container(
                        height: 150,
                        width: 240,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C2420),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: palette.primary, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 18,
                              offset: const Offset(8, 12),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Stone texture background
                              Image.asset(
                                'assets/images/grande_ledge_ta02.png',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFF382E2B)),
                              ),
                              // Grout Grid Lines
                              Column(
                                children: List.generate(rows, (r) {
                                  return Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Colors.black.withValues(alpha: 0.5),
                                            width: 1.0,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: List.generate(cols, (c) {
                                          return Expanded(
                                            child: Container(
                                              decoration: BoxDecoration(
                                                border: Border(
                                                  right: BorderSide(
                                                    color: Colors.black.withValues(alpha: 0.5),
                                                    width: 1.0,
                                                  ),
                                                ),
                                              ),
                                              child: Center(
                                                child: Container(
                                                  width: 4,
                                                  height: 4,
                                                  decoration: BoxDecoration(
                                                    color: palette.primary.withValues(alpha: 0.4),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: palette.surfaceDark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Grid Pattern: $cols cols × $rows rows',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: palette.textSecondary),
                ),
                Text(
                  '~$totalTiles Course Tiles',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: palette.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCell(String label, String value, LuxuryPalette palette, {bool isHighlight = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: palette.textTertiary)),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: isHighlight ? 20 : 15,
              fontWeight: FontWeight.w800,
              color: isHighlight ? palette.primary : palette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

