import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:grazia_stones/core/providers/stone_providers.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/typography.dart';
import 'package:grazia_stones/shared/theme/spacing.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/shared/widgets/smart_stone_image.dart';
import 'package:grazia_stones/features/live_ai/presentation/widgets/ar_camera_view.dart';

class AIVizScreen extends ConsumerStatefulWidget {
  const AIVizScreen({super.key});

  @override
  ConsumerState<AIVizScreen> createState() => _AIVizScreenState();
}

class _AIVizScreenState extends ConsumerState<AIVizScreen>
    with SingleTickerProviderStateMixin {
  // Mode: 'photo' or 'live'
  String _mode = 'photo';

  Uint8List? _selectedImage;
  Uint8List? _visualizedImage;
  bool _wallNotDetected = false;
  String? _selectedStoneId;
  bool _isProcessing = false;
  bool _textureApplied = false;
  bool _cameraReady = false;
  double _arOpacity = 0.72;
  final _picker = ImagePicker();

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _mode = _tabController.index == 0 ? 'photo' : 'live';
          if (_mode == 'live') {
            _cameraReady = false;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    ARCameraView.stopCamera();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        if (!mounted) return;
        setState(() {
          _selectedImage = bytes;
          _visualizedImage = null;
          _textureApplied = false;
          _wallNotDetected = false;
        });
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _applyStoneTexture() async {
    if ((_mode == 'photo' && (_selectedImage == null || _selectedStoneId == null)) ||
        (_mode == 'live' && _selectedStoneId == null)) {
      return;
    }

    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    if (_mode == 'photo') {
      final allStones = ref.read(allStonesProvider).valueOrNull ?? [];
      final stone = allStones.firstWhere((s) => s.id == _selectedStoneId,
          orElse: () => allStones.first);
      final textureUrl = stone.images.isNotEmpty ? stone.images.first : null;

      String? resultDataUrl;
      if (textureUrl != null) {
        final roomDataUrl = 'data:image/jpeg;base64,${base64Encode(_selectedImage!)}';
        resultDataUrl = await ARCameraView.renderStaticVisualization(
            roomDataUrl, textureUrl, _arOpacity);
      }

      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        if (resultDataUrl != null) {
          _visualizedImage = base64Decode(resultDataUrl.split(',').last);
          _textureApplied = true;
          _wallNotDetected = false;
        } else {
          _visualizedImage = null;
          _textureApplied = false;
          _wallNotDetected = true;
        }
      });
      HapticFeedback.heavyImpact();
      return;
    }

    if (_mode == 'live') {
      // Live camera: directly update the AR overlay
      final allStones = ref.read(allStonesProvider).valueOrNull ?? [];
      final stone = allStones
          .firstWhere((s) => s.id == _selectedStoneId, orElse: () => allStones.first);
      final path = stone.images.isNotEmpty ? stone.images.first : null;
      ARCameraView.updateStone(path, _arOpacity);
      ARCameraView.showWallBoundary(true);
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        setState(() {
          _isProcessing = false;
          _textureApplied = true;
        });
        HapticFeedback.heavyImpact();
      });
    }
  }



  Widget _buildPhotoTab(LuxuryPalette palette, List stones, dynamic selectedStone) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info banner
          _buildInfoBanner(palette,
            icon: Icons.auto_awesome,
            title: 'Upload your space',
            subtitle: 'Upload a photo of your room or wall, select a stone, and see it transform!',
          ),
          GLuxurySpacing.gapXl,

          // Step 1: Upload
          Text('Step 1: Upload Your Space',
              style: GLuxuryTypography.h3.copyWith(color: palette.textPrimary)),
          GLuxurySpacing.gapSm,

          if (_selectedImage == null)
            Row(
              children: [
                Expanded(
                  child: _buildUploadButton(palette, 'Camera',
                      Icons.camera_alt_outlined, () => _pickImage(ImageSource.camera)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildUploadButton(palette, 'Gallery',
                      Icons.photo_library_outlined, () => _pickImage(ImageSource.gallery)),
                ),
              ],
            )
          else
            _buildImagePreview(palette),

          if (_wallNotDetected) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Couldn't clearly detect a wall in this photo. Try a photo taken "
                      "straight-on with the wall clearly visible and well-lit.",
                      style: GLuxuryTypography.bodySmall.copyWith(color: palette.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],

          GLuxurySpacing.gapXl,

          // Step 2: Select stone
          Text('Step 2: Select Stone',
              style: GLuxuryTypography.h3.copyWith(color: palette.textPrimary)),
          GLuxurySpacing.gapSm,
          _buildStoneGrid(palette, stones),

          if (_textureApplied && _selectedImage != null && selectedStone != null)
            _buildSuccessCard(palette, selectedStone),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildImagePreview(LuxuryPalette palette) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Composited result (real tiles painted only onto the
              // detected wall region) once available, else the raw upload.
              Image.memory(
                _visualizedImage ?? _selectedImage!,
                height: 260,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
              if (_textureApplied && _visualizedImage != null) ...[
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        color: Colors.black.withValues(alpha: 0.4),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 14),
                            SizedBox(width: 4),
                            Text('Stone Applied',
                                style: TextStyle(color: Colors.white, fontSize: 11,
                                    fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Remove button
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: () => setState(() {
              _selectedImage = null;
              _visualizedImage = null;
              _selectedStoneId = null;
              _textureApplied = false;
              _wallNotDetected = false;
            }),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────── Live Camera Tab ─────────────────────────────────

  Widget _buildLiveCameraTab(LuxuryPalette palette, List stones, dynamic selectedStone) {
    return Column(
      children: [
        // Camera view (takes most of the screen)
        Expanded(
          flex: 5,
          child: Stack(
            children: [
              ARCameraView(
                key: const ValueKey('aiviz-ar-camera'),
                stoneImagePath: _cameraReady && _selectedStoneId != null
                    ? (() {
                        final allStones = ref.read(allStonesProvider).valueOrNull ?? [];
                        return allStones
                            .firstWhere((s) => s.id == _selectedStoneId,
                                orElse: () => allStones.first)
                            .images
                            .firstOrNull;
                      })()
                    : null,
                opacity: _arOpacity,
                onReady: () {
                  setState(() {
                    _cameraReady = true;
                  });
                  if (_selectedStoneId != null) {
                    final allStones = ref.read(allStonesProvider).valueOrNull ?? [];
                    final stone = allStones
                        .firstWhere((s) => s.id == _selectedStoneId, orElse: () => allStones.first);
                    ARCameraView.updateStone(
                        stone.images.isNotEmpty ? stone.images.first : null,
                        _arOpacity);
                    ARCameraView.showWallBoundary(true);
                  }
                },
                onError: () {
                  // ARCameraView shows its own error state internally
                },
              ),

              // Opacity slider overlay
              if (_cameraReady)
                Positioned(
                  right: 12,
                  top: 60,
                  bottom: 60,
                  child: _buildOpacitySlider(palette),
                ),

              // Selected stone badge
              if (_cameraReady && selectedStone != null)
                Positioned(
                  top: 12,
                  left: 12,
                  child: _buildSelectedStoneBadge(palette, selectedStone),
                ),
            ],
          ),
        ),

        // Stone selector strip
        Container(
          height: 140,
          color: palette.background,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 6),
                child: Text(
                  'SWIPE TO SELECT STONE',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: palette.textSecondary,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: stones.length,
                  itemBuilder: (ctx, i) {
                    final stone = stones[i];
                    final isSelected = _selectedStoneId == stone.id;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedStoneId = stone.id);
                        // Update live camera immediately
                        final path = stone.images.isNotEmpty ? stone.images.first : null;
                        ARCameraView.updateStone(path, _arOpacity);
                        ARCameraView.showWallBoundary(true);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        width: isSelected ? 92 : 78,
                        margin: const EdgeInsets.only(right: 10, bottom: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFC8A53C)
                                : palette.border,
                            width: isSelected ? 2.5 : 1,
                          ),
                          boxShadow: isSelected
                              ? [BoxShadow(color: const Color(0xFFC8A53C).withValues(alpha: 0.3), blurRadius: 8)]
                              : [],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              SmartStoneImage(imageUrl: stone.images.firstOrNull, palette: palette),
                              if (isSelected)
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    color: const Color(0xFFC8A53C).withValues(alpha: 0.9),
                                    child: Text(
                                      stone.productCode,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOpacitySlider(LuxuryPalette palette) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: 44,
          padding: const EdgeInsets.symmetric(vertical: 12),
          color: Colors.black.withValues(alpha: 0.35),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.opacity, color: Color(0xFFC8A53C), size: 16),
              const SizedBox(height: 8),
              Expanded(
                child: RotatedBox(
                  quarterTurns: 3,
                  child: Slider(
                    value: _arOpacity,
                    min: 0.1,
                    max: 1.0,
                    activeColor: const Color(0xFFC8A53C),
                    inactiveColor: Colors.white24,
                    onChanged: (v) {
                      setState(() => _arOpacity = v);
                      ARCameraView.updateOpacity(v);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(_arOpacity * 100).toInt()}%',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 9,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedStoneBadge(LuxuryPalette palette, dynamic stone) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          color: Colors.black.withValues(alpha: 0.5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFC8A53C),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                stone.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────── Shared helpers ──────────────────────────────────

  Widget _buildInfoBanner(LuxuryPalette palette,
      {required IconData icon, required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: palette.primaryGradient,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: palette.background, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GLuxuryTypography.labelLarge.copyWith(
                        color: palette.background, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: GLuxuryTypography.bodySmall.copyWith(
                        color: palette.background.withValues(alpha: 0.8))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoneGrid(LuxuryPalette palette, List stones) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemCount: stones.length,
      itemBuilder: (context, i) {
        final stone = stones[i];
        final isSelected = _selectedStoneId == stone.id;
        return GestureDetector(
          onTap: () {
            setState(() => _selectedStoneId = stone.id);
            HapticFeedback.selectionClick();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? palette.primary : palette.border,
                width: isSelected ? 2.5 : 1,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: palette.primary.withValues(alpha: 0.3), blurRadius: 8)]
                  : [],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SmartStoneImage(
                      imageUrl: stone.imageUrl,
                      palette: palette,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    color: isSelected ? palette.primary.withValues(alpha: 0.1) : null,
                    child: Column(
                      children: [
                        Text(
                          stone.name,
                          style: GLuxuryTypography.labelSmall.copyWith(
                              color: palette.textPrimary,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle, color: Color(0xFFC8A53C), size: 14),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuccessCard(LuxuryPalette palette, dynamic stone) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.check_circle_outline, color: Color(0xFF4CAF50), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Stone Applied!',
                    style: GLuxuryTypography.labelLarge.copyWith(
                        color: palette.textPrimary, fontWeight: FontWeight.w700)),
                Text('${stone.name} • ₹${stone.pricePerSqFt.toInt()}/sq.ft',
                    style: GLuxuryTypography.bodySmall.copyWith(color: palette.textSecondary)),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedImage = null;
                _visualizedImage = null;
                _textureApplied = false;
                _selectedStoneId = null;
                _wallNotDetected = false;
              });
            },
            child: Text('Reset', style: TextStyle(color: palette.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadButton(LuxuryPalette palette, String label, IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 36),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: palette.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: palette.background, size: 28),
              ),
              const SizedBox(height: 12),
              Text(label,
                  style: GLuxuryTypography.labelMedium.copyWith(color: palette.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Bottom action bar only for photo mode ──
  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);
    final allStones = ref.watch(allStonesProvider).valueOrNull ?? [];
    final stones = allStones.take(9).toList();
    final selectedStone = _selectedStoneId != null
        ? stones.firstWhere((s) => s.id == _selectedStoneId, orElse: () => stones.first)
        : null;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_ios_new, color: palette.textPrimary),
        ),
        title: Text(
          'AI Visualization',
          style: GLuxuryTypography.h2.copyWith(color: palette.textPrimary),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                gradient: palette.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              labelColor: palette.background,
              unselectedLabelColor: palette.textSecondary,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: '📷  Photo Mode'),
                Tab(text: '🎥  Live Camera'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPhotoTab(palette, stones, selectedStone),
          _buildLiveCameraTab(palette, stones, selectedStone),
        ],
      ),
      bottomNavigationBar: _mode == 'photo'
          ? Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(context).padding.bottom + 12,
              ),
              decoration: BoxDecoration(
                color: palette.background,
                border: Border(top: BorderSide(color: palette.border)),
              ),
              child: ElevatedButton.icon(
                onPressed: _selectedImage != null &&
                        _selectedStoneId != null &&
                        !_isProcessing
                    ? _applyStoneTexture
                    : null,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(_isProcessing
                    ? 'Applying texture…'
                    : _textureApplied
                        ? 'Re-apply Texture'
                        : 'Apply Stone Texture'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.primary,
                  foregroundColor: palette.background,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28)),
                  disabledBackgroundColor: palette.surfaceDark,
                ),
              ),
            )
          : null,
    );
  }
}
