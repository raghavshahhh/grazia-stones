import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:image/image.dart' as img;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/core/services/ai_endpoint_client.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/core/providers/stone_providers.dart' show allStonesProvider;

/// Architectural Color & Finish Variant Model
class StudioColorVariant {
  final String id;
  final String name;
  final String finishName;
  final Color swatchColor;
  final Color tintColor;
  final BlendMode blendMode;
  final List<String> matchingCollections;

  const StudioColorVariant({
    required this.id,
    required this.name,
    required this.finishName,
    required this.swatchColor,
    required this.tintColor,
    this.blendMode = BlendMode.color,
    required this.matchingCollections,
  });
}

const List<StudioColorVariant> _studioColorVariants = [
  StudioColorVariant(
    id: 'classic',
    name: 'Classic Natural',
    finishName: 'Honed Quarry',
    swatchColor: Color(0xFFC8A96E),
    tintColor: Color(0xFFD4B97A),
    blendMode: BlendMode.modulate,
    matchingCollections: ['Travertine Series', 'Mountain Ledge', 'Classic Ledge'],
  ),
  StudioColorVariant(
    id: 'noir',
    name: 'Charcoal Noir',
    finishName: 'Textured Midnight',
    swatchColor: Color(0xFF222226),
    tintColor: Color(0xFF1E1E22),
    blendMode: BlendMode.multiply,
    matchingCollections: ['Obsidian Stack', 'Rockface Noir', 'Tevoli Series'],
  ),
  StudioColorVariant(
    id: 'bianco',
    name: 'Bianco Carrara',
    finishName: 'Silken Satin',
    swatchColor: Color(0xFFE8E8ED),
    tintColor: Color(0xFFE2E2E8),
    blendMode: BlendMode.screen,
    matchingCollections: ['Cuarzo Series', 'Alpine Series', 'Milano Series'],
  ),
  StudioColorVariant(
    id: 'sand',
    name: 'Desert Sand',
    finishName: 'Matte Earth',
    swatchColor: Color(0xFFC4A482),
    tintColor: Color(0xFFC9A887),
    blendMode: BlendMode.softLight,
    matchingCollections: ['Travertine Dune', 'Cave Series', 'Egyptian Series'],
  ),
  StudioColorVariant(
    id: 'terracotta',
    name: 'Tuscan Rust',
    finishName: 'Rustic Kiln',
    swatchColor: Color(0xFFA65038),
    tintColor: Color(0xFF9E4B34),
    blendMode: BlendMode.overlay,
    matchingCollections: ['Lakhori Brick', 'Colonial Brick', 'Rustic Brick'],
  ),
  StudioColorVariant(
    id: 'grigio',
    name: 'Grigio Ash',
    finishName: 'Linear Fluted',
    swatchColor: Color(0xFF6B6F76),
    tintColor: Color(0xFF5E636A),
    blendMode: BlendMode.color,
    matchingCollections: ['Modena Series', 'Venetian Series', 'Andorra Series'],
  ),
];

class _SamplePreset {
  final String title;
  final String subtitle;
  final String assetPath;

  const _SamplePreset({
    required this.title,
    required this.subtitle,
    required this.assetPath,
  });
}

const List<_SamplePreset> _sampleRooms = [
  _SamplePreset(
    title: 'Living Room',
    subtitle: 'Feature entertainment wall',
    assetPath: 'assets/images/home_hero_living_room.jpg',
  ),
  _SamplePreset(
    title: 'Master Bedroom',
    subtitle: 'Headboard accent wall',
    assetPath: 'assets/images/hero_luxury_bedroom.jpg',
  ),
  _SamplePreset(
    title: 'Grand Fireplace',
    subtitle: 'Vertical hearth cladding',
    assetPath: 'assets/images/hero_luxury_fireplace.jpg',
  ),
  _SamplePreset(
    title: 'Dining Suite',
    subtitle: 'Fluted architectural wall',
    assetPath: 'assets/images/hero_luxury_dining_fluted.jpg',
  ),
  _SamplePreset(
    title: 'Luxury Villa Salon',
    subtitle: 'High-ceiling grand salon',
    assetPath: 'assets/images/onboarding_hero_room.jpg',
  ),
];

const List<_SamplePreset> _sampleStones = [
  _SamplePreset(
    title: 'Mountain Ledge',
    subtitle: 'Warm rugged interlocking stack',
    assetPath: 'assets/images/mountain_ledge_m08_tex.png',
  ),
  _SamplePreset(
    title: 'Grande Ledge',
    subtitle: 'Monumental scale format',
    assetPath: 'assets/images/grande_ledge_ta02_tex.png',
  ),
  _SamplePreset(
    title: 'Classic Ledge',
    subtitle: 'Authentic quarry masonry',
    assetPath: 'assets/images/classic_ledge_07_tex.png',
  ),
  _SamplePreset(
    title: 'Opus Ledge',
    subtitle: 'Deep relief linear shadow',
    assetPath: 'assets/images/opus_ledge_15_tex.png',
  ),
  _SamplePreset(
    title: 'Athena 3D',
    subtitle: 'Sculpted acoustic luxury',
    assetPath: 'assets/images/athena_3d_tex.png',
  ),
  _SamplePreset(
    title: 'Vantage V12',
    subtitle: 'Modern linear ashlar stone',
    assetPath: 'assets/images/vantage_v12_tex.png',
  ),
  _SamplePreset(
    title: 'Verona 3D',
    subtitle: 'Architectural ribbed masonry',
    assetPath: 'assets/images/verona_3d_tex.png',
  ),
];

/// Ultra-Premium AI Room Studio Screen
class SimpleAIStudioScreen extends ConsumerStatefulWidget {
  final String? preSelectedStoneId;

  const SimpleAIStudioScreen({super.key, this.preSelectedStoneId});

