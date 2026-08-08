import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/typography.dart';
import 'package:grazia_stones/shared/theme/spacing.dart';
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
    _resultController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid dimensions')),
      );
      return;
    }

    double area = l * w;

    // Convert to sq ft if needed
    if (_unit == 'meters') area *= 10.764;
    if (_unit == 'inches') area /= 144;

    final withWastage = area * (1 + wastage / 100);
    // Assuming 10.5 sqft per box (standard)
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
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_ios_new, color: palette.textPrimary, size: 20),
        ),
        title: Text('Area Calculator', style: GLuxuryTypography.h2.copyWith(color: palette.textPrimary)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: palette.primaryGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(Icons.calculate_outlined, color: palette.background, size: 36),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stone Coverage Calculator',
                          style: GLuxuryTypography.h3.copyWith(
                            color: palette.background,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Calculate how many boxes you need',
                          style: GLuxuryTypography.bodySmall.copyWith(
                            color: palette.background.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            GLuxurySpacing.gapXl,

            // Unit selector
            _SectionLabel('Measurement Unit', palette),
            GLuxurySpacing.gapSm,
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
                        style: GLuxuryTypography.labelSmall.copyWith(
                          color: isSelected ? palette.background : palette.textSecondary,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            GLuxurySpacing.gapBase,

            // Shape selector
            _SectionLabel('Room Shape', palette),
            GLuxurySpacing.gapSm,
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
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? palette.primary.withValues(alpha: 0.15) : palette.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? palette.primary : palette.border,
                          width: isSelected ? 1.5 : 0.8,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            s == 'Rectangle' ? Icons.rectangle_outlined
                              : s == 'L-Shape' ? Icons.turn_right_outlined
                              : Icons.circle_outlined,
                            color: isSelected ? palette.primary : palette.textTertiary,
                            size: 20,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            s,
                            textAlign: TextAlign.center,
                            style: GLuxuryTypography.labelSmall.copyWith(
                              color: isSelected ? palette.primary : palette.textSecondary,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            GLuxurySpacing.gapBase,

            // Dimension inputs
            _SectionLabel('Dimensions', palette),
            GLuxurySpacing.gapSm,
            Row(
              children: [
                Expanded(
                  child: _DimInput(
                    controller: _lengthController,
                    label: 'Length',
                    unit: _unit,
                    palette: palette,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DimInput(
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
              Row(
                children: [
                  Expanded(
                    child: _DimInput(
                      controller: _heightController,
                      label: 'Cut Length',
                      unit: _unit,
                      palette: palette,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ],

            GLuxurySpacing.gapBase,

            // Wastage
            _SectionLabel('Wastage %', palette),
            GLuxurySpacing.gapSm,
            Row(
              children: [10, 15, 20].map((pct) {
                final isSelected = _wastageController.text == '$pct';
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _wastageController.text = '$pct'),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? palette.primary.withValues(alpha: 0.15) : palette.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isSelected ? palette.primary : palette.border),
                      ),
                      child: Text(
                        '$pct%',
                        textAlign: TextAlign.center,
                        style: GLuxuryTypography.bodySmall.copyWith(
                          color: isSelected ? palette.primary : palette.textSecondary,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            GLuxurySpacing.gapXl,

            // Calculate button
            Row(
              children: [
                if (_hasResult)
                  Expanded(
                    flex: 1,
                    child: OutlinedButton.icon(
                      onPressed: _reset,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Reset'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.textSecondary,
                        side: BorderSide(color: palette.border),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ),
                if (_hasResult) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _calculate,
                    icon: const Icon(Icons.calculate, size: 18),
                    label: const Text('Calculate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.primary,
                      foregroundColor: palette.background,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),

            // Results
            if (_hasResult) ...[
              GLuxurySpacing.gapXl,
              AnimatedBuilder(
                animation: _resultAnimation,
                builder: (_, child) => Opacity(
                  opacity: _resultAnimation.value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - _resultAnimation.value)),
                    child: child,
                  ),
                ),
                child: _ResultCard(
                  palette: palette,
                  area: _totalArea!,
                  areaWithWastage: _totalWithWastage!,
                  boxes: _boxes!,
                  unit: _unit,
                ),
              ),
            ],

            const SizedBox(height: 40),

            // Camera Scan Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: palette.primary.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.camera_alt_outlined, color: palette.primary, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Scan Room with Camera',
                          style: GLuxuryTypography.h3.copyWith(color: palette.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Use AI-powered camera to automatically detect walls and measure your room',
                    style: GLuxuryTypography.bodySmall.copyWith(color: palette.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => context.push('/live-ai'),
                          icon: const Icon(Icons.camera_roll_outlined, size: 18),
                          label: const Text('Live AI Detection'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: palette.primary,
                            foregroundColor: palette.background,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.push('/ar-view'),
                          icon: Icon(Icons.view_in_ar_outlined, size: 18, color: palette.primary),
                          label: Text(
                            'AR Visualizer',
                            style: TextStyle(color: palette.primary),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: palette.primary.withValues(alpha: 0.5)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Tips
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tips_and_updates_outlined, color: palette.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Pro Tips',
                        style: GLuxuryTypography.h3.copyWith(color: palette.textPrimary),
                      ),
                    ],
                  ),
                  GLuxurySpacing.gapSm,
                  _Tip('Always add 10-15% wastage for cuts and breakage', palette),
                  _Tip('For complex patterns, add 20% wastage', palette),
                  _Tip('1 box covers approx 10.5 sq ft', palette),
                  _Tip('Measure twice, order once!', palette),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final LuxuryPalette palette;
  const _SectionLabel(this.text, this.palette);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: GLuxuryTypography.bodySmall.copyWith(
      color: palette.textSecondary,
      fontWeight: FontWeight.w600,
    ),
  );
}

class _DimInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String unit;
  final LuxuryPalette palette;
  const _DimInput({required this.controller, required this.label, required this.unit, required this.palette});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: GLuxuryTypography.bodyMedium.copyWith(color: palette.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GLuxuryTypography.bodySmall.copyWith(color: palette.textSecondary),
        suffixText: unit == 'feet' ? 'ft' : unit == 'meters' ? 'm' : 'in',
        suffixStyle: GLuxuryTypography.bodySmall.copyWith(color: palette.textTertiary),
        filled: true,
        fillColor: palette.surface,
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
}

class _ResultCard extends StatelessWidget {
  final LuxuryPalette palette;
  final double area;
  final double areaWithWastage;
  final double boxes;
  final String unit;
  const _ResultCard({required this.palette, required this.area, required this.areaWithWastage, required this.boxes, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: palette.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: palette.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline, color: palette.background, size: 22),
              const SizedBox(width: 8),
              Text(
                'Calculation Result',
                style: GLuxuryTypography.h3.copyWith(color: palette.background, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _ResultItem(label: 'Net Area', value: '${area.toStringAsFixed(1)} sq ft', palette: palette),
              _ResultItem(label: 'With Wastage', value: '${areaWithWastage.toStringAsFixed(1)} sq ft', palette: palette),
              _ResultItem(label: 'Boxes Needed', value: '${boxes.toInt()}', palette: palette, isBig: true),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '* Based on 10.5 sq ft per box (standard)',
            style: GLuxuryTypography.labelSmall.copyWith(color: palette.background.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}

class _ResultItem extends StatelessWidget {
  final String label;
  final String value;
  final LuxuryPalette palette;
  final bool isBig;
  const _ResultItem({required this.label, required this.value, required this.palette, this.isBig = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GLuxuryTypography.labelSmall.copyWith(color: palette.background.withValues(alpha: 0.7))),
          const SizedBox(height: 4),
          Text(
            value,
            style: (isBig ? GLuxuryTypography.h1 : GLuxuryTypography.h3).copyWith(
              color: palette.background,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  final String text;
  final LuxuryPalette palette;
  const _Tip(this.text, this.palette);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.arrow_right, color: palette.primary, size: 18),
          const SizedBox(width: 4),
          Expanded(
            child: Text(text, style: GLuxuryTypography.bodySmall.copyWith(color: palette.textSecondary)),
          ),
        ],
      ),
    );
  }
}
