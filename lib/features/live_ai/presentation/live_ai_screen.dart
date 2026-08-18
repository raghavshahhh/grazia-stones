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

  // Texture controls
  double _textureOpacity = 0.75;
  double _textureScale = 1.0;

  // Controllers
  late PageController _stonePageController;

  @override
  void initState() {
    super.initState();
    _stonePageController = PageController(
      viewportFraction: 0.32,
      initialPage: 0,
    );
    _updateFilteredStones();
  }

  @override
  void dispose() {
    _stonePageController.dispose();
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

          // 3. Side tile rail — swipe to select a stone
          _buildSideTileRail(),

          // 4. Info button — product name/price + link to product page
          _buildInfoButton(),

          // 5. Tap-to-measure overlay
          if (_measureMode)
            MeasureOverlay(onClose: () => setState(() => _measureMode = false)),

          // 6. Manual wall-corner adjustment overlay
          if (_adjustingCorners)
            CornerAdjustOverlay(
                onClose: () => setState(() => _adjustingCorners = false)),
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
            IconButton(
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
            IconButton(
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
          ],
        ),
      ),
    );
  }

  /// Vertical side rail — swipe up/down to browse stones, tap to select.
  /// Sits on the right edge, native-camera-filter style.
  Widget _buildSideTileRail() {
    if (_filteredStones.isEmpty) return const SizedBox.shrink();

    return Positioned(
      right: 10,
      top: MediaQuery.of(context).padding.top + 90,
      bottom: MediaQuery.of(context).padding.bottom + 30,
      child: SizedBox(
        width: 64,
        child: PageView.builder(
          controller: _stonePageController,
          scrollDirection: Axis.vertical,
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: isSelected ? 56 : 46,
                      height: isSelected ? 56 : 46,
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
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
                            : Colors.black.withValues(alpha: 0.35),
                        border: !isSelected
                            ? Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1,
                              )
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color:
                                      AppColors.goldWarm.withValues(alpha: 0.5),
                                  blurRadius: 14,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black,
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            thumbPath,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => Container(
                              color: const Color(0xFF222222),
                              child: const Icon(
                                Icons.texture,
                                color: AppColors.goldWarm,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.productCode.isNotEmpty
                          ? item.productCode
                          : item.name.split(' ').first,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 8,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? AppColors.goldWarm
                            : Colors.white.withValues(alpha: 0.8),
                        shadows: const [
                          Shadow(color: Colors.black, blurRadius: 4),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
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
