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

import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/models/ai_job.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/core/providers/stone_providers.dart';
import 'package:grazia_stones/core/services/room_analysis_service.dart';
import 'package:grazia_stones/core/widgets/animated_widgets.dart';
import 'package:grazia_stones/core/widgets/error_handler_widget.dart';
import 'package:grazia_stones/features/ai_viz/presentation/widgets/room_analysis_widget.dart';
import 'package:grazia_stones/features/ai_viz/providers/ai_job_provider.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/widgets/smart_stone_image.dart';

/// Luxury Apple-grade Architectural AI Studio Screen.
/// Enables room capture / preset selection, dual material mode (Grazia stones vs custom tile upload),
/// surface finish / lighting customization, and automated generation of 4 distinct architectural colorways.
class AIVizScreen extends ConsumerStatefulWidget {
  final String? preSelectedStoneId;

  const AIVizScreen({super.key, this.preSelectedStoneId});

  @override
  ConsumerState<AIVizScreen> createState() => _AIVizScreenState();
}

class _AIVizScreenState extends ConsumerState<AIVizScreen> {
  // ─── STEP 1: ROOM SELECTION ───
  Uint8List? _selectedRoomBytes;
  File? _selectedRoomFile;
  String? _uploadedRoomUrl;
  RoomAnalysisResult? _roomAnalysis;
  bool _isAnalyzingRoom = false;
  String _activePresetTitle = 'Modern Living Room Accent';

  final List<Map<String, String>> _sampleRooms = [
    {
      'title': 'Modern Living Room Accent',
      'subtitle': 'Feature TV Wall',
      'asset': 'assets/images/hero_banner_1.png',
      'tag': 'LIVING',
    },
    {
      'title': 'Luxury Spa Bathroom',
      'subtitle': 'Master Bath Shower Wall',
      'asset': 'assets/images/hero_banner_2.png',
      'tag': 'BATHROOM',
    },
    {
      'title': 'Contemporary Kitchen',
      'subtitle': 'Island & Backsplash Wall',
      'asset': 'assets/images/template_page-06.png',
      'tag': 'KITCHEN',
    },
    {
      'title': 'Grand Villa Fireplace',
      'subtitle': 'Double-Height Chimney Breast',
      'asset': 'assets/images/template_page-08.png',
      'tag': 'FIREPLACE',
    },
  ];

  // ─── STEP 2: MATERIAL SELECTION (CATALOG VS CUSTOM) ───
  bool _isCustomMode = false;
  String? _selectedStoneId;
  Uint8List? _customDesignBytes;
  String _customDesignName = 'Athena Fluted 3D Sample';

  final List<Map<String, String>> _customPresets = [
    {
      'name': 'Athena Fluted 3D',
      'asset': 'assets/images/athena_3d.png',
      'desc': 'Linear architectural grooves',
    },
    {
      'name': 'Grande Ledge TA02',
      'asset': 'assets/images/grande_ledge_ta02.png',
      'desc': 'Rustic dry-stacked slate',
    },
    {
      'name': 'Mountain Ledge M08',
      'asset': 'assets/images/mountain_ledge_m08.png',
      'desc': 'Earthy textural quarry stone',
    },
    {
      'name': 'Verona 3D Mosaic',
      'asset': 'assets/images/verona_3d.png',
      'desc': 'Geometric multi-depth pattern',
    },
  ];

  // ─── STEP 3: FINISH & LIGHTING ───
  String _selectedFinish = 'Polished';
  String _selectedLighting = 'Daylight Natural';

  final List<Map<String, dynamic>> _finishOptions = [
    {'name': 'Polished', 'icon': Icons.auto_awesome_rounded, 'tag': 'High Gloss'},
    {'name': 'Honed', 'icon': Icons.crop_square_rounded, 'tag': 'Smooth Matte'},
    {'name': 'Leathered', 'icon': Icons.texture_rounded, 'tag': 'Textured Tactile'},
    {'name': 'Fluted', 'icon': Icons.view_week_rounded, 'tag': '3D Grooves'},
    {'name': 'Natural', 'icon': Icons.landscape_rounded, 'tag': 'Raw Split'},
  ];

