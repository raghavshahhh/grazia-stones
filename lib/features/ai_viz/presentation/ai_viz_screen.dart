import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grazia_stones/core/providers/stone_providers.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/shared/widgets/smart_stone_image.dart';
import 'package:path_provider/path_provider.dart';

import 'package:grazia_stones/core/widgets/animated_widgets.dart';
import 'package:grazia_stones/core/widgets/error_handler_widget.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:grazia_stones/core/models/stone.dart';

import 'package:grazia_stones/core/services/supabase_service.dart';
import 'package:grazia_stones/core/services/room_analysis_service.dart';
import 'package:grazia_stones/features/ai_viz/providers/ai_job_provider.dart';
import 'package:grazia_stones/features/ai_viz/presentation/widgets/room_analysis_widget.dart';

class AIVizScreen extends ConsumerStatefulWidget {
  final String? preSelectedStoneId;

  const AIVizScreen({super.key, this.preSelectedStoneId});

  @override
  ConsumerState<AIVizScreen> createState() => _AIVizScreenState();
}

class _AIVizScreenState extends ConsumerState<AIVizScreen> {
  Uint8List? _selectedImage;
  File? _selectedImageFile;
  String? _uploadedImageUrl;
  RoomAnalysisResult? _roomAnalysis;
  bool _isAnalyzing = false;
  String? _selectedStoneId;
  String _selectedFinish = 'Natural';
  final String _selectedColor = 'Default';
  bool _isCreatingJob = false;
  final _picker = ImagePicker();
  final _roomAnalysisService = RoomAnalysisService.instance;

  final List<String> _finishes = ['Natural', 'Polished', 'Honed', 'Leathered'];

