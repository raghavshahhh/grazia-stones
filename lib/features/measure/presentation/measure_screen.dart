import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/core/providers/stone_providers.dart';
import 'package:grazia_stones/core/widgets/animated_widgets.dart';
import 'package:grazia_stones/core/widgets/error_handler_widget.dart';
import 'package:grazia_stones/features/cart/presentation/cart_screen.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/shared/widgets/luxury_toast.dart';
import 'package:grazia_stones/shared/widgets/smart_stone_image.dart';

class MeasureScreen extends ConsumerStatefulWidget {
  const MeasureScreen({super.key});

  @override
  ConsumerState<MeasureScreen> createState() => _MeasureScreenState();
}

class _MeasureScreenState extends ConsumerState<MeasureScreen> with TickerProviderStateMixin {
  final _lengthController = TextEditingController(text: '12');
  final _widthController = TextEditingController(text: '10');
  final _heightController = TextEditingController(text: '4');
  final _wastageController = TextEditingController(text: '10');
  final _customRateController = TextEditingController(text: '450');

  String _unit = 'feet'; // 'feet', 'meters', 'inches'
  String _shape = 'Rectangle'; // 'Rectangle', 'L-Shape', 'Circle'
  String _selectedTileSize = '24" × 48"'; // '24" × 48"', '12" × 24"', '48" × 96"'
  
  Stone? _selectedStone;
  bool _useCustomRate = false;
  bool _is3DView = true;
  double _wallRotationAngle = -0.20; // radians for interactive 3D rotation

  // Calculated Metrics
  double _netAreaSqFt = 120.0;
  double _grossAreaSqFt = 132.0;
  double _wastageAreaSqFt = 12.0;
  int _boxCount = 13;
  double _estimatedCost = 59400.0;
  int _tileCount = 17;
  int _adhesiveBags = 4;
  int _groutKg = 6;
  int _cols = 6;
  int _rows = 5;