  @override
  ConsumerState<SimpleAIStudioScreen> createState() => _SimpleAIStudioScreenState();
}

class _SimpleAIStudioScreenState extends ConsumerState<SimpleAIStudioScreen> {
  final ImagePicker _picker = ImagePicker();
  final ScrollController _scrollController = ScrollController();

  Uint8List? _roomBytes;
  String? _roomLabel;
  Uint8List? _designBytes;
  String? _preSelectedStoneName;
  bool _loadingPreSelectedStone = false;

  int _selectedColorIndex = 0;
  StudioColorVariant get _activeVariant => _studioColorVariants[_selectedColorIndex];

  String? _resultImage; // data URL
  bool _generating = false;
  double _generationProgress = 0.0;
  String _generationStatusText = 'Creating image';
  String? _statusNote;
  bool _resultFromAi = false;
  String? _error;
  bool _showOriginal = false;

  @override
  void initState() {
    super.initState();
    if (widget.preSelectedStoneId != null) {
      _loadPreSelectedStone(widget.preSelectedStoneId!);
    } else {
      _loadInitialDemo();
    }
  }

  Future<void> _loadInitialDemo() async {
    try {
      final roomData = await rootBundle.load('assets/images/home_hero_living_room.jpg');
      final stoneData = await rootBundle.load('assets/images/grande_ledge_ta02_tex.png');
      if (!mounted) return;
      setState(() {
        _roomBytes = roomData.buffer.asUint8List();
        _roomLabel = 'Living Room Feature Wall';
        _designBytes = stoneData.buffer.asUint8List();
        _preSelectedStoneName = 'Grande Ledge Series';
      });
    } catch (_) {}
  }

  Future<void> _loadPreSelectedStone(String stoneId) async {
    setState(() => _loadingPreSelectedStone = true);
    try {
      final stone = await ref.read(stoneRepositoryProvider).getStoneById(stoneId);
      final imageUrl = stone.arTexture ??
          stone.mainImageUrl ??
          (stone.images.isNotEmpty ? stone.images.first : null);
      if (imageUrl == null || imageUrl.isEmpty) return;

      final response = await Dio().get<List<int>>(
        imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      if (bytes == null || !mounted) return;
      setState(() {
        _designBytes = Uint8List.fromList(bytes);
        _preSelectedStoneName = stone.name;
      });
    } catch (_) {
      // Best-effort
    } finally {
      if (mounted) setState(() => _loadingPreSelectedStone = false);
    }
  }

  Future<void> _pick(bool isRoom) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: const Color(0xFF161618),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _SourceSelectorSheet(isRoom: isRoom),
    );

    if (result == null) return;

    if (result['source'] == 'asset') {
      final assetPath = result['assetPath'] as String;
      final label = result['label'] as String?;
      try {
        final byteData = await rootBundle.load(assetPath);
        final bytes = byteData.buffer.asUint8List();
        HapticFeedback.lightImpact();
        if (!mounted) return;
        setState(() {
          if (isRoom) {
            _roomBytes = bytes;
            _roomLabel = label;
          } else {
            _designBytes = bytes;
            _preSelectedStoneName = label;
          }
          _resultImage = null;
          _error = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFFD4AF37), size: 18),
                const SizedBox(width: 8),
                Text('$label selected', style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
              ],
            ),
            backgroundColor: const Color(0xFF1E1E22),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load preset: $e', style: GoogleFonts.inter(color: Colors.white)),
            backgroundColor: const Color(0xFFE53935),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      return;
    }

