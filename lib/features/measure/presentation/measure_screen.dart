import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/widgets/animated_widgets.dart';
import 'package:grazia_stones/core/widgets/error_handler_widget.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/shared/widgets/luxury_toast.dart';

class MeasureScreen extends ConsumerStatefulWidget {
  const MeasureScreen({super.key});

  @override
  ConsumerState<MeasureScreen> createState() => _MeasureScreenState();
}

class _MeasureScreenState extends ConsumerState<MeasureScreen> with TickerProviderStateMixin {
  final _lengthController = TextEditingController(text: '12');
  final _widthController = TextEditingController(text: '10');
  final _heightController = TextEditingController();
  final _wastageController = TextEditingController(text: '10');

  String _unit = 'feet';
  String _shape = 'Rectangle';
  double? _totalArea;
  double? _totalWithWastage;
  double? _boxes;
  double? _estimatedCost;
  bool _hasResult = false;
  bool _is3DView = true;

  late AnimationController _resultController;
  late Animation<double> _resultAnimation;

  final List<Map<String, String>> _units = [
    {'id': 'feet', 'label': 'FEET', 'sym': 'ft'},
    {'id': 'meters', 'label': 'METERS', 'sym': 'm'},
    {'id': 'inches', 'label': 'INCHES', 'sym': 'in'},
  ];

  final List<Map<String, dynamic>> _shapes = [
    {
      'id': 'Rectangle',
      'label': 'Rectangle',
      'sub': 'Standard Wall / Floor',
      'icon': Icons.crop_landscape_rounded,
    },
    {
      'id': 'L-Shape',
      'label': 'L-Shape',
      'sub': 'Corner / Offset Return',
      'icon': Icons.turn_right_rounded,
    },
    {
      'id': 'Circle',
      'label': 'Circular',
      'sub': 'Rotunda / Curved Feature',
      'icon': Icons.album_outlined,
    },
  ];

  final List<Map<String, dynamic>> _wastageOptions = [
    {'pct': 5, 'label': '5% Minimal', 'desc': 'Straight Lay'},
    {'pct': 10, 'label': '10% Recommended', 'desc': 'Standard'},
    {'pct': 15, 'label': '15% Complex', 'desc': 'Herringbone / Cuts'},
    {'pct': 20, 'label': '20% Custom', 'desc': 'Diagonal / Arches'},
  ];

  final List<Map<String, dynamic>> _quickPresets = [
    {'title': "10' × 10'", 'l': '10', 'w': '10', 'desc': 'Powder Wall'},
    {'title': "12' × 15'", 'l': '12', 'w': '15', 'desc': 'Living Feature'},
    {'title': "16' × 20'", 'l': '16', 'w': '20', 'desc': 'Master Suite'},
    {'title': "20' × 24'", 'l': '20', 'w': '24', 'desc': 'Grand Façade'},
  ];