  final List<Map<String, dynamic>> _lightingOptions = [
    {'name': 'Daylight Natural', 'icon': Icons.wb_sunny_rounded, 'tag': '5500K Ambient'},
    {'name': 'Warm Evening', 'icon': Icons.nights_stay_rounded, 'tag': '2700K Golden'},
    {'name': 'Dramatic Accent', 'icon': Icons.highlight_rounded, 'tag': 'Directional Spot'},
    {'name': 'Clean Showroom', 'icon': Icons.lightbulb_rounded, 'tag': '4000K Studio'},
  ];

  // ─── STEP 4 & 5: GENERATION & JOBS ───
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
        debugPrint('RoomAnalysisService init: $e');
      }

      // Auto-load 1st preset room so user has instant interactive experience
      _loadPresetRoom('assets/images/hero_banner_1.png', 'Modern Living Room Accent');

      // Auto-load 1st custom texture default
      _loadSampleCustomTexture('Athena Fluted 3D', 'assets/images/athena_3d.png');
    });
  }

  // ─── ROOM SELECTION LOGIC ───

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
          _activePresetTitle = source == ImageSource.camera ? 'Live Camera Capture' : 'Gallery Upload';
        });
        HapticFeedback.mediumImpact();

        await _analyzeRoomPhoto();
      }
    } catch (e) {
      if (!mounted) return;
      showErrorSnackbar(
        context,
        e,
        customMessage: 'Unable to load image. Please select another.',
      );
    }
  }

  Future<void> _loadPresetRoom(String assetPath, String title) async {
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
        _activePresetTitle = title;
      });
      HapticFeedback.selectionClick();

      await _analyzeRoomPhoto();
    } catch (e) {
      debugPrint('Preset load error: $e');
    }
  }

  Future<void> _analyzeRoomPhoto() async {
    if (_selectedRoomBytes == null) return;

    setState(() => _isAnalyzingRoom = true);

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
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _roomAnalysis = RoomAnalysisService.instance.generateArchitecturalFallback();
        _isAnalyzingRoom = false;
      });
    }
  }

  // ─── CUSTOM TEXTURE PICKING ───

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
          _customDesignName = source == ImageSource.camera ? 'Camera Tile Photo' : 'Gallery Stone Sample';
          _isCustomMode = true;
          _activeBatchId = null;
        });
        HapticFeedback.mediumImpact();
        showSuccessSnackbar(context, 'Custom tile texture loaded. Ready to apply.');
      }
    } catch (e) {
      if (!mounted) return;
      showErrorSnackbar(context, e, customMessage: 'Could not load custom sample.');
    }
  }

  Future<void> _loadSampleCustomTexture(String name, String assetPath) async {
    try {
      final byteData = await rootBundle.load(assetPath);
      final bytes = byteData.buffer.asUint8List();
      if (!mounted) return;
      setState(() {
        _customDesignBytes = bytes;
        _customDesignName = name;
        _isCustomMode = true;
        _activeBatchId = null;
      });
      HapticFeedback.selectionClick();
    } catch (e) {
      debugPrint('Sample texture load error: $e');
    }
  }

  // ─── GENERATION PIPELINE ───

  Future<void> _startGeneration() async {
    if (_isCreatingJob) return;

    if (_selectedRoomBytes == null) {
      showErrorSnackbar(context, null, customMessage: 'Please select or upload a room wall photo first.');
      return;
    }

    final stones = ref.read(allStonesProvider).valueOrNull ?? [];
    Stone? selectedStone;
    if (!_isCustomMode) {
      final stoneId = _selectedStoneId ?? (stones.isNotEmpty ? stones.first.id : null);
      if (stoneId != null) {
        selectedStone = stones.firstWhere(
          (s) => s.id == stoneId,
          orElse: () => stones.first,
        );
      }
      if (selectedStone == null) {
        showErrorSnackbar(context, null, customMessage: 'Please pick a stone or switch to Custom Design.');
        return;
      }
    } else {
      if (_customDesignBytes == null) {
        showErrorSnackbar(context, null, customMessage: 'Please upload or select a custom stone texture.');
        return;
      }
    }

    setState(() => _isCreatingJob = true);
    HapticFeedback.heavyImpact();

    try {
      // 1. Prepare room photo
      String inputImageUrl = _uploadedRoomUrl ?? '';
      if (inputImageUrl.isEmpty) {
        inputImageUrl = 'data:image/jpeg;base64,${base64Encode(_selectedRoomBytes!)}';
        _uploadedRoomUrl = inputImageUrl;
      }

      // 2. Prepare stone / custom texture data
      String effectiveStoneId;
      String effectiveStoneName;
      String? customPatternUrl;

      if (_isCustomMode) {
        effectiveStoneId = 'custom-${DateTime.now().millisecondsSinceEpoch}';
        effectiveStoneName = _customDesignName;
        customPatternUrl = 'data:image/png;base64,${base64Encode(_customDesignBytes!)}';
      } else {
        effectiveStoneId = selectedStone!.id;
        effectiveStoneName = selectedStone.name;
        customPatternUrl = selectedStone.imageUrl;
      }

      // 3. Dispatch batch of 4 architectural colorways
      final repo = ref.read(aiJobRepositoryProvider);
      final jobs = await repo.createVisualizationBatch(
        inputImageUrl: inputImageUrl,
        stoneId: effectiveStoneId,
        stoneName: effectiveStoneName,
        finish: _selectedFinish,
        metadata: {
          'surface_type': 'wall',
          'lighting': _selectedLighting,
          'custom_pattern_url': ?customPatternUrl,
        },
      );

      final batchId = jobs.isNotEmpty
          ? (jobs.first.metadata?['batch_id'] as String? ?? jobs.first.id)
          : DateTime.now().millisecondsSinceEpoch.toString();

      if (!mounted) return;
      setState(() {
        _activeBatchId = batchId;
        _isCreatingJob = false;
      });

      HapticFeedback.lightImpact();
      showSuccessSnackbar(
        context,
        '✨ 4 Architectural Colorways generated below!',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCreatingJob = false);
      showErrorSnackbar(
        context,
        e,
        customMessage: 'Generation notice: using high-precision fallback colorways.',
      );
    }
  }

  // ─── BUILD SCREEN ───

  @override
  Widget build(BuildContext context) {
    final palette = GLuxuryPalettes.gold;
    final stonesAsync = ref.watch(allStonesProvider);
    final stones = stonesAsync.valueOrNull ?? [];

    if (_selectedStoneId == null && stones.isNotEmpty) {
      _selectedStoneId = stones.first.id;
    }

    final selectedStone = stones.where((s) => s.id == _selectedStoneId).firstOrNull ??
        (stones.isNotEmpty ? stones.first : null);

    final batchJobsAsync = _activeBatchId != null ? ref.watch(batchTrackingProvider(_activeBatchId!)) : null;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: palette.textPrimary, size: 19),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/tools');
            }
          },
        ),
        title: Row(
          children: [
            Text(
              'AI Room Studio',
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
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
          constraints: const BoxConstraints(maxWidth: 740),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step-by-Step Luxury Banner
                _buildHeroStepHeader(palette),
                const SizedBox(height: 22),

                // ── STEP 1: ROOM SELECTION ──
                _buildSectionHeader('1. ROOM OR WALL PHOTOGRAPHY', 'Choose your space or capture live', palette),
                const SizedBox(height: 12),
                _buildRoomSection(palette),

                // Surface detection feedback
                if (_roomAnalysis != null && _selectedRoomBytes != null) ...[
                  const SizedBox(height: 12),
                  RoomAnalysisWidget(
                    analysis: _roomAnalysis!,
                    palette: palette,
                    onWallSelected: _roomAnalysis!.isUsable ? _startGeneration : null,
                    onRetry: () => _pickRoomImage(ImageSource.gallery),
                  ),
                ],

                const SizedBox(height: 24),

                // ── STEP 2: STONE OR CUSTOM DESIGN ──
                _buildSectionHeader('2. SELECT STONE OR CUSTOM DESIGN', 'Browse Grazia catalog or upload your sample', palette),
                const SizedBox(height: 12),
                _buildSurfaceModeTabs(palette),
                const SizedBox(height: 14),
                if (_isCustomMode)
                  _buildCustomDesignBox(palette)
                else
                  _buildCatalogStonesGrid(palette, stones),

                const SizedBox(height: 24),

                // ── STEP 3: FINISH & LIGHTING ──
                _buildSectionHeader('3. SURFACE FINISH & LIGHTING MOOD', 'Fine-tune architectural ambience', palette),
                const SizedBox(height: 12),
                _buildFinishChips(palette),
                const SizedBox(height: 12),
                _buildLightingChips(palette),

                const SizedBox(height: 26),

                // ── STEP 4: COLORWAY PREVIEW & GENERATE CTA ──
                _buildColorwayTeaserBanner(palette),
                const SizedBox(height: 14),
                _buildGenerationButton(palette, selectedStone),

                // ── STEP 5: 4 COLORWAY RECOMMENDATIONS ──
                if (_activeBatchId != null) ...[
                  const SizedBox(height: 32),
                  _buildColorwayRecommendationsSection(palette, batchJobsAsync),
                ],

                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── UI COMPONENTS ───

  Widget _buildHeroStepHeader(LuxuryPalette palette) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [palette.primary.withValues(alpha: 0.2), const Color(0xFFD4AF37).withValues(alpha: 0.2)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.primary.withValues(alpha: 0.4)),
                ),
                child: Icon(Icons.auto_awesome_rounded, color: palette.primary, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Architectural AI Studio',
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Generate 4 distinct architectural colorways on your wall in 1 tap.',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: palette.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: palette.border.withValues(alpha: 0.6)),
            ),
            child: Row(
              children: [
                _buildStepBadge('1', 'Space', _selectedRoomBytes != null, palette),
                _buildStepDivider(palette),
                _buildStepBadge('2', 'Material', _isCustomMode ? _customDesignBytes != null : _selectedStoneId != null, palette),
                _buildStepDivider(palette),
                _buildStepBadge('3', '4 Colorways', _activeBatchId != null, palette),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepBadge(String number, String label, bool isCompleted, LuxuryPalette palette) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: isCompleted ? palette.primary : palette.border,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                  : Text(
                      number,
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: palette.textSecondary),
                    ),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: isCompleted ? FontWeight.w700 : FontWeight.w500,
              color: isCompleted ? palette.textPrimary : palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepDivider(LuxuryPalette palette) {
    return Container(
      width: 12,
      height: 1,
      color: palette.border,
    );
  }

  Widget _buildSectionHeader(String title, String subtitle, LuxuryPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
              title,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: palette.textTertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(left: 11),
          child: Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: palette.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  // ─── STEP 1: ROOM PREVIEW & PRESET CAROUSEL ───

  Widget _buildRoomSection(LuxuryPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Active Preview or Upload Cards
        if (_selectedRoomBytes != null)
          _buildRoomPreviewCard(palette)
        else
          _buildRoomUploadPickers(palette),

        const SizedBox(height: 14),

        // Quick Preset Rooms (Always Accessible)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'OR TAP A CURATED ARCHITECTURAL PRESET:',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: palette.textTertiary,
              ),
            ),
            if (_selectedRoomBytes != null)
              GestureDetector(
                onTap: () => _pickRoomImage(ImageSource.gallery),
                child: Row(
                  children: [
                    Icon(Icons.add_photo_alternate_rounded, size: 13, color: palette.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Upload Mine',
                      style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: palette.primary),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _sampleRooms.length,
            separatorBuilder: (ctx, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final room = _sampleRooms[index];
              final isSelected = _activePresetTitle == room['title'];
              return _buildPresetRoomTile(room, isSelected, palette);
            },
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
            'Live room wall capture',
            Icons.camera_alt_outlined,
            () => _pickRoomImage(ImageSource.camera),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildUploadCard(
            palette,
            'Upload Gallery',
            'Pick from room photos',
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
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
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
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: palette.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: palette.primary.withValues(alpha: 0.3)),
              ),
              child: Icon(icon, color: palette.primary, size: 21),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
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

  Widget _buildPresetRoomTile(Map<String, String> room, bool isSelected, LuxuryPalette palette) {
    return ApplePressable(
      onTap: () => _loadPresetRoom(room['asset']!, room['title']!),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 140,
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? palette.primary : palette.border,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: palette.primary.withValues(alpha: 0.25),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 64,
                    width: double.infinity,
                    child: Image.asset(room['asset']!, fit: BoxFit.cover),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room['title']!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? palette.primary : palette.textPrimary,
                          ),
                        ),
                        Text(
                          room['subtitle']!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 9, color: palette.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (isSelected)
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      color: palette.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded, size: 10, color: Colors.white),
                  ),
                ),
            ],
          ),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Stack(
          children: [
            Image.memory(
              _selectedRoomBytes!,
              height: 230,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
            if (_isAnalyzingRoom)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.6),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(strokeWidth: 2.5, color: palette.primary),
                        const SizedBox(height: 12),
                        Text(
                          'Detecting Room Surfaces & Lighting...',
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
            // Bottom Info Bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: palette.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'ACTIVE SPACE',
                        style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _activePresetTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Top Action Controls
            Positioned(
              top: 10,
              right: 10,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _pickRoomImage(ImageSource.camera),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 13),
                          const SizedBox(width: 4),
                          Text(
                            'Camera',
                            style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _pickRoomImage(ImageSource.gallery),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.photo_library_outlined, color: Colors.white, size: 13),
                          const SizedBox(width: 4),
                          Text(
                            'Gallery',
                            style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ],
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
                  gradient: !_isCustomMode
                      ? LinearGradient(
                          colors: [palette.primary, const Color(0xFFD4AF37)],
                        )
                      : null,
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
                      'Grazia Catalog Stones',
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
                  gradient: _isCustomMode
                      ? LinearGradient(
                          colors: [palette.primary, const Color(0xFFD4AF37)],
                        )
                      : null,
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
                      '✨ Custom Design Upload',
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.primary.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: palette.primary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // If active texture preview exists
          if (_customDesignBytes != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: palette.primary, width: 1.5),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      _customDesignBytes!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: palette.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'READY TO APPLY',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: palette.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _customDesignName,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: palette.textPrimary,
                          ),
                        ),
                        Text(
                          'Will be realistically projected onto wall',
                          style: GoogleFonts.inter(fontSize: 10, color: palette.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _pickCustomDesign(ImageSource.gallery),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    tooltip: 'Replace',
                    color: palette.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Action Buttons: Capture vs Gallery
          Row(
            children: [
              Expanded(
                child: ApplePressable(
                  onTap: () => _pickCustomDesign(ImageSource.camera),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
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
                          'Capture Tile Photo',
                          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
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
                    padding: const EdgeInsets.symmetric(vertical: 11),
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
                          'Upload Sample',
                          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: palette.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Quick Preset Custom Textures
          Text(
            'OR PICK A TEXTURAL SAMPLE:',
            style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w700, color: palette.textTertiary),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _customPresets.map((preset) {
                final isSelected = _customDesignName == preset['name'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ApplePressable(
                    onTap: () => _loadSampleCustomTexture(preset['name']!, preset['asset']!),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? palette.primary.withValues(alpha: 0.12) : palette.background,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? palette.primary : palette.border,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.asset(preset['asset']!, width: 22, height: 22, fit: BoxFit.cover),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            preset['name']!,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                              color: isSelected ? palette.primary : palette.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ─── STEP 3: FINISH & LIGHTING CHIPS ───

  Widget _buildFinishChips(LuxuryPalette palette) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _finishOptions.map((f) {
          final isSelected = _selectedFinish == f['name'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ApplePressable(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedFinish = f['name']);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? palette.primary : palette.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isSelected ? palette.primary : palette.border,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: palette.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  children: [
                    Icon(
                      f['icon'] as IconData,
                      size: 14,
                      color: isSelected ? Colors.white : palette.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      f['name'],
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : palette.textPrimary,
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

  Widget _buildLightingChips(LuxuryPalette palette) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _lightingOptions.map((l) {
          final isSelected = _selectedLighting == l['name'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ApplePressable(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedLighting = l['name']);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? palette.primary : palette.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isSelected ? palette.primary : palette.border,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: palette.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  children: [
                    Icon(
                      l['icon'] as IconData,
                      size: 14,
                      color: isSelected ? Colors.white : palette.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l['name'],
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : palette.textPrimary,
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

  // ─── STEP 4: COLORWAY TEASER & GENERATION CTA ───

  Widget _buildColorwayTeaserBanner(LuxuryPalette palette) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Icon(Icons.palette_outlined, size: 18, color: palette.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Includes 4 Distinct Architectural Colorways',
                  style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: palette.textPrimary),
                ),
                Text(
                  'Classic Original • Warm Champagne Gold • Noir Charcoal • Cool Bianco Mist',
                  style: GoogleFonts.inter(fontSize: 10, color: palette.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerationButton(LuxuryPalette palette, Stone? selectedStone) {
    final hasRoom = _selectedRoomBytes != null;
    final hasMaterial = _isCustomMode ? _customDesignBytes != null : selectedStone != null;
    final isReady = hasRoom && hasMaterial;

    return ApplePressable(
      onTap: _isCreatingJob ? null : _startGeneration,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isReady
                ? [palette.primary, const Color(0xFFD4AF37), const Color(0xFFE5C158)]
                : [palette.surface, palette.surface],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isReady ? palette.primary : palette.border,
            width: isReady ? 1.5 : 1.0,
          ),
          boxShadow: isReady
              ? [
                  BoxShadow(
                    color: palette.primary.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: _isCreatingJob
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Generating 4 Colorway Variations...',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 19,
                    color: isReady ? Colors.white : palette.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isReady
                        ? 'Generate 4 Architectural Colorways'
                        : (!hasRoom ? 'Select Room Wall Photo Above' : 'Select Stone or Custom Tile Above'),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isReady ? Colors.white : palette.textSecondary,
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
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: palette.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.palette_rounded, color: palette.primary, size: 16),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RECOMMENDED 4 COLORWAYS',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    color: palette.textTertiary,
                  ),
                ),
                Text(
                  'Tap any colorway for interactive before/after comparison',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (batchJobsAsync == null)
          _buildRecommendationsLoadingGrid(palette)
        else
          batchJobsAsync.when(
            data: (jobs) => _buildRecommendationsGrid(palette, jobs),
            loading: () => _buildRecommendationsLoadingGrid(palette),
            error: (err, stack) => _buildRecommendationsError(palette),
          ),
      ],
    );
  }

  Widget _buildRecommendationsLoadingGrid(LuxuryPalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(strokeWidth: 2.5, color: palette.primary),
            const SizedBox(height: 18),
            Text(
              'Rendering 4 Color Variations...',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: palette.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Applying perspective geometry, seams, and lighting reflections.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 11, color: palette.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsError(LuxuryPalette palette) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.info_outline_rounded, color: palette.primary, size: 28),
            const SizedBox(height: 10),
            Text(
              'Renders in Queue',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: palette.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'Your jobs are processing. Check Render History anytime.',
              style: GoogleFonts.inter(fontSize: 11, color: palette.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsGrid(LuxuryPalette palette, List<AIJob> jobs) {
    final List<Map<String, dynamic>> colorwayConfigs = [
      {
        'title': 'Classic Natural Original',
        'subtitle': 'Authentic Quarry Veining',
        'swatch': const Color(0xFFC8A53C),
        'tag': 'ORIGINAL',
      },
      {
        'title': 'Warm Champagne Gold',
        'subtitle': 'Amber & Golden Undertones',
        'swatch': const Color(0xFFD4AF37),
        'tag': 'WARM LUXURY',
      },
      {
        'title': 'Noir Charcoal Dramatic',
        'subtitle': 'Moody Depth with Sharp Contrast',
        'swatch': const Color(0xFF222222),
        'tag': 'DRAMATIC',
      },
      {
        'title': 'Cool Bianco Mist',
        'subtitle': 'Alabaster White & Grey Marble',
        'swatch': const Color(0xFFE8ECEF),
        'tag': 'MINIMAL',
      },
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
      itemBuilder: (context, index) {
        final job = index < jobs.length ? jobs[index] : null;
        final config = colorwayConfigs[index];
        final isReady = job != null && job.isSuccessful && job.resultImageUrl != null;
        final imageUrl = isReady ? job.resultImageUrl! : null;

        return ApplePressable(
          onTap: () {
            if (imageUrl != null) {
              _openComparisonModal(
                palette,
                colorwayTitle: config['title'] as String,
                resultImageUrl: imageUrl,
              );
            }
          },
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Render Image or Placeholder
                      Expanded(
                        child: imageUrl != null
                            ? Image.network(
                                imageUrl,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => _buildFallbackColorwayPreview(config, palette),
                              )
                            : _buildFallbackColorwayPreview(config, palette),
                      ),
                      // Meta details
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: config['swatch'] as Color,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 1),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    config['title'] as String,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: palette.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              config['subtitle'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                color: palette.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Tag pill
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        config['tag'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  // Compare Tap Hint
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: palette.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.compare_arrows_rounded, size: 12, color: Colors.white),
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

  Widget _buildFallbackColorwayPreview(Map<String, dynamic> config, LuxuryPalette palette) {
    return Container(
      color: (config['swatch'] as Color).withValues(alpha: 0.15),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: (config['swatch'] as Color).withValues(alpha: 0.3),
                shape: BoxShape.circle,
                border: Border.all(color: (config['swatch'] as Color), width: 1.5),
              ),
              child: Icon(Icons.auto_awesome_rounded, color: config['swatch'] as Color, size: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Color Palette Active',
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: palette.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  // ─── INTERACTIVE BEFORE / AFTER COMPARISON MODAL ───

  void _openComparisonModal(
    LuxuryPalette palette, {
    required String colorwayTitle,
    required String resultImageUrl,
  }) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _InteractiveCompareSheet(
          palette: palette,
          colorwayTitle: colorwayTitle,
          originalBytes: _selectedRoomBytes!,
          resultImageUrl: resultImageUrl,
          finish: _selectedFinish,
          stoneName: _isCustomMode ? _customDesignName : 'Grazia Stone',
        );
      },
    );
  }
}

/// Interactive Fullscreen Before/After Slider Sheet
class _InteractiveCompareSheet extends StatefulWidget {
  final LuxuryPalette palette;
  final String colorwayTitle;
  final Uint8List originalBytes;
  final String resultImageUrl;
  final String finish;
  final String stoneName;

  const _InteractiveCompareSheet({
    required this.palette,
    required this.colorwayTitle,
    required this.originalBytes,
    required this.resultImageUrl,
    required this.finish,
    required this.stoneName,
  });

  @override
  State<_InteractiveCompareSheet> createState() => _InteractiveCompareSheetState();
}

class _InteractiveCompareSheetState extends State<_InteractiveCompareSheet> {
  double _sliderPosition = 0.5;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.88,
      decoration: BoxDecoration(
        color: widget.palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: widget.palette.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Top Title Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.colorwayTitle,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: widget.palette.textPrimary,
                        ),
                      ),
                      Text(
                        '${widget.stoneName} • ${widget.finish} Finish',
                        style: GoogleFonts.inter(fontSize: 11, color: widget.palette.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
          ),
          // Interactive Split View Slider
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;

                return GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _sliderPosition = (details.localPosition.dx / width).clamp(0.05, 0.95);
                    });
                  },
                  child: Stack(
                    children: [
                      // Underneath: Original Room Photo
                      Positioned.fill(
                        child: Image.memory(
                          widget.originalBytes,
                          fit: BoxFit.cover,
                        ),
                      ),
                      // Over: AI Rendered Stone Wall (Clipped by slider)
                      Positioned.fill(
                        child: ClipRect(
                          clipper: _HorizontalSplitClipper(_sliderPosition),
                          child: Image.network(
                            widget.resultImageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => const Center(child: Icon(Icons.broken_image_rounded)),
                          ),
                        ),
                      ),
                      // Divider Line
                      Positioned(
                        left: width * _sliderPosition - 1.5,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 3,
                          color: Colors.white,
                        ),
                      ),
                      // Divider Circular Grip
                      Positioned(
                        left: width * _sliderPosition - 18,
                        top: height / 2 - 18,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: widget.palette.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.code_rounded, size: 16, color: Colors.white),
                        ),
                      ),
                      // Left & Right Badges
                      Positioned(
                        top: 14,
                        left: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'ORIGINAL',
                            style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 14,
                        right: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: widget.palette.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'GRAZIA AI',
                            style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Action Buttons: Save, Share, Request Quote
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      HapticFeedback.selectionClick();
                      try {
                        await Share.shareUri(Uri.parse(widget.resultImageUrl));
                      } catch (_) {
                        Share.share(
                          'Check out my architectural stone visualization on Grazia Stones: ${widget.resultImageUrl}',
                        );
                      }
                    },
                    icon: const Icon(Icons.share_outlined, size: 16),
                    label: const Text('Share'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: widget.palette.textPrimary,
                      side: BorderSide(color: widget.palette.border),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/quote-request?stone=${Uri.encodeComponent(widget.stoneName)}');
                    },
                    icon: const Icon(Icons.request_quote_rounded, size: 16, color: Colors.white),
                    label: const Text('Get Quote', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.palette.primary,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

class _HorizontalSplitClipper extends CustomClipper<Rect> {
  final double fraction;

  _HorizontalSplitClipper(this.fraction);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(size.width * fraction, 0, size.width * (1.0 - fraction), size.height);
  }

  @override
  bool shouldReclip(_HorizontalSplitClipper oldClipper) => oldClipper.fraction != fraction;
}
