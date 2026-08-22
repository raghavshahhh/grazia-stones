import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grazia_stones/core/providers/stone_providers.dart';
import 'package:grazia_stones/core/services/ai_visualization_service.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/shared/widgets/smart_stone_image.dart';

class AIVizScreen extends ConsumerStatefulWidget {
  const AIVizScreen({super.key});

  @override
  ConsumerState<AIVizScreen> createState() => _AIVizScreenState();
}

class _AIVizScreenState extends ConsumerState<AIVizScreen> {
  Uint8List? _selectedImage;
  Uint8List? _visualizedImage;
  bool _wallNotDetected = false;
  String? _selectedStoneId;
  bool _isProcessing = false;
  bool _textureApplied = false;
  bool _showOriginal = false;
  final _picker = ImagePicker();
  final _aiVizService = AIVisualizationService.instance;

  @override
  void initState() {
    super.initState();
    _aiVizService.init();
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
          _showOriginal = false;
        });
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting image: $e')),
      );
    }
  }

  Future<void> _applyStoneTexture() async {
    if (_selectedImage == null || _selectedStoneId == null) return;

    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    try {
      final allStones = ref.read(allStonesProvider).valueOrNull ?? [];
      final stone = allStones.firstWhere(
        (s) => s.id == _selectedStoneId,
        orElse: () => allStones.first,
      );
      
      final tempDir = await Directory.systemTemp.createTemp('aiviz_');
      final imageFile = File('${tempDir.path}/room_image.jpg');
      await imageFile.writeAsBytes(_selectedImage!);

      final result = await _aiVizService.generateVisualization(
        roomImage: imageFile,
        stone: stone,
        onProgress: (progress) {},
      );

      if (!mounted) return;
      
      try { await tempDir.delete(recursive: true); } catch (_) {}

      setState(() {
        _isProcessing = false;
        _visualizedImage = base64Decode(result.visualizedImageUrl.split(',').last);
        _textureApplied = true;
        _wallNotDetected = false;
      });
      HapticFeedback.heavyImpact();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _visualizedImage = null;
        _textureApplied = false;
        _wallNotDetected = true;
      });
      debugPrint('❌ AI Visualization error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);
    final allStones = ref.watch(allStonesProvider).valueOrNull ?? [];
    final stones = allStones.take(12).toList();
    final selectedStone = _selectedStoneId != null
        ? stones.where((s) => s.id == _selectedStoneId).firstOrNull
        : null;

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
          'AI Studio',
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
            // Studio Hero Card
            Container(
              padding: const EdgeInsets.all(18),
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
                    child: Icon(Icons.auto_awesome_rounded, color: palette.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Photorealistic Rendering',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: palette.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Upload your wall or floor to visualize marble & natural stone in architectural lighting.',
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

            // Step 1: Upload Room Photo
            Text(
              '1. UPLOAD ROOM PHOTO',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
                color: palette.textTertiary,
              ),
            ),
            const SizedBox(height: 12),

            if (_selectedImage == null)
              Row(
                children: [
                  Expanded(
                    child: _buildUploadCard(
                      palette,
                      'Take Photo',
                      Icons.camera_alt_outlined,
                      () => _pickImage(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildUploadCard(
                      palette,
                      'Upload Gallery',
                      Icons.photo_library_outlined,
                      () => _pickImage(ImageSource.gallery),
                    ),
                  ),
                ],
              )
            else
              _buildImagePreviewCard(palette),

            if (_wallNotDetected) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Ensure the target wall is unobstructed and well lit for optimal AI surface placement.',
                        style: GoogleFonts.inter(fontSize: 12, color: palette.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 28),

            // Step 2: Choose Stone
            Text(
              '2. SELECT NATURAL STONE',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
                color: palette.textTertiary,
              ),
            ),
            const SizedBox(height: 12),

            _buildStoneSelectorGrid(palette, stones),

            if (_textureApplied && _visualizedImage != null && selectedStone != null)
              _buildAppliedStoneSummary(palette, selectedStone),

            const SizedBox(height: 110),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 14,
          bottom: MediaQuery.of(context).padding.bottom + 14,
        ),
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border(top: BorderSide(color: palette.border, width: 1.0)),
        ),
        child: ElevatedButton.icon(
          onPressed: _selectedImage != null && _selectedStoneId != null && !_isProcessing
              ? _applyStoneTexture
              : null,
          icon: _isProcessing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.auto_awesome_rounded, size: 18),
          label: Text(
            _isProcessing
                ? 'Rendering Space...'
                : _textureApplied
                    ? 'Re-Render Surface'
                    : 'Generate AI Visualization',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: palette.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
            disabledBackgroundColor: palette.border,
          ),
        ),
      ),
    );
  }

  Widget _buildUploadCard(LuxuryPalette palette, String label, IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 28),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: palette.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: palette.primary, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreviewCard(LuxuryPalette palette) {
    final displayImage = (_showOriginal || _visualizedImage == null)
        ? _selectedImage!
        : _visualizedImage!;

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Stack(
          children: [
            Image.memory(
              displayImage,
              height: 260,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
            // Comparison Toggle button
            if (_visualizedImage != null)
              Positioned(
                bottom: 12,
                left: 12,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _showOriginal = !_showOriginal);
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        color: Colors.black.withValues(alpha: 0.6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.compare_arrows_rounded, color: Colors.white, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              _showOriginal ? 'Showing: Original' : 'Showing: AI Render',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Remove/Reset button
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _selectedImage = null;
                    _visualizedImage = null;
                    _selectedStoneId = null;
                    _textureApplied = false;
                    _wallNotDetected = false;
                    _showOriginal = false;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoneSelectorGrid(LuxuryPalette palette, List stones) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.8,
      ),
      itemCount: stones.length,
      itemBuilder: (context, i) {
        final stone = stones[i];
        final isSelected = _selectedStoneId == stone.id;

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selectedStoneId = stone.id);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? palette.primary : palette.border,
                width: isSelected ? 2.0 : 1.0,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: palette.primary.withValues(alpha: 0.25), blurRadius: 8)]
                  : [],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SmartStoneImage(
                      imageUrl: stone.imageUrl,
                      fit: BoxFit.cover,
                      palette: palette,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Column(
                      children: [
                        Text(
                          stone.name,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: palette.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹${stone.pricePerSqFt.toInt()}/sqft',
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
          ),
        );
      },
    );
  }

  Widget _buildAppliedStoneSummary(LuxuryPalette palette, dynamic stone) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Surface Render Complete',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
                Text(
                  '${stone.name} • ₹${stone.pricePerSqFt.toInt()} / sq ft',
                  style: GoogleFonts.inter(fontSize: 11, color: palette.textSecondary),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.push('/stones/${stone.id}'),
            child: Text(
              'Details →',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: palette.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
