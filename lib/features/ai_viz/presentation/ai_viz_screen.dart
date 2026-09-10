import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:grazia_stones/core/models/ai_job.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/core/providers/stone_providers.dart';
import 'package:grazia_stones/core/repositories/ai_job_repository.dart';
import 'package:grazia_stones/core/services/room_analysis_service.dart';
import 'package:grazia_stones/core/services/supabase_service.dart';
import 'package:grazia_stones/core/widgets/animated_widgets.dart';
import 'package:grazia_stones/core/widgets/error_handler_widget.dart';
import 'package:grazia_stones/features/ai_viz/presentation/widgets/room_analysis_widget.dart';
import 'package:grazia_stones/features/ai_viz/providers/ai_job_provider.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/shared/widgets/smart_stone_image.dart';

/// Luxury AI Room Studio Screen
///
/// Features:
/// 1. Room/Wall Photo Upload (Camera, Gallery, Sample Luxury Rooms)
/// 2. Surface Material Selection:
///    - Grazia Catalog (Statuario, Calacatta, Nero Marquina, Travertine, etc.)
///    - Custom Design (Upload custom tile/marble/wallpaper photo)
/// 3. Finish & Lighting Selection (Natural, Polished, Honed, Leathered, Fluted)
/// 4. AI 4K Generation Action connected to backend
/// 5. 4 Colorway Recommendations (Classic, Warm Gold, Noir Charcoal, Cool Bianco)
///    with live progress and interactive comparison modal
class AIVizScreen extends ConsumerStatefulWidget {
  final String? preSelectedStoneId;

  const AIVizScreen({super.key, this.preSelectedStoneId});

  @override
  ConsumerState<AIVizScreen> createState() => _AIVizScreenState();
}

class _AIVizScreenState extends ConsumerState<AIVizScreen> {
  // Step 1: Room Photo
  Uint8List? _selectedRoomBytes;
  File? _selectedRoomFile;
  String? _uploadedRoomUrl;
  RoomAnalysisResult? _roomAnalysis;
  bool _isAnalyzingRoom = false;

  // Step 2: Surface Selection Mode (Catalog vs Custom)
  bool _isCustomMode = false;
  String? _selectedStoneId;
  Uint8List? _customDesignBytes;
  String? _customDesignUrl;
  String _customDesignName = 'Custom Marble Design';

  // Step 3: Finish & Lighting
  String _selectedFinish = 'Natural';
  String _selectedLighting = 'Daylight Natural';
  final List<String> _finishes = ['Natural', 'Polished', 'Honed', 'Leathered', 'Fluted'];
  final List<String> _lightings = ['Daylight Natural', 'Warm Evening', 'Dramatic Accent', 'Clean Showroom'];