  @override
  void initState() {
    super.initState();
    _resultController = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _resultAnimation = CurvedAnimation(parent: _resultController, curve: Curves.easeOutCubic);
    _calculate(silent: true);
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

  void _calculate({bool silent = false}) {
    final l = double.tryParse(_lengthController.text);
    final w = double.tryParse(_widthController.text);
    final wastage = double.tryParse(_wastageController.text) ?? 10;

    if (l == null || w == null || l <= 0 || w <= 0) {
      if (!silent) {
        showErrorSnackbar(context, null, customMessage: 'Please enter valid dimensions');
      }
      return;
    }

    double area = l * w;
    if (_shape == 'Circle') {
      area = 3.141592653589793 * w * w;
    } else if (_shape == 'L-Shape') {
      final cutout = double.tryParse(_heightController.text) ?? (l * 0.35);
      area = (l * w) - (cutout * (w * 0.35));
    }

    if (_unit == 'meters') area *= 10.764;
    if (_unit == 'inches') area /= 144;

    final withWastage = area * (1 + wastage / 100);
    final boxCount = (withWastage / 10.5).ceil();
    final estCost = withWastage * 340;

    setState(() {
      _totalArea = area;
      _totalWithWastage = withWastage;
      _boxes = boxCount.toDouble();
      _estimatedCost = estCost;
      _hasResult = true;
    });

    if (!silent) {
      HapticFeedback.mediumImpact();
    }
    _resultController.forward(from: 0);
  }

  void _applyPreset(String l, String w) {
    HapticFeedback.selectionClick();
    setState(() {
      _lengthController.text = l;
      _widthController.text = w;
      _shape = 'Rectangle';
      _unit = 'feet';
    });
    _calculate(silent: true);
  }

  void _reset() {
    HapticFeedback.lightImpact();
    _lengthController.clear();
    _widthController.clear();
    _heightController.clear();
    setState(() => _hasResult = false);
    _resultController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: ApplePressable(
              onTap: () => context.push('/measure/tile-visualizer'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      palette.primary.withValues(alpha: 0.15),
                      palette.primary.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: palette.primary.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.view_in_ar_rounded, size: 14, color: palette.primary),
                    const SizedBox(width: 5),
                    Text(
                      '3D Visualizer',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: palette.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroCard(palette, isDark),
                const SizedBox(height: 20),
                _buildSectionHeader('QUICK ARCHITECTURAL PRESETS', palette),
                const SizedBox(height: 10),
                _buildQuickPresetsRow(palette),
                const SizedBox(height: 22),
                _buildSectionHeader('MEASUREMENT UNIT', palette),
                const SizedBox(height: 10),
                _buildUnitSelector(palette),
                const SizedBox(height: 22),
                _buildSectionHeader('ROOM GEOMETRY', palette),
                const SizedBox(height: 10),
                _buildGeometrySelector(palette),
                const SizedBox(height: 22),
                _buildSectionHeader('ROOM DIMENSIONS', palette),
                const SizedBox(height: 10),
                _buildDimensionInputs(palette),
                const SizedBox(height: 22),
                _buildSectionHeader('RECOMMENDED CUT WASTAGE', palette),
                const SizedBox(height: 10),
                _buildWastageSelector(palette),
                const SizedBox(height: 26),
                _buildActionButtons(palette),
                if (_hasResult && _totalArea != null) ...[
                  const SizedBox(height: 26),
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
                        _buildBreakdownCard(palette, isDark),
                        const SizedBox(height: 20),
                        _build3DWallPreview(palette, isDark),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 26),
                _buildArBanner(palette, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, LuxuryPalette palette) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 11,
          decoration: BoxDecoration(
            color: palette.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 7),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: palette.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard(LuxuryPalette palette, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      palette.primary.withValues(alpha: 0.25),
                      palette.primary.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: palette.primary.withValues(alpha: 0.35)),
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
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Calculate surface area, packaging box requirements, edge cut wastage, and real-time material investment.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: palette.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildFeaturePill('LIDAR READY', palette),
              const SizedBox(width: 6),
              _buildFeaturePill('10.5 SQFT/BOX', palette),
              const SizedBox(width: 6),
              _buildFeaturePill('3D ISOMETRIC', palette),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturePill(String text, LuxuryPalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: palette.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.primary.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: palette.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildQuickPresetsRow(LuxuryPalette palette) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _quickPresets.map((preset) {
          final isCurrent = _lengthController.text == preset['l'] && _widthController.text == preset['w'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ApplePressable(
              onTap: () => _applyPreset(preset['l'] as String, preset['w'] as String),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: isCurrent ? palette.primary.withValues(alpha: 0.14) : palette.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCurrent ? palette.primary : palette.border,
                    width: isCurrent ? 1.5 : 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preset['title'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: isCurrent ? palette.primary : palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      preset['desc'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: palette.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildUnitSelector(LuxuryPalette palette) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: _units.map((u) {
          final isSelected = _unit == u['id'];
          return Expanded(
            child: ApplePressable(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _unit = u['id']!);
                _calculate(silent: true);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? palette.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected ? Border.all(color: palette.border) : null,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      u['label']!,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? palette.primary : palette.textSecondary,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '(${u['sym']})',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: isSelected ? palette.textSecondary : palette.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGeometrySelector(LuxuryPalette palette) {
    return Row(
      children: _shapes.map((s) {
        final isSelected = _shape == s['id'];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: s != _shapes.last ? 8 : 0),
            child: ApplePressable(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _shape = s['id'] as String);
                _calculate(silent: true);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                decoration: BoxDecoration(
                  color: isSelected ? palette.primary.withValues(alpha: 0.12) : palette.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? palette.primary : palette.border,
                    width: isSelected ? 1.6 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: palette.primary.withValues(alpha: 0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    Icon(
                      s['icon'] as IconData,
                      color: isSelected ? palette.primary : palette.textTertiary,
                      size: 22,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s['label'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? palette.primary : palette.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s['sub'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        color: palette.textTertiary,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDimensionInputs(LuxuryPalette palette) {
    final sym = _unit == 'feet' ? 'ft' : _unit == 'meters' ? 'm' : 'in';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildDimInputField(
                controller: _lengthController,
                label: 'Room Length / Width',
                icon: Icons.straighten_rounded,
                suffix: sym,
                palette: palette,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDimInputField(
                controller: _widthController,
                label: _shape == 'Circle' ? 'Radius' : 'Wall Height / Depth',
                icon: Icons.height_rounded,
                suffix: sym,
                palette: palette,
              ),
            ),
          ],
        ),
        if (_shape == 'L-Shape') ...[
          const SizedBox(height: 12),
          _buildDimInputField(
            controller: _heightController,
            label: 'Cutout Length (Return Wall Offset)',
            icon: Icons.crop_free_rounded,
            suffix: sym,
            palette: palette,
          ),
        ],
      ],
    );
  }

  Widget _buildDimInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String suffix,
    required LuxuryPalette palette,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: GoogleFonts.inter(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        color: palette.textPrimary,
      ),
      onChanged: (_) => _calculate(silent: true),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(fontSize: 12, color: palette.textSecondary),
        prefixIcon: Icon(icon, size: 17, color: palette.primary),
        suffixIcon: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          alignment: Alignment.center,
          width: 36,
          child: Text(
            suffix,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: palette.textTertiary),
          ),
        ),
        filled: true,
        fillColor: palette.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.primary, width: 1.6),
        ),
      ),
    );
  }

  Widget _buildWastageSelector(LuxuryPalette palette) {
    return Row(
      children: _wastageOptions.map((opt) {
        final pct = opt['pct'] as int;
        final isSelected = _wastageController.text == '$pct';
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: opt != _wastageOptions.last ? 6 : 0),
            child: ApplePressable(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _wastageController.text = '$pct');
                _calculate(silent: true);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                decoration: BoxDecoration(
                  color: isSelected ? palette.primary.withValues(alpha: 0.14) : palette.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? palette.primary : palette.border,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '$pct%',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? palette.primary : palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      opt['desc'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: isSelected ? palette.primary : palette.textTertiary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionButtons(LuxuryPalette palette) {
    return Row(
      children: [
        if (_hasResult) ...[
          ApplePressable(
            onTap: _reset,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: palette.border),
              ),
              alignment: Alignment.center,
              child: Text(
                'Reset',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: palette.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: ApplePressable(
            onTap: () => _calculate(silent: false),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    palette.primary,
                    palette.primary.withValues(alpha: 0.85),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: palette.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calculate_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Calculate Materials & Specs',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBreakdownCard(LuxuryPalette palette, bool isDark) {
    final net = _totalArea ?? 0;
    final withWastage = _totalWithWastage ?? 0;
    final boxes = (_boxes ?? 0).toInt();
    final cost = _estimatedCost ?? 0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: palette.surface.withValues(alpha: isDark ? 0.85 : 0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: palette.primary.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: palette.primary.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 6),
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
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: palette.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.verified_rounded, color: palette.primary, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Architectural Specification',
                        style: GoogleFonts.inter(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: palette.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'ESTIMATE',
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: palette.primary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _buildMetricCell('NET AREA', '${net.toStringAsFixed(1)} sq ft', 'Surface', palette),
                  Container(width: 1, height: 38, color: palette.border),
                  _buildMetricCell('WITH BUFFER', '${withWastage.toStringAsFixed(1)} sq ft', '+${_wastageController.text}% cut', palette),
                ],
              ),
              const Divider(height: 28),
              Row(
                children: [
                  _buildMetricCell(
                    'BOXES NEEDED',
                    '$boxes Boxes',
                    '~10.5 sq ft/box',
                    palette,
                    highlight: true,
                  ),
                  Container(width: 1, height: 38, color: palette.border),
                  _buildMetricCell(
                    'EST. MATERIAL',
                    '₹${cost.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                    '@ ₹340 / sq ft avg',
                    palette,
                    highlight: true,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ApplePressable(
                      onTap: () => context.push('/measure/tile-visualizer'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          color: palette.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: palette.primary.withValues(alpha: 0.3)),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.picture_as_pdf_outlined, size: 14, color: palette.primary),
                            const SizedBox(width: 6),
                            Text(
                              'Full Spec & PDF Sheet →',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: palette.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ApplePressable(
                    onTap: () {
                      LuxuryToast.show(context, message: '$boxes boxes added to estimate schedule.');
                      context.push('/cart');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: palette.surfaceDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: palette.border),
                      ),
                      child: Icon(Icons.shopping_bag_outlined, size: 16, color: palette.textPrimary),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCell(String label, String value, String sub, LuxuryPalette palette, {bool highlight = false}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: palette.textTertiary,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: highlight ? 18 : 15,
                fontWeight: FontWeight.w800,
                color: highlight ? palette.primary : palette.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: palette.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _build3DWallPreview(LuxuryPalette palette, bool isDark) {
    final l = double.tryParse(_lengthController.text) ?? 12.0;
    final w = double.tryParse(_widthController.text) ?? 10.0;
    final unitLabel = _unit == 'feet' ? 'ft' : _unit == 'meters' ? 'm' : 'in';

    final cols = (l / 2.0).clamp(3, 8).round();
    final rows = (w / 1.5).clamp(3, 6).round();
    final totalTiles = cols * rows;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 5),
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
                  Icon(Icons.view_in_ar_rounded, color: palette.primary, size: 19),
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
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: palette.surfaceDark,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: palette.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ApplePressable(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _is3DView = false);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: !_is3DView ? palette.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '2D Elevation',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: !_is3DView ? Colors.white : palette.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    ApplePressable(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _is3DView = true);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _is3DView ? palette.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '3D Isometric',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
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
          Center(
            child: SizedBox(
              height: 220,
              width: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
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
                  Positioned(
                    left: 2,
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
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
                  Padding(
                    padding: const EdgeInsets.only(left: 36, top: 22, right: 12, bottom: 8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      transform: _is3DView
                          ? (Matrix4.identity()
                              ..setEntry(3, 2, 0.0015)
                              ..rotateX(0.24)
                              ..rotateY(-0.24)
                              ..rotateZ(0.04))
                          : Matrix4.identity(),
                      transformAlignment: Alignment.center,
                      child: Container(
                        height: 155,
                        width: 250,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C2420),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: palette.primary, width: 1.6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.18),
                              blurRadius: 18,
                              offset: const Offset(8, 12),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.asset(
                                'assets/images/grande_ledge_ta02.png',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Color(0xFF382E2B), Color(0xFF221C1A)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                ),
                              ),
                              Column(
                                children: List.generate(rows, (r) {
                                  return Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Colors.black.withValues(alpha: 0.55),
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
                                                    color: Colors.black.withValues(alpha: 0.55),
                                                    width: 1.0,
                                                  ),
                                                ),
                                              ),
                                              child: Center(
                                                child: Container(
                                                  width: 3.5,
                                                  height: 3.5,
                                                  decoration: BoxDecoration(
                                                    color: palette.primary.withValues(alpha: 0.45),
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
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: palette.surfaceDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Slab Grid: $cols cols × $rows rows',
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

  Widget _buildArBanner(LuxuryPalette palette, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
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
            child: Icon(Icons.view_in_ar_outlined, color: palette.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live AR Camera Measurement',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Aim camera at room to scan bounds automatically.',
                  style: GoogleFonts.inter(fontSize: 11, color: palette.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ApplePressable(
            onTap: () => context.push('/live-ai'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: palette.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Open AR',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