    if (result['source'] == 'stone_model') {
      final stone = result['stone'] as Stone;
      final bytes = result['bytes'] as Uint8List;
      HapticFeedback.lightImpact();
      if (!mounted) return;
      setState(() {
        _designBytes = bytes;
        _preSelectedStoneName = stone.name;
        _resultImage = null;
        _error = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFFD4AF37), size: 18),
              const SizedBox(width: 8),
              Text('${stone.name} loaded from catalogue', style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
            ],
          ),
          backgroundColor: const Color(0xFF1E1E22),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final source = result['source'] as ImageSource;
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Selected image is empty. Please choose another photo.', style: GoogleFonts.inter(color: Colors.white)),
            backgroundColor: const Color(0xFFE53935),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }

      HapticFeedback.mediumImpact();
      if (!mounted) return;
      setState(() {
        if (isRoom) {
          _roomBytes = bytes;
          _roomLabel = 'Custom Room Photo';
        } else {
          _designBytes = bytes;
          _preSelectedStoneName = 'Custom Stone Texture';
        }
        _resultImage = null;
        _error = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFFD4AF37), size: 18),
              const SizedBox(width: 8),
              Text(
                isRoom ? 'Room photo uploaded successfully' : 'Stone texture uploaded successfully',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1E1E22),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            source == ImageSource.camera
                ? 'Camera unavailable or permission denied. Please choose from Gallery.'
                : 'Could not access photo library. Please check permissions.',
            style: GoogleFonts.inter(color: Colors.white),
          ),
          backgroundColor: const Color(0xFFE53935),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _generate() async {
    if (_roomBytes == null || _designBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _roomBytes == null
                ? 'Please select or upload a room photo first (Step 1)'
                : 'Please select or upload a stone design first (Step 2)',
            style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
          ),
          backgroundColor: const Color(0xFFD4AF37),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    HapticFeedback.heavyImpact();
    setState(() {
      _generating = true;
      _generationProgress = 0.08;
      _generationStatusText = 'Scanning room depth & wall geometry...';
      _error = null;
      _statusNote = null;
      _showOriginal = false;
    });

    String? generatedB64;
    String statusNote = 'Quick preview • ${_activeVariant.name} (AI render unavailable, try again shortly)';
    var fromAi = false;

    // Start background inference (via Vercel AI proxy or local high-res compositor)
    final inferenceFuture = () async {
      try {
        final roomDataUrl = _jpegDataUrl(_roomBytes!);
        final designDataUrl = _jpegDataUrl(_designBytes!);

        final data = await AIEndpointClient.post('/api/generate-visualization', {
          'image': roomDataUrl,
          'designImage': designDataUrl,
          'color': _activeVariant.name,
          'finish': _activeVariant.finishName,
          'variantIndex': _selectedColorIndex,
        });

        final returnedImage = data['resultImage'] as String?;
        if (returnedImage != null && returnedImage.isNotEmpty) {
          generatedB64 = returnedImage;
          statusNote = 'Rendered via Google Gemini 2.5 Flash';
          fromAi = true;
          return;
        }
      } catch (e) {
        debugPrint('[AIStudio] generate-visualization failed, using local preview: $e');
      }

      // High-precision architectural composite
      final compositeUrl = await _createLocalCompositeDataUrl();
      generatedB64 = compositeUrl;
    }();

    // Sequence of animated neural synthesis steps matching user's design (0.08 -> 0.43 -> 0.89 -> 1.0)
    final steps = [
      (0.24, 'Detecting furniture & sofa occlusion boundaries...'),
      (0.43, 'Isolating foreground decor, plants & ceiling fixtures...'),
      (0.68, 'Synthesizing ${_preSelectedStoneName ?? "stone"} texture onto wall...'),
      (0.89, 'Rendering ambient contact drop-shadows & light wash...'),
      (0.98, 'Finalizing photorealistic architectural render...'),
    ];

    for (final step in steps) {
      await Future.delayed(const Duration(milliseconds: 550));
      if (!mounted || !_generating) return;
      setState(() {
        _generationProgress = step.$1;
        _generationStatusText = step.$2;
      });
    }

    // Await background inference completion
    await inferenceFuture;

    if (!mounted) return;
    setState(() {
      _generationProgress = 1.0;
      _generationStatusText = 'Synthesis complete!';
    });

    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    if (generatedB64 != null) {
      setState(() {
        _resultImage = generatedB64;
        _resultFromAi = fromAi;
        _generating = false;
        _statusNote = statusNote;
      });
      HapticFeedback.mediumImpact();
      _scrollToResult();
    } else {
      setState(() {
        _generating = false;
        _error = 'Could not generate preview. Please try another photo.';
      });
    }
  }

  Future<String?> _createLocalCompositeDataUrl() async {
    if (_roomBytes == null || _designBytes == null) return null;
    try {
      final roomCodec = await ui.instantiateImageCodec(_roomBytes!);
      final roomFrame = await roomCodec.getNextFrame();
      final roomImg = roomFrame.image;

      final designCodec = await ui.instantiateImageCodec(_designBytes!);
      final designFrame = await designCodec.getNextFrame();
      final designImg = designFrame.image;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
        recorder,
        Rect.fromLTWH(0, 0, roomImg.width.toDouble(), roomImg.height.toDouble()),
      );

      final rw = roomImg.width.toDouble();
      final rh = roomImg.height.toDouble();

      // 1. Draw original room base
      canvas.drawImage(roomImg, Offset.zero, Paint());

      // 2. Compute accurate architectural wall path isolating wall BEHIND furniture
      final wallPath = _buildArchitecturalWallPath(width: rw, height: rh, label: _roomLabel);

      // 3. Texture tile shader with perspective alignment
      final shader = ImageShader(
        designImg,
        TileMode.repeated,
        TileMode.repeated,
        Matrix4.identity().storage,
      );

      // Save canvas and clip strictly to the vertical wall surface
      canvas.save();
      canvas.clipPath(wallPath);

      // 4. Draw texture with active colorway tint & finish blend mode
      final texturePaint = Paint()
        ..shader = shader
        ..colorFilter = ColorFilter.mode(
          _activeVariant.tintColor,
          _activeVariant.blendMode,
        );
      canvas.drawPath(wallPath, texturePaint);

      // 5. Draw architectural lighting: ceiling ambient wash + vertical drop-shadow
      final lightingGradient = ui.Gradient.linear(
        Offset(0, rh * 0.10),
        Offset(0, rh * 0.70),
        [
          Colors.white.withValues(alpha: 0.15),
          Colors.transparent,
          Colors.black.withValues(alpha: 0.35),
        ],
        [0.0, 0.45, 1.0],
      );
      canvas.drawPath(
        wallPath,
        Paint()
          ..shader = lightingGradient
          ..blendMode = BlendMode.overlay,
      );

      // 6. Contact shadow behind furniture backrest (so sofa appears physically in front)
      if ((_roomLabel ?? '').toLowerCase().contains('living')) {
        final shadowRect = Rect.fromLTRB(rw * 0.28, rh * 0.63, rw * 0.77, rh * 0.69);
        final sofaShadow = ui.Gradient.linear(
          Offset(0, rh * 0.63),
          Offset(0, rh * 0.69),
          [Colors.transparent, Colors.black.withValues(alpha: 0.65)],
        );
        canvas.drawRect(
          shadowRect,
          Paint()
            ..shader = sofaShadow
            ..blendMode = BlendMode.multiply,
        );
      }

      canvas.restore();

      final picture = recorder.endRecording();
      final compositeImg = await picture.toImage(roomImg.width, roomImg.height);
      final byteData = await compositeImg.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final b64 = base64Encode(byteData.buffer.asUint8List());
      return 'data:image/png;base64,$b64';
    } catch (_) {
      return null;
    }
  }

  Future<void> _generateLocalComposite() async {
    final url = await _createLocalCompositeDataUrl();
    if (url != null && mounted) {
      setState(() {
        _resultImage = url;
        _resultFromAi = false;
        _generating = false;
        _statusNote = 'Quick preview • ${_activeVariant.name}';
      });
    }
  }

  void _openFullscreenViewer() {
    if (_resultImage == null) return;
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.96),
        pageBuilder: (context, _, __) {
          return _FullscreenStudioViewer(
            resultImage: _resultImage!,
            originalBytes: _roomBytes,
            stoneName: _preSelectedStoneName ?? 'Grazia Natural Stone',
            variantName: _activeVariant.name,
            finishName: _activeVariant.finishName,
            onDownload: _downloadImage,
            onWhatsApp: _shareToWhatsApp,
            onShare: _shareResult,
          );
        },
        transitionsBuilder: (context, anim, _, child) {
          return FadeTransition(opacity: anim, child: child);
        },
      ),
    );
  }

  Future<void> _downloadImage() async {
    if (_resultImage == null) return;
    HapticFeedback.mediumImpact();
    try {
      final bytes = base64Decode(_resultImage!.split(',').last);
      final fileName = 'Grazia_Stones_${_activeVariant.id}_${DateTime.now().millisecondsSinceEpoch}.png';
      if (kIsWeb) {
        // Browser: triggers a file download (dart:io File doesn't exist on web)
        await XFile.fromData(bytes, mimeType: 'image/png', name: fileName).saveTo(fileName);
      } else {
        final dir = await getApplicationDocumentsDirectory();
        await File('${dir.path}/$fileName').writeAsBytes(bytes);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF161618),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFD4AF37), width: 1.2),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          duration: const Duration(seconds: 3),
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFD4AF37),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.black, size: 16),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Saved to Device',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'High-resolution architectural render downloaded.',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF8E8E93),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save image: $e')),
      );
    }
  }

  Future<void> _shareToWhatsApp() async {
    if (_resultImage == null) return;
    HapticFeedback.mediumImpact();
    try {
      final bytes = base64Decode(_resultImage!.split(',').last);
      final file = XFile.fromData(bytes, mimeType: 'image/png', name: 'grazia_${_activeVariant.id}_preview.png');

      final message = '✨ *Grazia Stones — AI Room Visualization*\n'
          '🏛 Stone Design: ${_preSelectedStoneName ?? "Luxury Natural Stone"}\n'
          '🎨 Color & Finish: ${_activeVariant.name} (${_activeVariant.finishName})\n'
          '📍 Applied to: ${_roomLabel ?? "Living Room Feature Wall"}\n\n'
          'Explore Grazia Natural Stone Collections: https://graziastones.com';

      final whatsappUrl = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(message)}');
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      }

      await Share.shareXFiles(
        [file],
        text: message,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('WhatsApp share: $e')),
      );
    }
  }

  Path _buildArchitecturalWallPath({
    required double width,
    required double height,
    required String? label,
  }) {
    final path = Path();
    final norm = (label ?? '').toLowerCase();

    if (norm.contains('living')) {
      // Living Room: Wall behind sofa (strictly isolates sofa, plant, curtains, and ceiling)
      path.moveTo(width * 0.28, height * 0.105); // top-left (below ceiling soffit, past wood column & plant)
      path.lineTo(width, height * 0.105);        // top-right
      path.lineTo(width, height * 0.84);         // down along right wall to floor
      path.lineTo(width * 0.77, height * 0.84);  // floor to right sofa armrest
      path.lineTo(width * 0.77, height * 0.685); // up right sofa edge
      path.lineTo(width * 0.28, height * 0.685); // across top backrest of sofa
      path.close();
    } else if (norm.contains('bedroom')) {
      // Bedroom: Accent wall behind headboard (isolating bed, headboard, nightstands, and window)
      path.moveTo(0, height * 0.08);
      path.lineTo(width * 0.66, height * 0.08);
      path.lineTo(width * 0.66, height * 0.57);
      path.lineTo(0, height * 0.57);
      path.close();
    } else if (norm.contains('fire')) {
      // Fireplace: Center chimney column (isolates curved sofa, table, and hearth)
      path.moveTo(width * 0.515, height * 0.06);
      path.lineTo(width * 0.885, height * 0.06);
      path.lineTo(width * 0.885, height * 0.625);
      path.lineTo(width * 0.515, height * 0.625);
      path.close();
    } else if (norm.contains('dining')) {
      // Dining Suite: Curved architectural column (isolates dining table, chairs, bar)
      path.moveTo(width * 0.43, height * 0.05);
      path.lineTo(width * 0.78, height * 0.05);
      path.lineTo(width * 0.78, height * 0.82);
      path.lineTo(width * 0.43, height * 0.82);
      path.close();
    } else {
      // User Camera/Gallery Photo: Preserve bottom 36% for furniture/seating/floor, top 10% for ceiling
      path.moveTo(width * 0.04, height * 0.10);
      path.lineTo(width * 0.96, height * 0.10);
      path.lineTo(width * 0.96, height * 0.64);
      path.lineTo(width * 0.04, height * 0.64);
      path.close();
    }
    return path;
  }

  void _scrollToResult() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onColorVariantChanged(int index) {
    if (index == _selectedColorIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedColorIndex = index);

    // Re-render in the new colourway: through the AI again if the current
    // result came from it (a local composite would silently replace it).
    if (_resultImage != null && _roomBytes != null && _designBytes != null && !_generating) {
      _resultFromAi ? _generate() : _generateLocalComposite();
    }
  }

  /// Downscaled JPEG data URL for the AI proxy: keeps the request under
  /// Vercel's ~4.5 MB body limit and labels the bytes with their real type.
  String _jpegDataUrl(Uint8List bytes) {
    var decoded = img.decodeImage(bytes);
    if (decoded == null) return 'data:image/jpeg;base64,${base64Encode(bytes)}';
    if (decoded.width > 1536 || decoded.height > 1536) {
      decoded = decoded.width >= decoded.height
          ? img.copyResize(decoded, width: 1536)
          : img.copyResize(decoded, height: 1536);
    }
    return 'data:image/jpeg;base64,${base64Encode(img.encodeJpg(decoded, quality: 85))}';
  }

  Future<void> _shareResult() async {
    if (_resultImage == null) return;
    try {
      final bytes = base64Decode(_resultImage!.split(',').last);
      final file = XFile.fromData(bytes, mimeType: 'image/png', name: 'grazia_${_activeVariant.id}_${DateTime.now().millisecondsSinceEpoch}.png');
      await Share.shareXFiles(
        [file],
        text: 'My Grazia Stones ${_activeVariant.name} room visualization',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not share the result.')),
      );
    }
  }

  void _showApiInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161618),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _ApiArchitectureSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🔥🔥🔥 BUILDING SimpleAIStudioScreen now! 🔥🔥🔥');
    final canGenerate = _roomBytes != null && _designBytes != null && !_generating;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F11),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/home');
            }
          },
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
        ),
        title: Text(
          'AI Room Studio',
          style: GoogleFonts.playfairDisplay(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _showApiInfo,
            icon: const Icon(Icons.info_outline_rounded, color: Color(0xFFD4AF37), size: 22),
            tooltip: 'AI & Architecture',
          ),
        ],
      ),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          // ─── CASE 1: AI GENERATION IN PROGRESS (Screenshots 3 & 4 Dot Matrix Animation) ───
          if (_generating) ...[
            _NeuralSynthesisWidget(
              progress: _generationProgress,
              statusText: _generationStatusText,
            ),
          ]

          // ─── CASE 2: RESULT GENERATED IN PLACE ("usi jagah pe aa jaye") ───
          else if (_resultImage != null) ...[
            // Top Context Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded, color: Color(0xFFD4AF37), size: 14),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_roomLabel ?? "Living Room"} • ${_preSelectedStoneName ?? "Stone Cladding"}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() => _resultImage = null);
                  },
                  icon: const Icon(Icons.replay_rounded, size: 14, color: Color(0xFFD4AF37)),
                  label: Text(
                    'Change Photos',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFFD4AF37),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // In-Place Result Card (Tap to Zoom Fullscreen)
            GestureDetector(
              onTap: _openFullscreenViewer,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF161618),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.35), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.08),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header inside card
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Architectural Output',
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              if (_statusNote != null)
                                Text(
                                  _statusNote!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: const Color(0xFFD4AF37),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Before / After toggle
                        if (_roomBytes != null)
                          InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _showOriginal = !_showOriginal);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _showOriginal
                                    ? const Color(0xFFD4AF37).withValues(alpha: 0.2)
                                    : const Color(0xFF26262A),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _showOriginal ? const Color(0xFFD4AF37) : const Color(0xFF333338),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _showOriginal ? Icons.visibility_rounded : Icons.compare_rounded,
                                    size: 14,
                                    color: _showOriginal ? const Color(0xFFD4AF37) : Colors.white,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    _showOriginal ? 'Original' : 'Compare',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _showOriginal ? const Color(0xFFD4AF37) : Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Image Display with Tap to Enlarge
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          AnimatedCrossFade(
                            duration: const Duration(milliseconds: 250),
                            crossFadeState: _showOriginal
                                ? CrossFadeState.showSecond
                                : CrossFadeState.showFirst,
                            firstChild: Image.memory(
                              base64Decode(_resultImage!.split(',').last),
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                            secondChild: _roomBytes != null
                                ? Image.memory(
                                    _roomBytes!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                  )
                                : const SizedBox.shrink(),
                          ),

                          // Top-left Variant Tag
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.72),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                              ),
                              child: Text(
                                _showOriginal ? 'ORIGINAL ROOM' : _activeVariant.name.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: _showOriginal ? Colors.white : const Color(0xFFD4AF37),
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ),

                          // Bottom-right "Tap to Zoom" badge
                          Positioned(
                            bottom: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Tap to Zoom',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Color Variants Selection Bar inside Result
                    Text(
                      'TRY SAME DESIGN IN OTHER FINISHES & TONES:',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: const Color(0xFF8E8E93),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _studioColorVariants.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, idx) {
                          final v = _studioColorVariants[idx];
                          final isSel = idx == _selectedColorIndex;
                          return InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => _onColorVariantChanged(idx),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSel ? const Color(0xFFD4AF37).withValues(alpha: 0.18) : const Color(0xFF222226),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSel ? const Color(0xFFD4AF37) : const Color(0xFF333338),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(radius: 6, backgroundColor: v.swatchColor),
                                  const SizedBox(width: 6),
                                  Text(
                                    v.name,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                      color: isSel ? const Color(0xFFD4AF37) : Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Matching Collections Recommendation Chip
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E22),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF2A2A30)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.layers_outlined, color: Color(0xFFD4AF37), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Recommended Collections for this shade:',
                                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF8E8E93)),
                                ),
                                Text(
                                  _activeVariant.matchingCollections.join(' • '),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Action Buttons Row: Download, WhatsApp, Share, Order Sample
                    Row(
                      children: [
                        // Download button
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _downloadImage,
                            icon: const Icon(Icons.download_rounded, size: 16, color: Colors.white),
                            label: Text(
                              'Save',
                              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF3A3A40)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // WhatsApp button
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _shareToWhatsApp,
                            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Color(0xFF25D366)),
                            label: Text(
                              'WhatsApp',
                              style: GoogleFonts.inter(color: const Color(0xFF25D366), fontWeight: FontWeight.w600, fontSize: 12),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: const Color(0xFF25D366).withValues(alpha: 0.4)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Share HD button
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _shareResult,
                            icon: const Icon(Icons.share_outlined, size: 16, color: Colors.black),
                            label: Text(
                              'Share',
                              style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD4AF37),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Order Sample Tile button
                    OutlinedButton.icon(
                      onPressed: () {
                        context.push('/samples/request');
                      },
                      icon: const Icon(Icons.shopping_bag_outlined, size: 16, color: Color(0xFFD4AF37)),
                      label: Text(
                        'Order Free Physical Sample Tile',
                        style: GoogleFonts.inter(color: const Color(0xFFD4AF37), fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFD4AF37)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ]

          // ─── CASE 3: INITIAL PHOTO SLOTS SELECTION ───
          else ...[
            // Subtitle & Status badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Two photos, one realistic result.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF8E8E93),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.35), width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: Color(0xFFD4AF37), size: 11),
                      const SizedBox(width: 4),
                      Text(
                        'AI GEN 2.5',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFD4AF37),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Slot 1: Your Room
            _LuxuryImageSlot(
              stepNumber: '1',
              label: 'Your Room',
              subtitle: _roomLabel ?? 'Photo of the wall you want to redesign',
              bytes: _roomBytes,
              onTap: () => _pick(true),
            ),
            const SizedBox(height: 14),

            // Slot 2: Your Design
            if (_loadingPreSelectedStone)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD4AF37)),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Loading selected stone texture…',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF8E8E93)),
                    ),
                  ],
                ),
              ),
            _LuxuryImageSlot(
              stepNumber: '2',
              label: 'Your Design',
              subtitle: _preSelectedStoneName != null
                  ? '$_preSelectedStoneName — tap to switch'
                  : 'Photo of the stone or tile design you want applied',
              bytes: _designBytes,
              onTap: () => _pick(false),
            ),
            const SizedBox(height: 20),

            // Colorway & Finish Palette Selector
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'STONE COLORWAY & FINISH',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: const Color(0xFFA1A1A6),
                      ),
                    ),
                    Text(
                      _activeVariant.finishName,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFD4AF37),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _studioColorVariants.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, idx) {
                      final variant = _studioColorVariants[idx];
                      final isSelected = idx == _selectedColorIndex;
                      return InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => _onColorVariantChanged(idx),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF26262A) : const Color(0xFF161618),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isSelected ? const Color(0xFFD4AF37) : const Color(0xFF2A2A2E),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: variant.swatchColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 0.8),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                variant.name,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected ? Colors.white : const Color(0xFF8E8E93),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // Generate Action Button
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: canGenerate ? _generate : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: const Color(0xFF1C1C1E),
                  disabledForegroundColor: const Color(0xFF555558),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.auto_fix_high_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Generate Realistic Result',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_error!, style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _LuxuryImageSlot extends StatelessWidget {
  final String stepNumber;
  final String label;
  final String subtitle;
  final Uint8List? bytes;
  final VoidCallback onTap;

  const _LuxuryImageSlot({
    required this.stepNumber,
    required this.label,
    required this.subtitle,
    required this.bytes,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = bytes != null && bytes!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 195,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: hasImage
                ? const Color(0xFFD4AF37).withValues(alpha: 0.6)
                : const Color(0xFF2C2C2E),
            width: hasImage ? 1.4 : 1.0,
          ),
          color: const Color(0xFF161618),
          image: hasImage
              ? DecorationImage(
                  image: MemoryImage(bytes!),
                  fit: BoxFit.cover,
                )
              : null,
          boxShadow: hasImage
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: hasImage
            ? Stack(
                fit: StackFit.expand,
                children: [
                  // Top scrim for crisp badge and change button
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 64,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.75),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Bottom scrim for title & subtitle
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 76,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.85),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Top Row: Step Badge + Change Button
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFFD4AF37),
                                size: 12,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'STEP $stepNumber • ${label.toUpperCase()}',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.80),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFD4AF37),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.photo_camera_back_outlined,
                                size: 13,
                                color: Color(0xFFD4AF37),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Change',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom info banner
                  Positioned(
                    bottom: 12,
                    left: 14,
                    right: 14,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Tap to upload or select another image',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFA1A1A6),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 11,
                            color: Color(0xFFD4AF37),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF242426),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                        width: 1.2,
                      ),
                    ),
                    child: const Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 26,
                      color: Color(0xFFD4AF37),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Step $stepNumber: $label',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF8E8E93),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF242428),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF333338)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.camera_alt_outlined, size: 12, color: Color(0xFFD4AF37)),
                            const SizedBox(width: 4),
                            Text('Camera', style: GoogleFonts.inter(color: Colors.white, fontSize: 11)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF242428),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF333338)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.photo_library_outlined, size: 12, color: Color(0xFFD4AF37)),
                            const SizedBox(width: 4),
                            Text('Gallery', style: GoogleFonts.inter(color: Colors.white, fontSize: 11)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF242428),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF333338)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.auto_awesome_rounded, size: 12, color: Color(0xFFD4AF37)),
                            const SizedBox(width: 4),
                            Text('Presets', style: GoogleFonts.inter(color: Colors.white, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _SourceSelectorSheet extends ConsumerStatefulWidget {
  final bool isRoom;

  const _SourceSelectorSheet({required this.isRoom});

  @override
  ConsumerState<_SourceSelectorSheet> createState() => _SourceSelectorSheetState();
}

class _SourceSelectorSheetState extends ConsumerState<_SourceSelectorSheet> {
  String? _loadingStoneId;

  Future<void> _selectStone(Stone stone) async {
    setState(() => _loadingStoneId = stone.id);
    try {
      final imageUrl = stone.arTexture ??
          stone.mainImageUrl ??
          (stone.images.isNotEmpty ? stone.images.first : null);
      if (imageUrl == null || imageUrl.isEmpty) {
        throw Exception('No texture available for this stone');
      }

      Uint8List bytes;
      if (imageUrl.startsWith('assets/')) {
        final data = await rootBundle.load(imageUrl);
        bytes = data.buffer.asUint8List();
      } else {
        final response = await Dio().get<List<int>>(
          imageUrl,
          options: Options(responseType: ResponseType.bytes),
        );
        bytes = Uint8List.fromList(response.data!);
      }

      if (!mounted) return;
      Navigator.pop(context, {
        'source': 'stone_model',
        'stone': stone,
        'bytes': bytes,
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingStoneId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not load stone: $e', style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: const Color(0xFFE53935),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final presets = widget.isRoom ? _sampleRooms : _sampleStones;

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Drag Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isRoom ? 'Select Room Photo' : 'Select Stone Surface',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.isRoom
                            ? 'Upload your wall or choose a showroom preset'
                            : 'Upload custom sample or pick from Grazia collection',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF8E8E93),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF8E8E93)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Camera & Gallery Primary Action Buttons
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.pop(context, {'source': ImageSource.camera}),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF242428), Color(0xFF1E1E22)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF333338)),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt_rounded, color: Color(0xFFD4AF37), size: 24),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Take Photo',
                            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.isRoom ? 'Snap your wall' : 'Snap stone sample',
                            style: GoogleFonts.inter(color: const Color(0xFF8E8E93), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.pop(context, {'source': ImageSource.gallery}),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF242428), Color(0xFF1E1E22)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF333338)),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.photo_library_rounded, color: Color(0xFFD4AF37), size: 24),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Choose Gallery',
                            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Upload from device',
                            style: GoogleFonts.inter(color: const Color(0xFF8E8E93), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Scrollable section for presets & catalog
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section Title
                    Text(
                      widget.isRoom
                          ? 'OR TRY WITH A GRAZIA LUXURY ROOM:'
                          : 'SIGNATURE STONE TEXTURES:',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: const Color(0xFF8E8E93),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 130,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: presets.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, idx) {
                          final p = presets[idx];
                          return InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              Navigator.pop(context, {
                                'source': 'asset',
                                'assetPath': p.assetPath,
                                'label': p.title,
                              });
                            },
                            child: Container(
                              width: 140,
                              decoration: BoxDecoration(
                                color: const Color(0xFF222226),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFF333338)),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: Image.asset(
                                      p.assetPath,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                        Text(
                                          p.subtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            color: const Color(0xFF8E8E93),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    if (!widget.isRoom) ...[
                      const SizedBox(height: 20),
                      Text(
                        'BROWSE CATALOGUE (36 SERIES):',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: const Color(0xFF8E8E93),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ref.watch(allStonesProvider).when(
                            data: (stones) {
                              if (stones.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return SizedBox(
                                height: 130,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: stones.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                                  itemBuilder: (context, idx) {
                                    final stone = stones[idx];
                                    final isLoading = _loadingStoneId == stone.id;
                                    final imgUrl = stone.arTexture ??
                                        stone.mainImageUrl ??
                                        (stone.images.isNotEmpty ? stone.images.first : null);

                                    return InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap: isLoading ? null : () => _selectStone(stone),
                                      child: Container(
                                        width: 140,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF222226),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: isLoading
                                                ? const Color(0xFFD4AF37)
                                                : const Color(0xFF333338),
                                          ),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            Expanded(
                                              child: Stack(
                                                fit: StackFit.expand,
                                                children: [
                                                  if (imgUrl != null && imgUrl.startsWith('assets/'))
                                                    Image.asset(imgUrl, fit: BoxFit.cover)
                                                  else if (imgUrl != null)
                                                    Image.network(
                                                      imgUrl,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (_, __, ___) => const Center(
                                                        child: Icon(Icons.broken_image_outlined,
                                                            color: Colors.white24),
                                                      ),
                                                    )
                                                  else
                                                    const Center(
                                                      child: Icon(Icons.texture_rounded, color: Colors.white24),
                                                    ),
                                                  if (isLoading)
                                                    Container(
                                                      color: Colors.black.withValues(alpha: 0.6),
                                                      child: const Center(
                                                        child: SizedBox(
                                                          width: 22,
                                                          height: 22,
                                                          child: CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color: Color(0xFFD4AF37),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    stone.name,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  Text(
                                                    stone.collection,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 10,
                                                      color: const Color(0xFF8E8E93),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                            loading: () => const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFD4AF37),
                                  ),
                                ),
                              ),
                            ),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApiArchitectureSheet extends StatelessWidget {
  const _ApiArchitectureSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'AI Studio Architecture',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF8E8E93)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _infoItem(
              icon: Icons.cloud_done_outlined,
              title: 'Backend API Endpoint',
              description: 'https://grazia-stones.vercel.app/api/generate-visualization',
            ),
            const SizedBox(height: 12),
            _infoItem(
              icon: Icons.psychology_outlined,
              title: 'Primary AI Model & API Key',
              description:
                  'Google Gemini 2.5 Flash Image Generation.\nAPI Key: GEMINI_API_KEY (stored securely in backend environment).',
            ),
            const SizedBox(height: 12),
            _infoItem(
              icon: Icons.filter_center_focus_rounded,
              title: 'Room & Wall Vision Detection',
              description: 'NVIDIA NIM Vision (Llama 3.2 11B Vision Instruct) via /api/wall-detect.',
            ),
            const SizedBox(height: 12),
            _infoItem(
              icon: Icons.bolt_rounded,
              title: 'Offline / Hybrid Neural Engine',
              description:
                  'If Gemini rate limits or connection drops, Grazia GPU Compositor seamlessly renders realistic multi-shade wall claddings instantly without breaking.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFFD4AF37), size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.inter(color: const Color(0xFF8E8E93), fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Animated Neural Synthesis Screen matching User's Dot Matrix AI generation design (Screenshots 3 & 4)
class _NeuralSynthesisWidget extends StatefulWidget {
  final double progress;
  final String statusText;

  const _NeuralSynthesisWidget({
    required this.progress,
    required this.statusText,
  });

  @override
  State<_NeuralSynthesisWidget> createState() => _NeuralSynthesisWidgetState();
}

class _NeuralSynthesisWidgetState extends State<_NeuralSynthesisWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final percent = (widget.progress * 100).toInt().clamp(0, 100);

    return Container(
      height: 380,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF070709),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF1E293B).withValues(alpha: 0.9),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
            blurRadius: 32,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Animated Dot Matrix Painter
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _DotMatrixPainter(
                    progress: widget.progress,
                    wavePhase: _waveController.value,
                  ),
                );
              },
            ),
          ),

          // Header: "Creating image"
          Positioned(
            top: 22,
            left: 22,
            right: 22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Creating image',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF38BDF8),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  widget.statusText,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),

          // Progress percentage pill on bottom right
          Positioned(
            bottom: 22,
            right: 22,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF131B2E).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF334155),
                  width: 1,
                ),
              ),
              child: Text(
                '$percent%',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF38BDF8),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DotMatrixPainter extends CustomPainter {
  final double progress;
  final double wavePhase;

  _DotMatrixPainter({
    required this.progress,
    required this.wavePhase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const int cols = 26;
    const int rows = 22;

    final cellW = size.width / (cols + 1);
    final cellH = (size.height - 90) / (rows + 1);
    const startY = 74.0;

    final inactivePaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final x = cellW * (c + 1);
        final y = startY + cellH * (r + 1);

        final diagDist = (c / cols * 0.55) + (r / rows * 0.45);

        if (diagDist <= progress) {
          final waveOffset = (diagDist * 4 - wavePhase * 2 * math.pi);
          final pulse = (math.sin(waveOffset) + 1.0) / 2.0;

          final alpha = 0.35 + (0.65 * pulse);
          final radius = 1.3 + (1.2 * pulse);

          final activePaint = Paint()
            ..color = Color.lerp(
              const Color(0xFF1D4ED8),
              const Color(0xFF38BDF8),
              pulse,
            )!.withValues(alpha: alpha)
            ..style = PaintingStyle.fill;

          canvas.drawCircle(Offset(x, y), radius, activePaint);
        } else {
          canvas.drawCircle(Offset(x, y), 1.0, inactivePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotMatrixPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.wavePhase != wavePhase;
  }
}

/// Fullscreen Zoom Interactive Viewer ("tap kare to wo bada ho jaye")
class _FullscreenStudioViewer extends StatefulWidget {
  final String resultImage;
  final Uint8List? originalBytes;
  final String stoneName;
  final String variantName;
  final String finishName;
  final VoidCallback onDownload;
  final VoidCallback onWhatsApp;
  final VoidCallback onShare;

  const _FullscreenStudioViewer({
    required this.resultImage,
    required this.originalBytes,
    required this.stoneName,
    required this.variantName,
    required this.finishName,
    required this.onDownload,
    required this.onWhatsApp,
    required this.onShare,
  });

  @override
  State<_FullscreenStudioViewer> createState() => _FullscreenStudioViewerState();
}

class _FullscreenStudioViewerState extends State<_FullscreenStudioViewer> {
  final TransformationController _transformController = TransformationController();
  bool _showOriginal = false;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transformController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    final imageBytes = base64Decode(widget.resultImage.split(',').last);

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: SafeArea(
        child: Stack(
          children: [
            // Interactive Pinch & Pan Zoomable Canvas
            Center(
              child: GestureDetector(
                onDoubleTap: _resetZoom,
                child: InteractiveViewer(
                  transformationController: _transformController,
                  minScale: 0.8,
                  maxScale: 5.0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedCrossFade(
                      duration: const Duration(milliseconds: 250),
                      crossFadeState: _showOriginal
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: Image.memory(
                        imageBytes,
                        fit: BoxFit.contain,
                      ),
                      secondChild: widget.originalBytes != null
                          ? Image.memory(
                              widget.originalBytes!,
                              fit: BoxFit.contain,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),

            // Top Bar
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.stoneName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.playfairDisplay(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${widget.variantName} • ${widget.finishName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: const Color(0xFFD4AF37),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.originalBytes != null)
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _showOriginal = !_showOriginal);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _showOriginal
                              ? const Color(0xFFD4AF37).withValues(alpha: 0.25)
                              : Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _showOriginal ? const Color(0xFFD4AF37) : const Color(0xFF333338),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _showOriginal ? Icons.visibility_rounded : Icons.compare_rounded,
                              size: 14,
                              color: _showOriginal ? const Color(0xFFD4AF37) : Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _showOriginal ? 'Original' : 'Compare',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _showOriginal ? const Color(0xFFD4AF37) : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Bottom Action Bar: Download, WhatsApp, Share
            Positioned(
              bottom: 20,
              left: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF161618).withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFF2C2C30)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _viewerActionButton(
                      icon: Icons.download_rounded,
                      label: 'Save',
                      onTap: widget.onDownload,
                    ),
                    Container(height: 24, width: 1, color: const Color(0xFF2C2C30)),
                    _viewerActionButton(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'WhatsApp',
                      color: const Color(0xFF25D366),
                      onTap: widget.onWhatsApp,
                    ),
                    Container(height: 24, width: 1, color: const Color(0xFF2C2C30)),
                    _viewerActionButton(
                      icon: Icons.share_outlined,
                      label: 'Share',
                      color: const Color(0xFFD4AF37),
                      onTap: widget.onShare,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _viewerActionButton({
    required IconData icon,
    required String label,
    Color color = Colors.white,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
