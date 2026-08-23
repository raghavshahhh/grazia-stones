import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/constants/app_colors.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/core/providers/stone_providers.dart';
import 'widgets/ar_camera_view.dart';
import 'widgets/corner_adjust_overlay.dart';
import 'widgets/measure_overlay.dart';

/// Live AI Visualizer — real camera + wall texture visualization
class LiveAIScreen extends ConsumerStatefulWidget {
  const LiveAIScreen({super.key});

  @override
  ConsumerState<LiveAIScreen> createState() => _LiveAIScreenState();
}

class _LiveAIScreenState extends ConsumerState<LiveAIScreen> {
  // Stone selection
  int _selectedStoneIndex = 0;
  List<Stone> _filteredStones = [];

  // Category filter (kept internally as "All"; UI chips removed per request)
  final String _selectedCategory = 'All';

  // Camera state
  bool _cameraReady = false;

  // Info card toggle (shown via the "i" button)
  bool _showInfoCard = false;

  // Measure mode toggle (shown via the ruler button)
  bool _measureMode = false;

  // Recording state — same button as measure: tap = measure, hold = record
  bool _isRecording = false;

  // Manual wall-corner adjustment (fixes texture not matching wall angle)
  bool _adjustingCorners = false;

  // Wall selection mode (when multiple walls detected)
  bool _selectingWall = false;
  List<Map<String, dynamic>> _detectedWalls = [];

  // Wall tracking state (from AR engine)
  String _wallState = 'SEARCHING';
  Timer? _wallStateTimer;

  // Calibration
  bool _calibrationMode = false;
  String _calibrationUnit = 'ft';

  // Texture controls
  double _textureOpacity = 0.96;
  double _textureScale = 1.0;

  // Quantity calculation result
  Map<String, dynamic>? _quantityResult;

  // Controllers
  late PageController _stonePageController;
  final _calibrationLengthController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _stonePageController = PageController(
      viewportFraction: 0.32,
      initialPage: 0,
    );
    _updateFilteredStones();
    