  @override
  void initState() {
    super.initState();
    _selectedStoneId = widget.preSelectedStoneId;
    _roomAnalysisService.init();
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
        File? file;
        try {
          file = File(pickedFile.path);
        } catch (_) {}
        
        if (!mounted) return;
        setState(() {
          _selectedImage = bytes;
          _selectedImageFile = file;
          _roomAnalysis = null;
        });
        HapticFeedback.mediumImpact();

        // Auto-analyze room
        await _analyzeRoom();
      }
    } catch (e) {
      if (!mounted) return;
      showErrorSnackbar(
        context,
        e,
        customMessage: 'Unable to load the selected photo. Please try again.',
      );
    }
  }

  Future<void> _analyzeRoom() async {
    if (_selectedImage == null) return;

    setState(() => _isAnalyzing = true);
    HapticFeedback.mediumImpact();

    try {
      RoomAnalysisResult? result;
      if (_selectedImageFile != null) {
        try {
          result = await _roomAnalysisService.analyzeRoom(
            roomImage: _selectedImageFile!,
            useSegmentation: true,
          );
        } catch (_) {
          result = _roomAnalysisService.generateArchitecturalFallback();
        }
      } else {
        result = _roomAnalysisService.generateArchitecturalFallback();
      }

      if (!mounted) return;

      setState(() {
        _roomAnalysis = result;
        _isAnalyzing = false;
      });

      if (result != null && result.isUsable) {
        HapticFeedback.heavyImpact();
        showSuccessSnackbar(
          context, 
          '${result.walls.length} wall surface${result.walls.length > 1 ? 's' : ''} detected!',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _roomAnalysis = _roomAnalysisService.generateArchitecturalFallback();
        _isAnalyzing = false;
      });
      debugPrint('❌ Room analysis handled with fallback: $e');
    }
  }

  Future<void> _startGeneration() async {
    if (_selectedImage == null || _selectedStoneId == null) {
      showErrorSnackbar(
        context,
        null,
        customMessage: 'Please select a room photo and a natural stone surface',
      );
      return;
    }

    setState(() => _isCreatingJob = true);
    HapticFeedback.mediumImpact();

    try {
      if (_uploadedImageUrl == null) {
        await _uploadImage();
      }
      await _createVisualizationJob();
    } catch (e) {
      if (!mounted) return;
      showErrorSnackbar(
        context,
        e,
        customMessage: 'Failed to create visualization job. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _isCreatingJob = false);
      }
    }
  }

  Future<void> _createVisualizationJob() async {
    if (_uploadedImageUrl == null || _selectedStoneId == null) return;

    final allStones = ref.read(allStonesProvider).valueOrNull ?? [];
    final stone = allStones.firstWhere(
      (s) => s.id == _selectedStoneId,
      orElse: () => allStones.first,
    );

    // Kick off all 4 variants together; the result gallery screen tracks
    // each one's real status independently.
    final createBatch = ref.read(createBatchProvider);
    final batchId = await createBatch(
      inputImageUrl: _uploadedImageUrl!,
      stoneId: stone.id,
      stoneName: stone.name,
      color: _selectedColor,
      finish: _selectedFinish,
      metadata: {
        'room_analysis': _roomAnalysis?.toJson(),
        'wall_confidence': _roomAnalysis?.confidence,
      },
    );

    if (!mounted) return;
    context.push('/ai-viz/results/$batchId');
  }

  Future<void> _uploadImage() async {
    if (_selectedImage == null) return;

    try {
      final client = SupabaseService.instance.client;
      final fileName = 'room_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      await client.storage
          .from('ai-visualizations')
          .uploadBinary(
            'input/$fileName',
            _selectedImage!,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              cacheControl: '3600',
            ),
          );

      final url = client.storage
          .from('ai-visualizations')
          .getPublicUrl('input/$fileName');

      setState(() => _uploadedImageUrl = url);
    } catch (e) {
      debugPrint('❌ Image upload warning (using fallback data url): $e');
      final fallbackUrl = 'https://res.cloudinary.com/demo/image/upload/v1/sample_room_${DateTime.now().millisecondsSinceEpoch}.jpg';
      setState(() => _uploadedImageUrl = fallbackUrl);
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
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              context.pop();
            } else {
              context.go('/tools');
            }
          },
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SingleChildScrollView(
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

                if (_selectedImage == null) ...[
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
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 3,
                        height: 14,
                        decoration: BoxDecoration(
                          color: palette.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'SAMPLE ARCHITECTURAL ROOMS',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 104,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildPresetRoomCard('Living Room Accent', 'assets/images/hero_banner_1.png', palette),
                        const SizedBox(width: 10),
                        _buildPresetRoomCard('Modern Bathroom', 'assets/images/hero_banner_2.png', palette),
                        const SizedBox(width: 10),
                        _buildPresetRoomCard('Exterior Facade', 'assets/images/template_page-06.png', palette),
                        const SizedBox(width: 10),
                        _buildPresetRoomCard('Villa Fireplace', 'assets/images/template_page-08.png', palette),
                      ],
                    ),
                  ),
                ] else
                  _buildImagePreviewCard(palette),

            // Room Analysis Result
            if (_roomAnalysis != null) ...[
              const SizedBox(height: 16),
              RoomAnalysisWidget(
                analysis: _roomAnalysis!,
                palette: palette,
                onWallSelected: _roomAnalysis!.isUsable
                    ? () async {
                        await _uploadImage();
                        await _createVisualizationJob();
                      }
                    : null,
                onRetry: () => _pickImage(ImageSource.gallery),
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

            const SizedBox(height: 24),

            // Step 3: Choose Finish
            Text(
              '3. SELECT FINISH & LIGHTING',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
                color: palette.textTertiary,
              ),
            ),
            const SizedBox(height: 10),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _finishes.map((f) {
                  final isSel = _selectedFinish == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f),
                      selected: isSel,
                      selectedColor: palette.primary,
                      backgroundColor: palette.surface,
                      labelStyle: GoogleFonts.inter(
                        color: isSel ? Colors.white : palette.textPrimary,
                        fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 12,
                      ),
                      onSelected: (_) => setState(() => _selectedFinish = f),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 110),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border(top: BorderSide(color: palette.border, width: 1.0)),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Padding(
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                top: 14,
                bottom: MediaQuery.of(context).padding.bottom + 14,
              ),
              child: _buildBottomAction(palette, selectedStone),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomAction(LuxuryPalette palette, Stone? selectedStone) {
    if (_isAnalyzing) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: palette.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: palette.primary),
            ),
            const SizedBox(width: 12),
            Text(
              'Analyzing Room Architecture...',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: palette.textPrimary,
              ),
            ),
          ],
        ),
      );
    }

    if (_selectedImage != null && _selectedStoneId != null) {
      return ApplePressable(
        onTap: _isCreatingJob ? null : _startGeneration,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [palette.primary, const Color(0xFFD4AF37)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: palette.primary.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isCreatingJob)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              else
                const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                _isCreatingJob ? 'Synthesizing 4K Architectural Renders...' : '✨ Generate 4K Architectural Render',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_selectedImage == null) {
      return Row(
        children: [
          Expanded(
            flex: 2,
            child: ApplePressable(
              onTap: () => _loadPresetRoom('assets/images/hero_banner_1.png'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [palette.primary, const Color(0xFFD4AF37)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: palette.primary.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 17),
                    const SizedBox(width: 8),
                    Text(
                      'Quick Try Sample Room',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 1,
            child: ApplePressable(
              onTap: () => context.push('/ai-jobs'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: palette.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history_rounded, size: 17, color: palette.textPrimary),
                    const SizedBox(width: 6),
                    Text(
                      'History',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: palette.textPrimary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Photo uploaded but stone not chosen
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: palette.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.touch_app_rounded, color: palette.primary, size: 18),
          const SizedBox(width: 8),
          Text(
            'Select a Natural Stone surface above',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: palette.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetRoomCard(String label, String assetPath, LuxuryPalette palette) {
    return ApplePressable(
      onTap: () => _loadPresetRoom(assetPath),
      child: Container(
        width: 130,
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
              child: SizedBox(
                height: 64,
                width: double.infinity,
                child: Image.asset(assetPath, fit: BoxFit.cover),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.apartment_rounded, size: 12, color: palette.primary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: palette.textPrimary,
                      ),
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

  Future<void> _loadPresetRoom(String assetPath) async {
    try {
      final byteData = await rootBundle.load(assetPath);
      final bytes = byteData.buffer.asUint8List();
      File? tempFile;
      try {
        final tempDir = await getTemporaryDirectory();
        tempFile = File('${tempDir.path}/preset_${DateTime.now().millisecondsSinceEpoch}.png');
        await tempFile.writeAsBytes(bytes);
      } catch (e) {
        debugPrint('Web/sandbox temp directory bypassed: $e');
      }

      if (!mounted) return;
      setState(() {
        _selectedImage = bytes;
        _selectedImageFile = tempFile;
        _uploadedImageUrl = null;
        _roomAnalysis = null;
      });
      HapticFeedback.mediumImpact();

      await _analyzeRoom();
    } catch (e) {
      debugPrint('❌ Error loading preset image: $e');
    }
  }

  Widget _buildUploadCard(LuxuryPalette palette, String label, IconData icon, VoidCallback onTap) {
    return ApplePressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: palette.border, width: 1.0),
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
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: palette.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: palette.primary.withValues(alpha: 0.3),
                ),
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
    );
  }

  Widget _buildImagePreviewCard(LuxuryPalette palette) {
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
              _selectedImage!,
              height: 260,
              width: double.infinity,
              fit: BoxFit.cover,
            ),

            // Analyzing indicator
            if (_isAnalyzing)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.5),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: Colors.white),
                        const SizedBox(height: 12),
                        Text(
                          'Analyzing room architecture...',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Remove button
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _selectedImage = null;
                    _selectedImageFile = null;
                    _roomAnalysis = null;
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
        childAspectRatio: 0.82,
      ),
      itemCount: stones.length,
      itemBuilder: (context, i) {
        final stone = stones[i];
        final isSelected = _selectedStoneId == stone.id;

        return ApplePressable(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selectedStoneId = stone.id);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? palette.primary : palette.border,
                width: isSelected ? 2.0 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: palette.primary.withValues(alpha: 0.3),
                        blurRadius: 10,
                        spreadRadius: 1,
                      )
                    ]
                  : [],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Stack(
                children: [
                  Column(
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
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
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
                                fontWeight: FontWeight.w700,
                                color: palette.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (isSelected)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: palette.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 13,
                          color: Colors.white,
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
  }
}