  // Step 4 & 5: AI Generation & Batch Results
  bool _isCreatingJob = false;
  String? _activeBatchId;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _selectedStoneId = widget.preSelectedStoneId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        RoomAnalysisService.instance.init();
      } catch (e) {
        debugPrint('RoomAnalysisService init notice: $e');
      }
    });
  }

  // ─── ROOM PHOTO PICKING ───

  Future<void> _pickRoomImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        File? file;
        try {
          file = File(picked.path);
        } catch (_) {}

        if (!mounted) return;
        setState(() {
          _selectedRoomBytes = bytes;
          _selectedRoomFile = file;
          _uploadedRoomUrl = null;
          _roomAnalysis = null;
          _activeBatchId = null;
        });
        HapticFeedback.mediumImpact();

        await _analyzeRoomPhoto();
      }
    } catch (e) {
      if (!mounted) return;
      showErrorSnackbar(
        context,
        e,
        customMessage: 'Unable to select photo. Please try again.',
      );
    }
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
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _selectedRoomBytes = bytes;
        _selectedRoomFile = tempFile;
        _uploadedRoomUrl = null;
        _roomAnalysis = null;
        _activeBatchId = null;
      });
      HapticFeedback.mediumImpact();

      await _analyzeRoomPhoto();
    } catch (e) {
      debugPrint('Preset load error: $e');
    }
  }

  Future<void> _analyzeRoomPhoto() async {
    if (_selectedRoomBytes == null) return;

    setState(() => _isAnalyzingRoom = true);
    HapticFeedback.mediumImpact();

    try {
      RoomAnalysisResult? result;
      if (_selectedRoomFile != null) {
        try {
          result = await RoomAnalysisService.instance.analyzeRoom(
            roomImage: _selectedRoomFile!,
            useSegmentation: true,
          );
        } catch (_) {
          result = RoomAnalysisService.instance.generateArchitecturalFallback();
        }
      } else {
        result = RoomAnalysisService.instance.generateArchitecturalFallback();
      }

      if (!mounted) return;
      setState(() {
        _roomAnalysis = result;
        _isAnalyzingRoom = false;
      });

      if (result.isUsable) {
        HapticFeedback.heavyImpact();
        showSuccessSnackbar(
          context,
          '${result.walls.length} architectural surface${result.walls.length > 1 ? 's' : ''} calibrated',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _roomAnalysis = RoomAnalysisService.instance.generateArchitecturalFallback();
        _isAnalyzingRoom = false;
      });
    }
  }

  // ─── CUSTOM DESIGN PICKING ───

  Future<void> _pickCustomDesign(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();

        if (!mounted) return;
        setState(() {
          _customDesignBytes = bytes;
          _customDesignUrl = null;
          _isCustomMode = true;
          _customDesignName = 'Custom Stone Sample';
        });
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      if (!mounted) return;
      showErrorSnackbar(
        context,
        e,
        customMessage: 'Could not load custom sample image.',
      );
    }
  }

  Future<void> _loadSampleCustomTexture(String label, String assetPath) async {
    try {
      final byteData = await rootBundle.load(assetPath);
      final bytes = byteData.buffer.asUint8List();
      if (!mounted) return;
      setState(() {
        _customDesignBytes = bytes;
        _customDesignUrl = null;
        _customDesignName = label;
        _isCustomMode = true;
      });
      HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('Sample texture load error: $e');
    }
  }

  // ─── IMAGE UPLOAD HELPER ───

  Future<String> _ensureRoomUploaded() async {
    if (_uploadedRoomUrl != null && _uploadedRoomUrl!.isNotEmpty) {
      return _uploadedRoomUrl!;
    }
    if (_selectedRoomBytes == null) {
      throw Exception('No room photo selected');
    }

    try {
      final client = SupabaseService.instance.clientOrNull;
      if (client != null) {
        final fileName = 'room_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await client.storage.from('ai-visualizations').uploadBinary(
              'input/$fileName',
              _selectedRoomBytes!,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                cacheControl: '3600',
              ),
            );
        final url = client.storage.from('ai-visualizations').getPublicUrl('input/$fileName');
        _uploadedRoomUrl = url;
        return url;
      }
    } catch (e) {
      debugPrint('Room upload storage warning: $e');
    }

    // Fallback data URL
    final base64String = base64Encode(_selectedRoomBytes!);
    final dataUrl = 'data:image/jpeg;base64,$base64String';
    _uploadedRoomUrl = dataUrl;
    return dataUrl;
  }

  Future<String?> _ensureCustomDesignUploaded() async {
    if (_customDesignBytes == null) return null;
    if (_customDesignUrl != null && _customDesignUrl!.isNotEmpty) {
      return _customDesignUrl;
    }

    try {
      final client = SupabaseService.instance.clientOrNull;
      if (client != null) {
        final fileName = 'custom_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await client.storage.from('ai-visualizations').uploadBinary(
              'custom/$fileName',
              _customDesignBytes!,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                cacheControl: '3600',
              ),
            );
        final url = client.storage.from('ai-visualizations').getPublicUrl('custom/$fileName');
        _customDesignUrl = url;
        return url;
      }
    } catch (e) {
      debugPrint('Custom design upload storage warning: $e');
    }

    final base64String = base64Encode(_customDesignBytes!);
    _customDesignUrl = 'data:image/jpeg;base64,$base64String';
    return _customDesignUrl;
  }

  // ─── START AI GENERATION ───

  Future<void> _startGeneration() async {
    if (_selectedRoomBytes == null) {
      showErrorSnackbar(context, null, customMessage: 'Please upload a photo of your room or wall');
      return;
    }

    if (!_isCustomMode && _selectedStoneId == null) {
      showErrorSnackbar(context, null, customMessage: 'Please select a natural stone or upload a custom design');
      return;
    }

    if (_isCustomMode && _customDesignBytes == null) {
      showErrorSnackbar(context, null, customMessage: 'Please upload your custom design or sample image');
      return;
    }

    setState(() => _isCreatingJob = true);
    HapticFeedback.mediumImpact();

    try {
      final inputRoomUrl = await _ensureRoomUploaded();
      String? customUrl;
      if (_isCustomMode) {
        customUrl = await _ensureCustomDesignUploaded();
      }

      final allStones = ref.read(allStonesProvider).valueOrNull ?? [];
      final stone = !_isCustomMode && _selectedStoneId != null
          ? allStones.where((s) => s.id == _selectedStoneId).firstOrNull
          : null;

      final stoneName = _isCustomMode
          ? _customDesignName
          : (stone?.name ?? 'Grazia Natural Stone');

      final createBatch = ref.read(createBatchProvider);
      final batchId = await createBatch(
        inputImageUrl: inputRoomUrl,
        stoneId: stone?.id,
        stoneName: stoneName,
        color: 'Classic Original',
        finish: _selectedFinish,
        metadata: {
          'is_custom_design': _isCustomMode,
          'custom_design_url': customUrl,
          'lighting_mood': _selectedLighting,
          'room_analysis': _roomAnalysis?.toJson(),
          'confidence': _roomAnalysis?.confidence,
        },
      );

      if (!mounted) return;
      setState(() {
        _activeBatchId = batchId;
        _isCreatingJob = false;
      });

      HapticFeedback.heavyImpact();
      showSuccessSnackbar(context, '✨ Synthesizing 4 Architectural Colorways...');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCreatingJob = false);
      showErrorSnackbar(
        context,
        e,
        customMessage: 'Failed to initiate AI generation. Please try again.',
      );
    }
  }

  // ─── BUILD SCREEN ───

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);
    final allStones = ref.watch(allStonesProvider).valueOrNull ?? [];
    final stones = allStones.take(12).toList();
    final selectedStone = _selectedStoneId != null
        ? stones.where((s) => s.id == _selectedStoneId).firstOrNull
        : null;

    final batchJobsAsync = _activeBatchId != null
        ? ref.watch(batchTrackingProvider(_activeBatchId!))
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
        title: Row(
          children: [
            Text(
              'AI Room Studio',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [palette.primary.withValues(alpha: 0.25), const Color(0xFFD4AF37).withValues(alpha: 0.25)],
                ),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: palette.primary.withValues(alpha: 0.5)),
              ),
              child: Text(
                'PRO 4K',
                style: GoogleFonts.inter(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: palette.primary,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.history_rounded, color: palette.textPrimary, size: 21),
            tooltip: 'Render History',
            onPressed: () => context.push('/ai-jobs'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Studio Header Feature Card
                _buildIntroBanner(palette),
                const SizedBox(height: 22),

                // ── STEP 1: ROOM PHOTO ──
                _buildSectionHeader('1. ROOM OR WALL PHOTOGRAPHY', palette),
                const SizedBox(height: 12),
                if (_selectedRoomBytes == null) ...[
                  _buildRoomUploadPickers(palette),
                  const SizedBox(height: 16),
                  _buildPresetRoomsStrip(palette),
                ] else
                  _buildRoomPreviewCard(palette),

                // Room Analysis Surface Badge
                if (_roomAnalysis != null && _selectedRoomBytes != null) ...[
                  const SizedBox(height: 14),
                  RoomAnalysisWidget(
                    analysis: _roomAnalysis!,
                    palette: palette,
                    onWallSelected: _roomAnalysis!.isUsable ? _startGeneration : null,
                    onRetry: () => _pickRoomImage(ImageSource.gallery),
                  ),
                ],

                const SizedBox(height: 26),

                // ── STEP 2: MATERIAL / STONE OR CUSTOM DESIGN ──
                _buildSectionHeader('2. SELECT STONE OR CUSTOM DESIGN', palette),
                const SizedBox(height: 12),
                _buildSurfaceModeTabs(palette),
                const SizedBox(height: 14),
                if (_isCustomMode)
                  _buildCustomDesignBox(palette)
                else
                  _buildCatalogStonesGrid(palette, stones),

                const SizedBox(height: 26),

                // ── STEP 3: FINISH & ARCHITECTURAL LIGHTING ──
                _buildSectionHeader('3. SURFACE FINISH & LIGHTING MOOD', palette),
                const SizedBox(height: 12),
                _buildFinishChips(palette),
                const SizedBox(height: 10),
                _buildLightingChips(palette),

                const SizedBox(height: 26),

                // ── STEP 4: AI GENERATION CTA BUTTON ──
                _buildGenerationButton(palette, selectedStone),

                // ── STEP 5: 4 COLORWAY RECOMMENDATIONS SECTION ──
                if (_activeBatchId != null) ...[
                  const SizedBox(height: 32),
                  _buildColorwayRecommendationsSection(palette, batchJobsAsync),
                ],

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── UI COMPONENTS ───

  Widget _buildIntroBanner(LuxuryPalette palette) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [palette.primary.withValues(alpha: 0.18), const Color(0xFFD4AF37).withValues(alpha: 0.18)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.primary.withValues(alpha: 0.3)),
            ),
            child: Icon(Icons.auto_awesome_rounded, color: palette.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Architectural AI Studio',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Upload any wall, floor or space. Choose Italian marble or upload your custom sample to generate 4 distinct architectural colorways.',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: palette.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
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
          height: 13,
          decoration: BoxDecoration(
            color: palette.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
            color: palette.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildRoomUploadPickers(LuxuryPalette palette) {
    return Row(
      children: [
        Expanded(
          child: _buildUploadCard(
            palette,
            'Take Photo',
            'Capture your wall or room',
            Icons.camera_alt_outlined,
            () => _pickRoomImage(ImageSource.camera),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildUploadCard(
            palette,
            'Upload Gallery',
            'Pick from your photos',
            Icons.photo_library_outlined,
            () => _pickRoomImage(ImageSource.gallery),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadCard(
    LuxuryPalette palette,
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ApplePressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 14),
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
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: palette.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: palette.primary.withValues(alpha: 0.3)),
              ),
              child: Icon(icon, color: palette.primary, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: palette.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetRoomsStrip(LuxuryPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SAMPLE ARCHITECTURAL ROOMS',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: palette.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 106,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              _buildPresetCard('Living Room Accent', 'assets/images/hero_banner_1.png', palette),
              const SizedBox(width: 10),
              _buildPresetCard('Luxury Bathroom', 'assets/images/hero_banner_2.png', palette),
              const SizedBox(width: 10),
              _buildPresetCard('Exterior Facade', 'assets/images/template_page-06.png', palette),
              const SizedBox(width: 10),
              _buildPresetCard('Villa Fireplace', 'assets/images/template_page-08.png', palette),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPresetCard(String title, String assetPath, LuxuryPalette palette) {
    return ApplePressable(
      onTap: () => _loadPresetRoom(assetPath),
      child: Container(
        width: 130,
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.border),
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
                      title,
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

  Widget _buildRoomPreviewCard(LuxuryPalette palette) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Stack(
          children: [
            Image.memory(
              _selectedRoomBytes!,
              height: 240,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
            if (_isAnalyzingRoom)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.55),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(strokeWidth: 2.5, color: palette.primary),
                        const SizedBox(height: 12),
                        Text(
                          'Detecting Room Surfaces...',
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
            Positioned(
              top: 10,
              right: 10,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _pickRoomImage(ImageSource.gallery),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.refresh_rounded, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'Change',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _selectedRoomBytes = null;
                        _selectedRoomFile = null;
                        _uploadedRoomUrl = null;
                        _roomAnalysis = null;
                        _activeBatchId = null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 15),
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

  // ─── STEP 2: MODE TABS (CATALOG VS CUSTOM) ───

  Widget _buildSurfaceModeTabs(LuxuryPalette palette) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _isCustomMode = false);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !_isCustomMode ? palette.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.account_balance_rounded,
                      size: 15,
                      color: !_isCustomMode ? Colors.white : palette.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Grazia Catalog',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: !_isCustomMode ? FontWeight.w700 : FontWeight.w500,
                        color: !_isCustomMode ? Colors.white : palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _isCustomMode = true);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _isCustomMode ? palette.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 15,
                      color: _isCustomMode ? Colors.white : palette.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '✨ Custom Design',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: _isCustomMode ? FontWeight.w700 : FontWeight.w500,
                        color: _isCustomMode ? Colors.white : palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── STEP 2A: CATALOG GRID ───

  Widget _buildCatalogStonesGrid(LuxuryPalette palette, List<Stone> stones) {
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
            setState(() {
              _selectedStoneId = stone.id;
              _isCustomMode = false;
            });
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
                        child: const Icon(Icons.check_rounded, size: 12, color: Colors.white),
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

  // ─── STEP 2B: CUSTOM DESIGN BOX ───

  Widget _buildCustomDesignBox(LuxuryPalette palette) {
    if (_customDesignBytes == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: palette.primary.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: palette.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add_photo_alternate_rounded, color: palette.primary, size: 26),
            ),
            const SizedBox(height: 12),
            Text(
              'Upload Custom Tile, Stone or Pattern',
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Photograph any stone slab, sample tile or architectural texture from your site to apply to your room walls.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: palette.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ApplePressable(
                    onTap: () => _pickCustomDesign(ImageSource.camera),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: palette.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 15),
                          const SizedBox(width: 6),
                          Text(
                            'Sample Camera',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ApplePressable(
                    onTap: () => _pickCustomDesign(ImageSource.gallery),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: palette.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.photo_library_outlined, color: palette.textPrimary, size: 15),
                          const SizedBox(width: 6),
                          Text(
                            'Pick Texture',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: palette.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Quick Sample Textures
            Row(
              children: [
                Text(
                  'OR TRY CUSTOM LUXURY TEXTURES:',
                  style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w700, color: palette.textTertiary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildCustomSampleChip('Athena Fluted', 'assets/images/athena_3d.png', palette),
                  const SizedBox(width: 8),
                  _buildCustomSampleChip('Grande Ledge', 'assets/images/grande_ledge_ta02.png', palette),
                  const SizedBox(width: 8),
                  _buildCustomSampleChip('Mountain Slate', 'assets/images/mountain_ledge_m08.png', palette),
                  const SizedBox(width: 8),
                  _buildCustomSampleChip('Verona Mosaic', 'assets/images/verona_3d.png', palette),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.primary, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: palette.primary.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              _customDesignBytes!,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: palette.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'CUSTOM TEXTURE ACTIVE',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: palette.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _customDesignName,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Will be rendered on wall with chosen finish',
                  style: GoogleFonts.inter(fontSize: 10.5, color: palette.textSecondary),
                ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                onPressed: () => _pickCustomDesign(ImageSource.gallery),
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Replace',
                color: palette.primary,
              ),
              IconButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _customDesignBytes = null;
                    _customDesignUrl = null;
                  });
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                tooltip: 'Remove',
                color: Colors.redAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomSampleChip(String label, String assetPath, LuxuryPalette palette) {
    return ApplePressable(
      onTap: () => _loadSampleCustomTexture(label, assetPath),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(assetPath, width: 20, height: 20, fit: BoxFit.cover),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: palette.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  // ─── STEP 3: FINISH & LIGHTING ───

  Widget _buildFinishChips(LuxuryPalette palette) {
    return SingleChildScrollView(
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
                fontSize: 11.5,
              ),
              onSelected: (_) {
                HapticFeedback.selectionClick();
                setState(() => _selectedFinish = f);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLightingChips(LuxuryPalette palette) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _lightings.map((l) {
          final isSel = _selectedLighting == l;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              avatar: Icon(
                Icons.light_mode_rounded,
                size: 14,
                color: isSel ? Colors.white : palette.primary,
              ),
              label: Text(l),
              selected: isSel,
              selectedColor: palette.primary,
              backgroundColor: palette.surface,
              labelStyle: GoogleFonts.inter(
                color: isSel ? Colors.white : palette.textPrimary,
                fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                fontSize: 11.5,
              ),
              onSelected: (_) {
                HapticFeedback.selectionClick();
                setState(() => _selectedLighting = l);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── STEP 4: GENERATION BUTTON ───

  Widget _buildGenerationButton(LuxuryPalette palette, Stone? selectedStone) {
    if (_isAnalyzingRoom) {
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
              style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: palette.textPrimary),
            ),
          ],
        ),
      );
    }

    final hasMaterial = _isCustomMode ? (_customDesignBytes != null) : (_selectedStoneId != null);
    final isReady = _selectedRoomBytes != null && hasMaterial;

    return ApplePressable(
      onTap: (_isCreatingJob || !isReady) ? null : _startGeneration,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: isReady
              ? LinearGradient(
                  colors: [palette.primary, const Color(0xFFD4AF37)],
                )
              : null,
          color: !isReady ? palette.surface : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isReady ? Colors.transparent : palette.border,
          ),
          boxShadow: isReady
              ? [
                  BoxShadow(
                    color: palette.primary.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isCreatingJob)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
              )
            else
              Icon(
                Icons.auto_awesome_rounded,
                color: isReady ? Colors.white : palette.textTertiary,
                size: 20,
              ),
            const SizedBox(width: 10),
            Text(
              _isCreatingJob
                  ? 'Synthesizing 4 Color Recommendations...'
                  : (isReady ? '✨ Generate 4K AI Recommendations' : 'Upload Room Photo & Material to Generate'),
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isReady ? Colors.white : palette.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── STEP 5: 4 COLORWAY RECOMMENDATIONS SECTION ───

  Widget _buildColorwayRecommendationsSection(
    LuxuryPalette palette,
    AsyncValue<List<AIJob>>? batchJobsAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 3,
                  height: 13,
                  decoration: BoxDecoration(
                    color: palette.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '4 COLORWAY RECOMMENDATIONS',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                    color: palette.textTertiary,
                  ),
                ),
              ],
            ),
            if (_activeBatchId != null)
              GestureDetector(
                onTap: () => context.push('/ai-viz/results/$_activeBatchId'),
                child: Row(
                  children: [
                    Text(
                      'View All in Gallery',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: palette.primary,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(Icons.arrow_forward_ios_rounded, size: 10, color: palette.primary),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Gemini AI has analyzed your room geometry and synthesized 4 architectural color palettes for your surface:',
          style: GoogleFonts.inter(fontSize: 11, color: palette.textSecondary),
        ),
        const SizedBox(height: 14),

        if (batchJobsAsync == null)
          const SizedBox.shrink()
        else
          batchJobsAsync.when(
            loading: () => _buildRecommendationsLoadingGrid(palette),
            error: (err, _) => _buildRecommendationsError(palette),
            data: (jobs) {
              if (jobs.isEmpty) {
                return _buildRecommendationsLoadingGrid(palette);
              }
              return _buildRecommendationsGrid(palette, jobs);
            },
          ),
      ],
    );
  }

  Widget _buildRecommendationsLoadingGrid(LuxuryPalette palette) {
    const titles = [
      'Classic Original',
      'Warm Champagne Gold',
      'Noir Charcoal Dramatic',
      'Cool Bianco Mist',
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: 4,
      itemBuilder: (context, i) {
        return Container(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: palette.primary),
              ),
              const SizedBox(height: 12),
              Text(
                titles[i],
                style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: palette.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Synthesizing render...',
                style: GoogleFonts.inter(fontSize: 10, color: palette.textSecondary),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecommendationsError(LuxuryPalette palette) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.refresh_rounded, color: palette.primary, size: 28),
            const SizedBox(height: 8),
            Text(
              'Rendering in background. Tap to refresh.',
              style: GoogleFonts.inter(fontSize: 12, color: palette.textSecondary),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.refresh(batchTrackingProvider(_activeBatchId!)),
              child: const Text('Refresh Recommendations'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsGrid(LuxuryPalette palette, List<AIJob> jobs) {
    final swatchColors = [
      const Color(0xFFE8DFD8), // Classic
      const Color(0xFFD4AF37), // Warm Gold
      const Color(0xFF2C2C2C), // Noir Charcoal
      const Color(0xFFF2F4F7), // Cool Bianco
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: 4,
      itemBuilder: (context, i) {
        final job = jobs.where((j) => j.variantIndex == i).firstOrNull;
        final colorName = job?.color ?? (i < AIJobRepository.recommendedColorways.length ? AIJobRepository.recommendedColorways[i]['title']! : 'Palette ${i + 1}');
        final swatch = swatchColors[i % swatchColors.length];

        return ApplePressable(
          onTap: job != null && job.isSuccessful ? () => _openInspector(job, jobs) : null,
          child: Container(
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: job != null && job.isSuccessful
                            ? Image.network(
                                job.resultImageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  color: Colors.grey.shade900,
                                  child: const Center(child: Icon(Icons.image, color: Colors.white38)),
                                ),
                              )
                            : Container(
                                color: palette.surfaceDark,
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: palette.primary),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Generating...',
                                        style: GoogleFonts.inter(fontSize: 10, color: palette.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: swatch,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.black26),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                colorName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: palette.textPrimary,
                                ),
                              ),
                            ),
                            Icon(Icons.zoom_in_rounded, size: 14, color: palette.textSecondary),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Variant ${i + 1}',
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
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
    );
  }

  // ─── FULLSCREEN INSPECTOR MODAL ───

  void _openInspector(AIJob job, List<AIJob> allJobs) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AIInspectionModal(
        job: job,
        allJobs: allJobs,
        originalRoomBytes: _selectedRoomBytes,
      ),
    );
  }
}

// ─── INSPECTION BOTTOM SHEET ───

class _AIInspectionModal extends StatefulWidget {
  final AIJob job;
  final List<AIJob> allJobs;
  final Uint8List? originalRoomBytes;

  const _AIInspectionModal({
    required this.job,
    required this.allJobs,
    this.originalRoomBytes,
  });

  @override
  State<_AIInspectionModal> createState() => _AIInspectionModalState();
}

class _AIInspectionModalState extends State<_AIInspectionModal> {
  late AIJob _currentJob;
  bool _showSplitCompare = false;

  @override
  void initState() {
    super.initState();
    _currentJob = widget.job;
  }

  Future<void> _share() async {
    HapticFeedback.lightImpact();
    try {
      await Share.share(
        'Grazia Stones AI Studio — ${_currentJob.stoneName} (${_currentJob.color ?? 'Natural'})\n${_currentJob.resultImageUrl}',
      );
    } catch (_) {}
  }

  Future<void> _openExternal() async {
    if (_currentJob.resultImageUrl == null) return;
    try {
      final uri = Uri.parse(_currentJob.resultImageUrl!);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Color(0xFF141414),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentJob.stoneName ?? 'AI Concept',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      Text(
                        '${_currentJob.color ?? 'Classic'} · Variant ${_currentJob.variantIndex + 1}',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                if (widget.originalRoomBytes != null)
                  IconButton(
                    icon: Icon(
                      _showSplitCompare ? Icons.view_sidebar_rounded : Icons.compare_rounded,
                      color: _showSplitCompare ? const Color(0xFFD4AF37) : Colors.white70,
                    ),
                    tooltip: 'Before / After Compare',
                    onPressed: () => setState(() => _showSplitCompare = !_showSplitCompare),
                  ),
                IconButton(
                  icon: const Icon(Icons.share_outlined, color: Colors.white),
                  onPressed: _share,
                ),
              ],
            ),
          ),

          // Variant Switcher Strip
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.allJobs.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final j = widget.allJobs[i];
                final isSelected = j.variantIndex == _currentJob.variantIndex;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _currentJob = j);
                  },
                  child: Container(
                    width: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFD4AF37) : Colors.white24,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: j.isSuccessful
                        ? Image.network(j.resultImageUrl!, fit: BoxFit.cover)
                        : Container(color: Colors.grey.shade900),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // Main Image Viewer
          Expanded(
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 4.0,
              child: Center(
                child: _currentJob.isSuccessful
                    ? Image.network(
                        _currentJob.resultImageUrl!,
                        fit: BoxFit.contain,
                      )
                    : const Text('Image unavailable', style: TextStyle(color: Colors.white54)),
              ),
            ),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: ApplePressable(
                    onTap: _openExternal,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.download_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Save HD',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ApplePressable(
                    onTap: () {
                      Navigator.of(context).pop();
                      final stoneId = _currentJob.stoneId;
                      context.push(stoneId != null ? '/quotes/new?stoneId=$stoneId' : '/quotes/new');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFB8860B), Color(0xFFD4AF37)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.request_quote_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Request Quote',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