    // Start polling wall state from AR engine
    _wallStateTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      final state = ARCameraView.getWallState();
      if (state != null && state != _wallState) {
        setState(() => _wallState = state);
      }
    });
  }

  @override
  void dispose() {
    _stonePageController.dispose();
    _calibrationLengthController.dispose();
    _wallStateTimer?.cancel();
    super.dispose();
  }

  void _updateFilteredStones() {
    final allStones = ref.read(allStonesProvider).valueOrNull ?? [];
    setState(() {
      if (_selectedCategory == 'All') {
        _filteredStones = List<Stone>.from(allStones);
      } else {
        _filteredStones = allStones
            .where((s) =>
                s.category.toLowerCase().contains(_selectedCategory.toLowerCase()) ||
                s.collection.toLowerCase().contains(_selectedCategory.toLowerCase()))
            .toList();
        if (_filteredStones.isEmpty) {
          _filteredStones = List<Stone>.from(allStones);
        }
      }
      _selectedStoneIndex = 0;
    });
  }

  Stone? get _selectedStone => _filteredStones.isEmpty
      ? null
      : _filteredStones[_selectedStoneIndex % _filteredStones.length];

  void _selectStone(int index) {
    HapticFeedback.selectionClick();
    setState(() => _selectedStoneIndex = index);
    final stone = _selectedStone;
    if (stone == null) return;
    final path = stone.arTextureUrl;
    if (path != null && _cameraReady) {
      ARCameraView.updateStone(path, _textureOpacity);
      
      // Preload adjacent carousel textures for instant switching
      final int currentIndex = _selectedStoneIndex;
      final int prevIndex = (currentIndex - 1 + _filteredStones.length) % _filteredStones.length;
      final int nextIndex = (currentIndex + 1) % _filteredStones.length;
      final List<String> preloadUrls = [];
      if (_filteredStones[prevIndex].arTextureUrl != null) preloadUrls.add(_filteredStones[prevIndex].arTextureUrl!);
      if (_filteredStones[nextIndex].arTextureUrl != null) preloadUrls.add(_filteredStones[nextIndex].arTextureUrl!);
      if (preloadUrls.isNotEmpty) {
        ARCameraView.preloadTextures(preloadUrls);
      }
      
      // Parse tile dimensions from stone size (e.g., "600×150×18-20mm")
      final sizeParts = stone.size.split('×');
      if (sizeParts.length >= 2) {
        final width = double.tryParse(sizeParts[0].replaceAll('mm', '').trim()) ?? 600;
        final height = double.tryParse(sizeParts[1].replaceAll('mm', '').trim()) ?? 600;
        ARCameraView.setTileDimensions(width, height, 'mm');
      }
    }
  }

  void _onOpacityChanged(double value) {
    setState(() => _textureOpacity = value);
    ARCameraView.updateOpacity(value);
  }

  void _onScaleChanged(double value) {
    setState(() => _textureScale = value);
    ARCameraView.updateScale(value);
  }

  void _startRecording() {
    if (!_cameraReady || _isRecording) return;
    HapticFeedback.mediumImpact();
    ARCameraView.startRecording();
    setState(() => _isRecording = true);
  }

  void _stopRecording() {
    if (!_isRecording) return;
    HapticFeedback.selectionClick();
    ARCameraView.stopRecording();
    setState(() => _isRecording = false);
  }

  void _navigateToProduct() {
    HapticFeedback.mediumImpact();
    final stone = _selectedStone;
    if (stone != null) context.push('/stones/${stone.id}');
  }

  // ── Wall Selection ────────────────────────────────────────────────────────

  void _refreshWalls() async {
    final walls = ARCameraView.getWalls();
    if (walls != null && mounted) {
      setState(() => _detectedWalls = walls);
    }
  }

  void _enterWallSelection() {
    _refreshWalls();
    if (_detectedWalls.length > 1) {
      setState(() => _selectingWall = true);
    } else if (_detectedWalls.length == 1) {
      ARCameraView.selectWall(_detectedWalls[0]['id'] as String);
    }
  }

  void _selectWall(String wallId) {
    ARCameraView.selectWall(wallId);
    setState(() => _selectingWall = false);
    _refreshWalls();
  }

  // ── Calibration ──────────────────────────────────────────────────────────

  void _startCalibration() {
    ARCameraView.startCalibration(unit: _calibrationUnit);
    setState(() {
      _calibrationMode = true;
      _calibrationLengthController.clear();
    });
  }

  void _finishCalibration() {
    final length = double.tryParse(_calibrationLengthController.text);
    if (length == null || length <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid length')),
      );
      return;
    }
    final success = ARCameraView.finishCalibration(length);
    if (success) {
      setState(() => _calibrationMode = false);
      _calculateQuantity();
    }
  }

  // ── Quantity Calculation ─────────────────────────────────────────────────

  void _calculateQuantity() async {
    final stone = _selectedStone;
    if (stone == null) return;

    // Parse tile dimensions from stone
    double tileWidth = 0, tileHeight = 0;
    final sizeParts = stone.size.split('×');
    if (sizeParts.length >= 2) {
      tileWidth = double.tryParse(sizeParts[0].replaceAll('mm', '').trim()) ?? 0;
      tileHeight = double.tryParse(sizeParts[1].replaceAll('mm', '').trim()) ?? 0;
    }

    if (tileWidth <= 0 || tileHeight <= 0) return;

    // Use calibration-aware calculation
    final calibration = ARCameraView.getCalibration();
    final isCalibrated = calibration != null && calibration['pixelsPerUnit'] != null;
    
    final result = ARCameraView.calculateTileQuantity(
      tileWidth: tileWidth,
      tileHeight: tileHeight,
      tileUnit: 'mm',
      wastagePercent: 10.0,
    );

    if (result != null && mounted) {
      // Add calibration status to result
      result['isCalibrated'] = isCalibrated;
      result['calibrationUnit'] = isCalibrated ? calibration['unit'] : 'mm';
      setState(() => _quantityResult = result);
    }
  }

  // ── Save Design ─────────────────────────────────────────────────────────────
  void _saveDesign() {
    HapticFeedback.mediumImpact();
    final stone = _selectedStone;
    if (stone == null) return;
    
    // TODO: Save to Supabase - design with stone, wall selection, texture settings
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Design saved: ${stone.name}'),
        backgroundColor: AppColors.goldWarm,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Request Quote ───────────────────────────────────────────────────────────
  void _requestQuote() {
    HapticFeedback.mediumImpact();
    final stone = _selectedStone;
    if (stone == null) return;
    
    // Navigate to quote request screen with pre-filled stone info
    context.push('/quotes', extra: {
      'stoneId': stone.id,
      'stoneName': stone.name,
      'pricePerSqFt': stone.pricePerSqFt,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Full-screen camera feed
          _buildCamera(),

          // 2. Top bar
          _buildTopBar(),

          // 3. Bottom horizontal product carousel with CTAs
          _buildBottomProductCarousel(),

          // 4. Info button — product name/price + link to product page
          _buildInfoButton(),

          // 5. Tap-to-measure overlay
          if (_measureMode)
            MeasureOverlay(onClose: () => setState(() => _measureMode = false)),

          // 6. Manual wall-corner adjustment overlay
          if (_adjustingCorners)
            CornerAdjustOverlay(
                onClose: () => setState(() => _adjustingCorners = false)),

          // 7. Wall selection overlay (when multiple walls detected)
          if (_selectingWall) _buildWallSelectionOverlay(),

          // 8. Calibration overlay
          if (_calibrationMode) _buildCalibrationOverlay(),

          // 9. Quantity result display
          if (_quantityResult != null) _buildQuantityDisplay(),

          // 10. Wall state overlay
          _buildWallStateOverlay(),
        ],
      ),
    );
  }

  // ── Wall State Overlay ───────────────────────────────────────────────

  Widget _buildWallStateOverlay() {
    String label;
    IconData icon;
    Color stateColor;

    switch (_wallState) {
      case 'SEARCHING':
        label = 'Point your camera at a wall';
        icon = Icons.crop_free_rounded;
        stateColor = const Color(0xFFD4AF37);
        break;
      case 'DETECTING':
        label = 'Detecting wall...';
        icon = Icons.auto_awesome_rounded;
        stateColor = const Color(0xFFD4AF37);
        break;
      case 'LOCKED':
      case 'TRACKING':
        label = 'Wall detected';
        icon = Icons.check_circle_rounded;
        stateColor = const Color(0xFF4CAF50);
        break;
      case 'LOST':
        label = 'Wall lost — point back at the wall';
        icon = Icons.error_outline_rounded;
        stateColor = const Color(0xFFE57373);
        break;
      case 'INVALID':
        label = 'Move closer to a clear wall';
        icon = Icons.zoom_in_rounded;
        stateColor = const Color(0xFFFFB74D);
        break;
      default:
        label = 'Point your camera at a wall';
        icon = Icons.crop_free_rounded;
        stateColor = const Color(0xFFD4AF37);
    }

    return Positioned(
      top: MediaQuery.of(context).padding.top + 72,
      left: 0,
      right: 0,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: stateColor.withValues(alpha: 0.6), width: 1.0),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: stateColor, size: 15),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: stateColor == const Color(0xFF4CAF50) ? Colors.white : stateColor,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Wall Selection Overlay ───────────────────────────────────────────────

  Widget _buildWallSelectionOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.7),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.goldWarm.withValues(alpha: 0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Multiple Walls Detected',
                  style: TextStyle(
                    color: AppColors.goldWarm,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap a wall to select it for visualization',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    itemCount: _detectedWalls.length,
                    itemBuilder: (context, index) {
                      final wall = _detectedWalls[index];
                      final area = (wall['area'] as num?)?.toDouble() ?? 0;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.goldWarm.withValues(alpha: 0.2),
                          child: Text('${index + 1}', style: TextStyle(color: AppColors.goldWarm)),
                        ),
                        title: Text(
                          'Wall ${index + 1}',
                          style: const TextStyle(color: Colors.white, fontFamily: 'Inter'),
                        ),
                        subtitle: Text(
                          '${area.toStringAsFixed(1)} px² • Confidence: ${((wall['confidence'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}%',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontFamily: 'Inter'),
                        ),
                        onTap: () => _selectWall(wall['id'] as String),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() => _selectingWall = false),
                  child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Calibration Overlay ──────────────────────────────────────────────────

  Widget _buildCalibrationOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.7),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.goldWarm.withValues(alpha: 0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Calibrate Wall Scale',
                  style: TextStyle(
                    color: AppColors.goldWarm,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap two points on a known reference (door width, tile, etc.), then enter its real length',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _calibrationLengthController,
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Real Length ($_calibrationUnit)',
                          labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: _calibrationUnit,
                      dropdownColor: Colors.grey[900],
                      style: const TextStyle(color: Colors.white),
                      items: ['ft', 'm', 'in', 'cm'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                      onChanged: (v) => setState(() => _calibrationUnit = v!),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _calibrationMode = false),
                      child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
                    ),
                    ElevatedButton(
                      onPressed: _finishCalibration,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.goldWarm, foregroundColor: Colors.black),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Quantity Display ─────────────────────────────────────────────────────

  Widget _buildQuantityDisplay() {
    final r = _quantityResult!;
    final isCalibrated = r['isCalibrated'] == true;
    final unit = r['unit']?.toString() ?? 'mm';
    final calibrationUnit = r['calibrationUnit']?.toString() ?? unit;
    
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 100,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.goldWarm.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calculate, color: AppColors.goldWarm, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Material Estimate',
                  style: TextStyle(color: AppColors.goldWarm, fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'Inter'),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isCalibrated ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isCalibrated ? Colors.green : Colors.orange,
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    isCalibrated ? 'CALIBRATED ($calibrationUnit)' : 'ESTIMATED ($unit)',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: isCalibrated ? Colors.green : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildQuantityRow('Wall Size', '${r['wallWidth']} × ${r['wallHeight']} $unit'),
            _buildQuantityRow('Wall Area', '${r['wallArea']} $unit²'),
            if (r['tileWidth'] != null) ...[
              _buildQuantityRow('Tile Size', '${r['tileWidth']} × ${r['tileHeight']} $unit'),
              _buildQuantityRow('Tile Area', '${r['tileArea']} $unit²'),
            ] else ...[
              _buildQuantityRow('Tile Area', '${r['tileArea']} $unit²'),
            ],
            _buildQuantityRow('Base Quantity', '${r['baseQuantity']} tiles'),
            _buildQuantityRow('Wastage', '${r['wastagePercent']}%'),
            _buildQuantityRow('Recommended', '${r['recommendedQuantity']} tiles', highlight: true),
            const SizedBox(height: 12),
            if (_selectedStone != null)
              Text(
                'Est. Cost: ₹${(_selectedStone!.pricePerSqFt * (r['wallArea'] as num) * (1 + (r['wastagePercent'] as num) / 100)).toStringAsFixed(0)}',
                style: TextStyle(color: AppColors.goldWarm, fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, fontFamily: 'Inter')),
          Text(value, style: TextStyle(color: highlight ? AppColors.goldWarm : Colors.white, fontSize: 13, fontWeight: highlight ? FontWeight.w700 : FontWeight.w500, fontFamily: 'Inter')),
        ],
      ),
    );
  }

  /// Camera feed
  Widget _buildCamera() {
    final assetPath = _selectedStone?.arTextureUrl;

    return Positioned.fill(
      child: ARCameraView(
        key: const ValueKey('ar-camera-main'),
        stoneImagePath: assetPath,
        opacity: _textureOpacity,
        onReady: () {
          if (!mounted) return;
          setState(() => _cameraReady = true);
          if (assetPath != null) {
            ARCameraView.updateStone(assetPath, _textureOpacity);
            // Set tile dimensions for accurate pattern generation
            final stone = _selectedStone;
            if (stone != null) {
              final sizeParts = stone.size.split('×');
              if (sizeParts.length >= 2) {
                final width = double.tryParse(sizeParts[0].replaceAll('mm', '').trim()) ?? 600;
                final height = double.tryParse(sizeParts[1].replaceAll('mm', '').trim()) ?? 600;
                ARCameraView.setTileDimensions(width, height, 'mm');
              }
            }
          }
        },
        onError: () {},
      ),
    );
  }

  /// Top bar — back button, title, settings toggle
  Widget _buildTopBar() {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(12, topPadding + 6, 12, 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.85),
              Colors.black.withValues(alpha: 0.0),
            ],
          ),
        ),
        child: Row(
          children: [
            // Back button
            // Flexible is required here: Row gives non-flex children an
            // unbounded max-width, and IconButton's min-tap-target wrapper
            // (_InputPadding) throws on infinite width constraints once a
            // Spacer/Expanded sibling forces that intrinsic-width query.
            Flexible(
              child: IconButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home');
                  }
                },
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 0.8,
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 15,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            const Spacer(),

            // Title
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'LIVE AI VISUALIZER',
                  style: TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.goldWarm,
                    letterSpacing: 2.2,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'REAL-TIME WALL MAPPING',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.7),
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Measure / record button — tap to measure, press-and-hold to record
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _measureMode = true);
              },
              onLongPressStart: (_) => _startRecording(),
              onLongPressEnd: (_) => _stopRecording(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isRecording
                      ? Colors.red.withValues(alpha: 0.55)
                      : Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isRecording
                        ? Colors.red
                        : Colors.white.withValues(alpha: 0.2),
                    width: _isRecording ? 1.4 : 0.8,
                  ),
                ),
                child: Icon(
                  _isRecording
                      ? Icons.fiber_manual_record_rounded
                      : Icons.straighten_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),

            // Settings button
            Flexible(
              child: IconButton(
                onPressed: _showSettingsSheet,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 0.8,
                    ),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    size: 17,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bottom horizontal product carousel — swipe left/right to browse stones, tap to select.
  /// Premium commercial AR product style with product info and CTAs.
  Widget _buildBottomProductCarousel() {
    if (_filteredStones.isEmpty) return const SizedBox.shrink();

    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Positioned(
      left: 0,
      right: 0,
      bottom: bottomInset,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.0),
              Colors.black.withValues(alpha: 0.9),
              Colors.black.withValues(alpha: 0.98),
            ],
            stops: const [0.0, 0.3, 1.0],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Product carousel
            SizedBox(
              height: 90,
              child: PageView.builder(
                controller: _stonePageController,
                scrollDirection: Axis.horizontal,
                itemCount: _filteredStones.length,
                onPageChanged: (index) => _selectStone(index),
                itemBuilder: (context, index) {
                  final item = _filteredStones[index];
                  final isSelected = index == _selectedStoneIndex;
                  final thumbPath = item.images.isNotEmpty
                      ? item.images.first
                      : 'assets/images/placeholder_stone.png';

                  return Center(
                    child: GestureDetector(
                      onTap: () {
                        _stonePageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutCubic,
                        );
                        _selectStone(index);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: EdgeInsets.symmetric(
                          horizontal: isSelected ? 8 : 16,
                          vertical: 8,
                        ),
                        width: isSelected ? 120 : 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: isSelected
                              ? const LinearGradient(
                                  colors: [
                                    AppColors.goldWarm,
                                    AppColors.goldLight,
                                    AppColors.goldWarm,
                                  ],
                                )
                              : null,
                          color: isSelected
                              ? null
                              : Colors.black.withValues(alpha: 0.4),
                          border: !isSelected
                              ? Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  width: 1,
                                )
                              : null,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppColors.goldWarm.withValues(alpha: 0.4),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.asset(
                                thumbPath,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => Container(
                                  color: const Color(0xFF222222),
                                  child: const Icon(
                                    Icons.texture,
                                    color: AppColors.goldWarm,
                                    size: 24,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          Colors.black.withValues(alpha: 0.9),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.productCode.isNotEmpty
                                              ? item.productCode
                                              : item.name.split(' ').first,
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (item.size.isNotEmpty)
                                          Text(
                                            item.size,
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 9,
                                              color: Colors.white.withValues(alpha: 0.7),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // CTAs Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // View Product
                  Expanded(
                    child: _buildCtaButton(
                      icon: Icons.arrow_forward_rounded,
                      label: 'View Product',
                      onTap: _navigateToProduct,
                      isPrimary: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Measure Wall
                  Expanded(
                    child: _buildCtaButton(
                      icon: Icons.straighten_rounded,
                      label: 'Measure Wall',
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _startCalibration();
                      },
                      isPrimary: false,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Save Design
                  Expanded(
                    child: _buildCtaButton(
                      icon: Icons.bookmark_add_rounded,
                      label: 'Save Design',
                      onTap: _saveDesign,
                      isPrimary: false,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Get Quote
                  Expanded(
                    child: _buildCtaButton(
                      icon: Icons.request_quote_rounded,
                      label: 'Get Quote',
                      onTap: _requestQuote,
                      isPrimary: false,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCtaButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isPrimary
                ? AppColors.goldWarm
                : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPrimary
                  ? AppColors.goldWarm
                  : Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isPrimary ? Colors.black : Colors.white,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isPrimary ? Colors.black : Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Floating "i" button (bottom-left) — toggles a compact product info
  /// card with pricing and a link through to the product page.
  Widget _buildInfoButton() {
    final stone = _selectedStone;
    if (stone == null) return const SizedBox.shrink();

    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Positioned(
      left: 14,
      bottom: bottomInset + 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Expandable info card
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: !_showInfoCard
                ? const SizedBox.shrink()
                : ClipRRect(
                    key: const ValueKey('info-card'),
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        constraints: const BoxConstraints(maxWidth: 220),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.82),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.goldWarm.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                stone.images.isNotEmpty
                                    ? stone.images.first
                                    : 'assets/images/placeholder_stone.png',
                                width: 38,
                                height: 38,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => Container(
                                  width: 38,
                                  height: 38,
                                  color: const Color(0xFF2A2A2A),
                                  child: const Icon(
                                    Icons.texture,
                                    color: AppColors.goldWarm,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    stone.name,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '₹${stone.pricePerSqFt}/sq.ft',
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.goldWarm,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: _navigateToProduct,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: AppColors.goldWarm,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 14,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),

          // "i" toggle button
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _showInfoCard = !_showInfoCard);
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.goldWarm.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.info_outline_rounded,
                color: AppColors.goldWarm,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Settings bottom sheet for opacity + scale controls
  void _showSettingsSheet() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.9),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                    border: Border.all(
                      color: AppColors.goldWarm.withValues(alpha: 0.3),
                      width: 0.8,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle
                      Container(
                        width: 36,
                        height: 3.5,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      // Title
                      const Text(
                        'Texture Settings',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Opacity slider
                      _buildSliderRow(
                        icon: Icons.opacity_rounded,
                        label: 'Opacity',
                        value: _textureOpacity,
                        min: 0.1,
                        max: 1.0,
                        displayValue: '${(_textureOpacity * 100).round()}%',
                        onChanged: (v) {
                          setSheetState(() => _textureOpacity = v);
                          _onOpacityChanged(v);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Scale slider
                      _buildSliderRow(
                        icon: Icons.zoom_out_map_rounded,
                        label: 'Scale',
                        value: _textureScale,
                        min: 0.3,
                        max: 3.0,
                        displayValue: '${_textureScale.toStringAsFixed(1)}x',
                        onChanged: (v) {
                          setSheetState(() => _textureScale = v);
                          _onScaleChanged(v);
                        },
                      ),
                      const SizedBox(height: 20),

// Fix wall angle — manual corner adjustment
                       SizedBox(
                         width: double.infinity,
                         child: OutlinedButton.icon(
                           onPressed: !_cameraReady
                               ? null
                               : () {
                                   Navigator.of(context).pop();
                                   setState(() => _adjustingCorners = true);
                                 },
                           icon: const Icon(Icons.crop_free_rounded, size: 18),
                           label: const Text('Fix Wall Angle'),
                           style: OutlinedButton.styleFrom(
                             foregroundColor: AppColors.goldWarm,
                             side: BorderSide(
                                 color: AppColors.goldWarm.withValues(alpha: 0.5)),
                             padding: const EdgeInsets.symmetric(vertical: 12),
                           ),
                         ),
                       ),
                       const SizedBox(height: 12),

                       // Select wall (when multiple detected)
                       SizedBox(
                         width: double.infinity,
                         child: OutlinedButton.icon(
                           onPressed: !_cameraReady
                               ? null
                               : () {
                                   Navigator.of(context).pop();
                                   _enterWallSelection();
                                 },
                           icon: const Icon(Icons.view_in_ar_rounded, size: 18),
                           label: const Text('Select Wall'),
                           style: OutlinedButton.styleFrom(
                             foregroundColor: AppColors.goldWarm,
                             side: BorderSide(
                                 color: AppColors.goldWarm.withValues(alpha: 0.5)),
                             padding: const EdgeInsets.symmetric(vertical: 12),
                           ),
                         ),
                       ),
                       const SizedBox(height: 12),

                       // Calibrate scale
                       SizedBox(
                         width: double.infinity,
                         child: OutlinedButton.icon(
                           onPressed: !_cameraReady
                               ? null
                               : () {
                                   Navigator.of(context).pop();
                                   _startCalibration();
                                 },
                           icon: const Icon(Icons.straighten_rounded, size: 18),
                           label: const Text('Calibrate Scale'),
                           style: OutlinedButton.styleFrom(
                             foregroundColor: AppColors.goldWarm,
                             side: BorderSide(
                                 color: AppColors.goldWarm.withValues(alpha: 0.5)),
                             padding: const EdgeInsets.symmetric(vertical: 12),
                           ),
                         ),
                       ),
                       const SizedBox(height: 12),

                       // Calculate quantity
                       SizedBox(
                         width: double.infinity,
                         child: OutlinedButton.icon(
                           onPressed: !_cameraReady || _quantityResult != null
                               ? null
                               : () {
                                   Navigator.of(context).pop();
                                   _calculateQuantity();
                                 },
                           icon: const Icon(Icons.calculate_rounded, size: 18),
                           label: const Text('Calculate Quantity'),
                           style: OutlinedButton.styleFrom(
                             foregroundColor: AppColors.goldWarm,
                             side: BorderSide(
                                 color: AppColors.goldWarm.withValues(alpha: 0.5)),
                             padding: const EdgeInsets.symmetric(vertical: 12),
                           ),
                         ),
                       ),
                     ],
                   ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSliderRow({
    required IconData icon,
    required String label,
    required double value,
    required double min,
    required double max,
    required String displayValue,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.goldWarm.withValues(alpha: 0.8)),
        const SizedBox(width: 10),
        SizedBox(
          width: 55,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              activeTrackColor: AppColors.goldWarm,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
              thumbColor: AppColors.goldWarm,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 14),
              overlayColor: AppColors.goldWarm.withValues(alpha: 0.15),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            displayValue,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.goldWarm,
            ),
          ),
        ),
      ],
    );
  }
}