  late AnimationController _pulseController;

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
    {'pct': 5, 'label': '5%', 'desc': 'Straight Lay'},
    {'pct': 10, 'label': '10%', 'desc': 'Standard'},
    {'pct': 15, 'label': '15%', 'desc': 'Herringbone'},
    {'pct': 20, 'label': '20%', 'desc': 'Diagonal / Curved'},
  ];

  final List<Map<String, dynamic>> _quickPresets = [
    {'title': "10' × 10'", 'l': '10', 'w': '10', 'desc': 'Powder Wall'},
    {'title': "12' × 15'", 'l': '12', 'w': '15', 'desc': 'Living Feature'},
    {'title': "16' × 20'", 'l': '16', 'w': '20', 'desc': 'Master Suite'},
    {'title': "20' × 24'", 'l': '20', 'w': '24', 'desc': 'Grand Façade'},
  ];

  final List<String> _tileSizes = [
    '12" × 24"',
    '24" × 48"',
    '48" × 96"',
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _calculate(silent: true);
  }

  @override
  void dispose() {
    _lengthController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _wastageController.dispose();
    _customRateController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _calculate({bool silent = false}) {
    final l = double.tryParse(_lengthController.text.trim()) ?? 0.0;
    final w = double.tryParse(_widthController.text.trim()) ?? 0.0;
    final wastagePct = double.tryParse(_wastageController.text.trim()) ?? 10.0;
    final customRate = double.tryParse(_customRateController.text.trim()) ?? 450.0;

    if (l <= 0 || w <= 0) {
      if (!silent) {
        showErrorSnackbar(context, null, customMessage: 'Please enter positive dimensions');
      }
      return;
    }

    // Calculate raw surface area in selected unit
    double rawArea = 0.0;
    if (_shape == 'Rectangle') {
      rawArea = l * w;
    } else if (_shape == 'Circle') {
      // w is radius
      rawArea = math.pi * w * w;
    } else if (_shape == 'L-Shape') {
      final cutout = double.tryParse(_heightController.text.trim()) ?? (l * 0.35);
      final mainArea = l * w;
      final cutoutArea = cutout * (w * 0.40);
      rawArea = math.max(1.0, mainArea - cutoutArea);
    }

    // Convert rawArea into Sq. Ft.
    double sqft = rawArea;
    if (_unit == 'meters') {
      sqft = rawArea * 10.76391;
    } else if (_unit == 'inches') {
      sqft = rawArea / 144.0;
    }

    final bufferArea = sqft * (wastagePct / 100.0);
    final grossArea = sqft + bufferArea;

    // Rate & Packaging Box
    final rate = _useCustomRate || _selectedStone == null
        ? customRate
        : _selectedStone!.pricePerSqFt;

    final sqftPerBox = (_selectedStone != null && _selectedStone!.sqftPerBox > 0)
        ? _selectedStone!.sqftPerBox
        : 10.5;

    final boxes = (grossArea / sqftPerBox).ceil();
    final cost = grossArea * rate;

    // Adhesive (1 bag per 40 sq ft) & Grout (1 kg per 25 sq ft)
    final adhesive = (grossArea / 40.0).ceil();
    final grout = (grossArea / 25.0).ceil();

    // Tile count calculation based on selected slab size
    double tileSqft = 8.0; // 24" x 48" = 8 sqft
    if (_selectedTileSize == '12" × 24"') {
      tileSqft = 2.0;
    } else if (_selectedTileSize == '48" × 96"') {
      tileSqft = 32.0;
    }
    final tilePcs = (grossArea / tileSqft).ceil();

    // Calculate grid dimensions for visualization
    final lengthInFeet = _unit == 'meters'
        ? l * 3.28084
        : _unit == 'inches'
            ? l / 12.0
            : l;
    final widthInFeet = _unit == 'meters'
        ? w * 3.28084
        : _unit == 'inches'
            ? w / 12.0
            : w;

    final cols = (lengthInFeet / (tileSqft == 2.0 ? 1.0 : tileSqft == 8.0 ? 2.0 : 4.0)).clamp(2, 10).round();
    final rows = (widthInFeet / (tileSqft == 2.0 ? 2.0 : tileSqft == 8.0 ? 4.0 : 8.0)).clamp(2, 8).round();

    setState(() {
      _netAreaSqFt = sqft;
      _grossAreaSqFt = grossArea;
      _wastageAreaSqFt = bufferArea;
      _boxCount = math.max(1, boxes);
      _estimatedCost = cost;
      _tileCount = math.max(1, tilePcs);
      _adhesiveBags = math.max(1, adhesive);
      _groutKg = math.max(1, grout);
      _cols = cols;
      _rows = rows;
    });

    if (!silent) {
      HapticFeedback.selectionClick();
    }
  }

  void _stepLength(double delta) {
    HapticFeedback.lightImpact();
    final current = double.tryParse(_lengthController.text.trim()) ?? 10.0;
    final newVal = (current + delta).clamp(1.0, 500.0);
    _lengthController.text = newVal == newVal.roundToDouble()
        ? newVal.toInt().toString()
        : newVal.toStringAsFixed(1);
    _calculate(silent: true);
  }

  void _stepWidth(double delta) {
    HapticFeedback.lightImpact();
    final current = double.tryParse(_widthController.text.trim()) ?? 10.0;
    final newVal = (current + delta).clamp(1.0, 500.0);
    _widthController.text = newVal == newVal.roundToDouble()
        ? newVal.toInt().toString()
        : newVal.toStringAsFixed(1);
    _calculate(silent: true);
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
    HapticFeedback.mediumImpact();
    setState(() {
      _lengthController.text = '12';
      _widthController.text = '10';
      _heightController.text = '4';
      _wastageController.text = '10';
      _unit = 'feet';
      _shape = 'Rectangle';
      _selectedTileSize = '24" × 48"';
      _wallRotationAngle = -0.20;
    });
    _calculate(silent: true);
    LuxuryToast.show(context, message: 'Dimensions reset to standard 12′ × 10′');
  }

  void _onAddToCart() {
    HapticFeedback.mediumImpact();
    if (_selectedStone != null) {
      // Cart quantity is sq ft (priced as pricePerSqFt × qty), same as the tile visualiser
      ref.read(cartProvider.notifier).addItem(_selectedStone!, quantity: _grossAreaSqFt.ceil());
      LuxuryToast.show(
        context,
        message: '$_boxCount boxes of ${_selectedStone!.name} added to Project Cart!',
      );
    } else {
      LuxuryToast.show(
        context,
        message: '$_boxCount boxes (approx. ${_grossAreaSqFt.toStringAsFixed(1)} sq ft) added to Project Schedule!',
      );
    }
    context.push('/cart');
  }

  void _onRequestQuote() {
    HapticFeedback.lightImpact();
    final stoneIdParam = _selectedStone != null ? '?stoneId=${_selectedStone!.id}' : '';
    context.push('/quotes/new$stoneIdParam');
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stonesAsync = ref.watch(allStonesProvider);

    // Default to first stone once loaded if not already selected
    stonesAsync.whenData((stones) {
      if (_selectedStone == null && stones.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selectedStone == null) {
            setState(() {
              _selectedStone = stones.first;
            });
            _calculate(silent: true);
          }
        });
      }
    });

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
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
        actions: [
          IconButton(
            tooltip: 'Reset',
            onPressed: _reset,
            icon: Icon(Icons.refresh_rounded, color: palette.textSecondary, size: 20),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ApplePressable(
              onTap: () {
                final id = _selectedStone?.id;
                context.push('/measure/tile-visualizer${id != null ? '?stoneId=$id' : ''}');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      palette.primary.withValues(alpha: 0.18),
                      palette.primary.withValues(alpha: 0.06),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: palette.primary.withValues(alpha: 0.45)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.view_in_ar_rounded, size: 14, color: palette.primary),
                    const SizedBox(width: 5),
                    Text(
                      '3D Studio',
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 130),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Live Instant Calculation Hero Banner
                _buildLiveResultHero(palette, isDark),
                const SizedBox(height: 18),

                // 2. Interactive 3D / 2D Wall Perspective Visualizer with Touch Drag
                _buildInteractive3DWall(palette, isDark),
                const SizedBox(height: 22),

                // 3. Real Stone Material Selection Strip
                _buildStoneMaterialSelector(palette, stonesAsync),
                const SizedBox(height: 22),

                // 4. Quick Architectural Presets
                _buildSectionHeader('QUICK ARCHITECTURAL PRESETS', palette),
                const SizedBox(height: 10),
                _buildQuickPresetsRow(palette),
                const SizedBox(height: 22),

                // 5. Measurement Unit Selector
                _buildSectionHeader('MEASUREMENT UNIT', palette),
                const SizedBox(height: 10),
                _buildUnitSelector(palette),
                const SizedBox(height: 22),

                // 6. Room Geometry Selector
                _buildSectionHeader('ROOM GEOMETRY', palette),
                const SizedBox(height: 10),
                _buildGeometrySelector(palette),
                const SizedBox(height: 22),

                // 7. Room Dimensions with Tactile Steppers
                _buildSectionHeader('ROOM DIMENSIONS', palette),
                const SizedBox(height: 10),
                _buildDimensionInputsWithSteppers(palette),
                const SizedBox(height: 22),

                // 8. Recommended Cut Wastage
                _buildSectionHeader('RECOMMENDED CUT WASTAGE', palette),
                const SizedBox(height: 10),
                _buildWastageSelector(palette),
                const SizedBox(height: 24),

                // 9. Detailed Engineering & Site Readiness Breakdown
                _buildComprehensiveBreakdown(palette, isDark),
                const SizedBox(height: 24),

                // 10. Action Buttons Hub
                _buildActionButtons(palette),
                const SizedBox(height: 20),

                // 11. AR Live Camera Measurement Card
                _buildArBanner(palette, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // 1. LIVE RESULT HERO CARD
  // ─────────────────────────────────────────────────────────
  Widget _buildLiveResultHero(LuxuryPalette palette, bool isDark) {
    final currencyFormat = _estimatedCost.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );

    final stoneName = _selectedStone?.name ?? 'Custom Specification';
    final stoneRate = _useCustomRate || _selectedStone == null
        ? '₹${_customRateController.text}/sqft'
        : '₹${_selectedStone!.pricePerSqFt.toInt()}/sqft';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.primary.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: palette.primary.withValues(alpha: 0.08),
            blurRadius: 18,
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
                  FadeTransition(
                    opacity: _pulseController,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.shade700,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.greenAccent.withValues(alpha: 0.6),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'LIVE ARCHITECTURAL ESTIMATE',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: palette.primary,
                      letterSpacing: 1.2,
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
                  stoneRate,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: palette.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // High Impact Metric Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ESTIMATED INVESTMENT',
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: palette.textTertiary,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹$currencyFormat',
                      style: GoogleFonts.inter(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: palette.primary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'for ${_grossAreaSqFt.toStringAsFixed(1)} sq ft gross',
                      style: GoogleFonts.inter(fontSize: 11, color: palette.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: palette.surfaceDark,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: palette.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$_boxCount BOXES',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '~${_selectedStone?.sqftPerBox ?? 10.5} sqft/box',
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        color: palette.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Secondary mini specs
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniSpec('NET SURFACE', '${_netAreaSqFt.toStringAsFixed(1)} sq ft', palette),
              _buildMiniSpec('CUT BUFFER', '+${_wastageAreaSqFt.toStringAsFixed(1)} sq ft (${_wastageController.text}%)', palette),
              _buildMiniSpec('SLAB TILES', '~$_tileCount pcs ($_selectedTileSize)', palette),
            ],
          ),
          const SizedBox(height: 8),

          // Selected Stone Tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: palette.surfaceDark,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.layers_outlined, size: 13, color: palette.primary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Selected Stone: $stoneName',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: palette.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniSpec(String title, String val, LuxuryPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(fontSize: 8.5, fontWeight: FontWeight.w700, color: palette.textTertiary, letterSpacing: 0.5),
        ),
        const SizedBox(height: 2),
        Text(
          val,
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: palette.textPrimary),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  // 2. INTERACTIVE 3D/2D WALL VISUALIZER WITH GESTURE ROTATION
  // ─────────────────────────────────────────────────────────
  Widget _buildInteractive3DWall(LuxuryPalette palette, bool isDark) {
    final l = double.tryParse(_lengthController.text.trim()) ?? 12.0;
    final w = double.tryParse(_widthController.text.trim()) ?? 10.0;
    final unitLabel = _unit == 'feet' ? 'ft' : _unit == 'meters' ? 'm' : 'in';

    final stoneImage = _selectedStone?.arTexture ?? _selectedStone?.mainImageUrl;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.view_in_ar_rounded, color: palette.primary, size: 18),
                    const SizedBox(width: 7),
                    Text(
                      '3D Wall Layout',
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
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
                          '2D Flat',
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
          const SizedBox(height: 6),
          Text(
            _is3DView
                ? '👆 Drag left / right on wall to rotate perspective'
                : 'Orthographic architectural elevation view',
            style: GoogleFonts.inter(fontSize: 10.5, color: palette.textTertiary),
          ),
          const SizedBox(height: 16),

          // Interactive Gestured 3D Wall Canvas
          Center(
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                if (_is3DView) {
                  setState(() {
                    _wallRotationAngle += details.primaryDelta! * 0.005;
                    _wallRotationAngle = _wallRotationAngle.clamp(-0.55, 0.55);
                  });
                }
              },
              child: SizedBox(
                height: 215,
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Dimension tags
                    Positioned(
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: palette.surfaceDark,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: palette.border),
                        ),
                        child: Text(
                          'Width: ${l.toStringAsFixed(1)} $unitLabel',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: palette.primary,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 2,
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: palette.surfaceDark,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: palette.border),
                          ),
                          child: Text(
                            'Height: ${w.toStringAsFixed(1)} $unitLabel',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: palette.primary,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Wall Block
                    Padding(
                      padding: const EdgeInsets.only(left: 36, top: 24, right: 12, bottom: 8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeOut,
                        transform: _is3DView
                            ? (Matrix4.identity()
                              ..setEntry(3, 2, 0.0015)
                              ..rotateX(0.22)
                              ..rotateY(_wallRotationAngle)
                              ..rotateZ(0.02))
                            : Matrix4.identity(),
                        transformAlignment: Alignment.center,
                        child: Container(
                          height: 155,
                          width: 260,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2C2420),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: palette.primary, width: 1.8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.20),
                                blurRadius: 20,
                                offset: const Offset(8, 14),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // Texture
                                if (stoneImage != null && stoneImage.isNotEmpty)
                                  SmartStoneImage(
                                    imageUrl: stoneImage,
                                    fit: BoxFit.cover,
                                    palette: palette,
                                  )
                                else
                                  Image.asset(
                                    'assets/images/grande_ledge_ta02.png',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [Color(0xFF382E2B), Color(0xFF1E1715)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                    ),
                                  ),

                                // Slabs Joint Overlay
                                Column(
                                  children: List.generate(_rows, (r) {
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
                                          children: List.generate(_cols, (c) {
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
          ),

          const SizedBox(height: 12),

          // Slab Size & Grid Spec Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: palette.surfaceDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Slab: ',
                          style: GoogleFonts.inter(fontSize: 11, color: palette.textTertiary),
                        ),
                        ..._tileSizes.map((size) {
                          final isSel = _selectedTileSize == size;
                          return Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedTileSize = size);
                                _calculate(silent: true);
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: isSel ? palette.primary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  size,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isSel ? Colors.white : palette.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$_cols×$_rows (~$_tileCount pcs)',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: palette.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // 3. REAL STONE MATERIAL SELECTOR STRIP
  // ─────────────────────────────────────────────────────────
  Widget _buildStoneMaterialSelector(LuxuryPalette palette, AsyncValue<List<Stone>> stonesAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('SELECT REAL STONE MATERIAL', palette),
        const SizedBox(height: 4),
        Text(
          'Choose a stone from Grazia catalogue to apply real texture, box sizes & pricing.',
          style: GoogleFonts.inter(fontSize: 11.5, color: palette.textSecondary),
        ),
        const SizedBox(height: 10),
        stonesAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (_, __) => _buildCustomRateFallback(palette),
          data: (stones) {
            if (stones.isEmpty) {
              return _buildCustomRateFallback(palette);
            }
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  ...stones.take(10).map((stone) {
                    final isSelected = !_useCustomRate && _selectedStone?.id == stone.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ApplePressable(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedStone = stone;
                            _useCustomRate = false;
                          });
                          _calculate(silent: true);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 140,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? palette.primary.withValues(alpha: 0.12)
                                : palette.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? palette.primary : palette.border,
                              width: isSelected ? 1.8 : 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  height: 72,
                                  width: double.infinity,
                                  child: SmartStoneImage(
                                    imageUrl: stone.mainImageUrl ?? stone.arTexture,
                                    fit: BoxFit.cover,
                                    palette: palette,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                stone.name,
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? palette.primary : palette.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '₹${stone.pricePerSqFt.toInt()}/sqft',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: palette.primary,
                                    ),
                                  ),
                                  Text(
                                    '${stone.sqftPerBox} sf/b',
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      color: palette.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                  // Custom Rate Option Card
                  ApplePressable(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _useCustomRate = true);
                      _calculate(silent: true);
                    },
                    child: Container(
                      width: 140,
                      height: 122,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _useCustomRate
                            ? palette.primary.withValues(alpha: 0.12)
                            : palette.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _useCustomRate ? palette.primary : palette.border,
                          width: _useCustomRate ? 1.8 : 1.0,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.edit_note_rounded, color: palette.primary, size: 24),
                          const SizedBox(height: 4),
                          Text(
                            'Custom Rate',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _useCustomRate ? palette.primary : palette.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '₹${_customRateController.text}/sqft',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: palette.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        if (_useCustomRate) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customRateController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: palette.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Enter Custom Rate per Sq Ft (₹)',
                    labelStyle: GoogleFonts.inter(fontSize: 11, color: palette.textSecondary),
                    prefixIcon: Icon(Icons.currency_rupee_rounded, size: 16, color: palette.primary),
                    filled: true,
                    fillColor: palette.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (_) => _calculate(silent: true),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildCustomRateFallback(LuxuryPalette palette) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        'Using Standard Architectural Rate: ₹450 / sq ft',
        style: GoogleFonts.inter(fontSize: 12, color: palette.textPrimary),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // 4. QUICK ARCHITECTURAL PRESETS
  // ─────────────────────────────────────────────────────────
  Widget _buildQuickPresetsRow(LuxuryPalette palette) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _quickPresets.map((preset) {
          final isCurrent = _lengthController.text == preset['l'] &&
              _widthController.text == preset['w'] &&
              _unit == 'feet';
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
                    width: isCurrent ? 1.6 : 1.0,
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

  // ─────────────────────────────────────────────────────────
  // 5. MEASUREMENT UNIT SELECTOR
  // ─────────────────────────────────────────────────────────
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

  // ─────────────────────────────────────────────────────────
  // 6. ROOM GEOMETRY SELECTOR
  // ─────────────────────────────────────────────────────────
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
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
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

  // ─────────────────────────────────────────────────────────
  // 7. ROOM DIMENSIONS WITH TACTILE STEPPERS
  // ─────────────────────────────────────────────────────────
  Widget _buildDimensionInputsWithSteppers(LuxuryPalette palette) {
    final sym = _unit == 'feet' ? 'ft' : _unit == 'meters' ? 'm' : 'in';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildDimInputFieldWithStepper(
                controller: _lengthController,
                label: 'Length / Width',
                icon: Icons.straighten_rounded,
                suffix: sym,
                palette: palette,
                onMinus: () => _stepLength(-1),
                onPlus: () => _stepLength(1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildDimInputFieldWithStepper(
                controller: _widthController,
                label: _shape == 'Circle' ? 'Radius' : 'Height / Depth',
                icon: Icons.height_rounded,
                suffix: sym,
                palette: palette,
                onMinus: () => _stepWidth(-1),
                onPlus: () => _stepWidth(1),
              ),
            ),
          ],
        ),
        if (_shape == 'L-Shape') ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.surfaceDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.turn_right_rounded, size: 16, color: palette.primary),
                    const SizedBox(width: 6),
                    Text(
                      'L-Shape Return Corner Cutout Offset',
                      style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: palette.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildDimInputFieldWithStepper(
                  controller: _heightController,
                  label: 'Return Wall Offset Length',
                  icon: Icons.crop_free_rounded,
                  suffix: sym,
                  palette: palette,
                  onMinus: () {
                    final cur = double.tryParse(_heightController.text) ?? 4.0;
                    _heightController.text = (cur - 1).clamp(0.5, 100.0).toStringAsFixed(1);
                    _calculate(silent: true);
                  },
                  onPlus: () {
                    final cur = double.tryParse(_heightController.text) ?? 4.0;
                    _heightController.text = (cur + 1).clamp(0.5, 100.0).toStringAsFixed(1);
                    _calculate(silent: true);
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDimInputFieldWithStepper({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String suffix,
    required LuxuryPalette palette,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: palette.textSecondary),
            ),
          ),
          Row(
            children: [
              // Minus stepper button
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onMinus,
                icon: Icon(Icons.remove_circle_outline_rounded, color: palette.textSecondary, size: 20),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: palette.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (_) => _calculate(silent: true),
                ),
              ),
              // Suffix symbol
              Text(
                suffix,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: palette.primary,
                ),
              ),
              // Plus stepper button
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onPlus,
                icon: Icon(Icons.add_circle_outline_rounded, color: palette.primary, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // 8. RECOMMENDED CUT WASTAGE SELECTOR
  // ─────────────────────────────────────────────────────────
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
                    width: isSelected ? 1.6 : 1.0,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '$pct%',
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
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

  // ─────────────────────────────────────────────────────────
  // 9. COMPREHENSIVE ARCHITECTURAL BREAKDOWN
  // ─────────────────────────────────────────────────────────
  Widget _buildComprehensiveBreakdown(LuxuryPalette palette, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2_outlined, color: palette.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'Architectural Bill of Quantities (BOQ)',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _buildBreakdownRow('Net Surface Area', '${_netAreaSqFt.toStringAsFixed(1)} sq ft', palette),
          _buildBreakdownRow('Cut & Edge Wastage (${_wastageController.text}%)', '+${_wastageAreaSqFt.toStringAsFixed(1)} sq ft', palette),
          _buildBreakdownRow('Total Gross Coverage Needed', '${_grossAreaSqFt.toStringAsFixed(1)} sq ft', palette, isBold: true),
          const Divider(height: 20),
          _buildBreakdownRow('Packaging Boxes Required', '$_boxCount Boxes (~${_selectedStone?.sqftPerBox ?? 10.5} sqft/box)', palette),
          _buildBreakdownRow('Estimated Slab Tiles ($_selectedTileSize)', '$_tileCount Units', palette),
          _buildBreakdownRow('Adhesive (20kg polymer bag)', '$_adhesiveBags Bags (~40 sqft/bag)', palette),
          _buildBreakdownRow('Epoxy / Cement Grout', '$_groutKg kg (~25 sqft/kg)', palette),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(String label, String val, LuxuryPalette palette, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
              color: isBold ? palette.textPrimary : palette.textSecondary,
            ),
          ),
          Text(
            val,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: isBold ? palette.primary : palette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // 10. ACTION BUTTONS HUB
  // ─────────────────────────────────────────────────────────
  Widget _buildActionButtons(LuxuryPalette palette) {
    return Column(
      children: [
        // Primary: Request Official Quotation with these specs
        ApplePressable(
          onTap: _onRequestQuote,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  palette.primary,
                  palette.primary.withValues(alpha: 0.88),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: palette.primary.withValues(alpha: 0.32),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.request_quote_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Request Official Quote for this Area',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Secondary Row: Add to Project Cart + Open 3D Visualizer
        Row(
          children: [
            Expanded(
              child: ApplePressable(
                onTap: _onAddToCart,
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: palette.primary.withValues(alpha: 0.45)),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_bag_outlined, color: palette.primary, size: 17),
                      const SizedBox(width: 6),
                      Text(
                        'Add to Project Cart',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: palette.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ApplePressable(
                onTap: () {
                  final id = _selectedStone?.id;
                  context.push('/measure/tile-visualizer${id != null ? '?stoneId=$id' : ''}');
                },
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: palette.surfaceDark,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: palette.border),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.view_in_ar_rounded, color: palette.textPrimary, size: 17),
                      const SizedBox(width: 6),
                      Text(
                        'Open 3D Visualizer',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
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

  // ─────────────────────────────────────────────────────────
  // 11. AR LIVE CAMERA BANNER
  // ─────────────────────────────────────────────────────────
  Widget _buildArBanner(LuxuryPalette palette, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surfaceDark,
        borderRadius: BorderRadius.circular(18),
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
            child: Icon(Icons.camera_alt_outlined, color: palette.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live LiDAR / AR Camera Scan',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Scan room perimeter with device camera automatically.',
                  style: GoogleFonts.inter(fontSize: 11, color: palette.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ApplePressable(
            onTap: () => context.push('/ar-view'),
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
}
