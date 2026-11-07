import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:grazia_stones/core/services/ai_endpoint_client.dart';
import 'package:grazia_stones/core/providers/ai_usage_provider.dart';
import 'package:grazia_stones/features/ai_viz/services/ai_studio_render.dart';
import 'package:grazia_stones/features/ai_viz/services/branded_render.dart';
import 'package:grazia_stones/features/pro/presentation/grazia_pro_screen.dart' show openPaywall;
import 'package:grazia_stones/features/pro/presentation/widgets/plan_widgets.dart' show AiUsageChip;
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/core/providers/stone_providers.dart' show allStonesProvider;
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/shared/widgets/smart_stone_image.dart';

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
  /// `&colour=` index into the stone's images: the shade the user was looking at on the product page.
  final int? preSelectedColour;

  const SimpleAIStudioScreen({super.key, this.preSelectedStoneId, this.preSelectedColour});

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
  // Real catalogue size of the chosen stone, sent so the render scales the pattern correctly.
  String? _preSelectedStoneSpec;
  bool _loadingPreSelectedStone = false;
  // The catalogue stone and image behind _designBytes (null for samples and uploads): drives the suggestions.
  Stone? _selectedStone;
  String? _designUrl;
  // Image URL (colour) or stone id (related) being loaded from a suggestion tap.
  String? _loadingSuggestion;

  StudioColorVariant get _activeVariant => _studioColorVariants.first;

  String? _resultImage; // data URL
  // Decoded once per render so the Image widgets and the reveal key off one stable instance.
  Uint8List? _resultBytesCache;
  String? _resultBytesFor;
  Uint8List get _resultBytes {
    if (!identical(_resultBytesFor, _resultImage)) {
      _resultBytesFor = _resultImage;
      _resultBytesCache = base64Decode(_resultImage!.split(',').last);
    }
    return _resultBytesCache!;
  }
  bool _generating = false;
  // Progress card state: real stages (0 preparing, 1 uploading, 2 designing) timed against the
  // user's own recent renders.
  DateTime _genStartedAt = DateTime.now();
  int _genStage = 0;
  double? _uploadFraction;
  bool _genDone = false;
  int _estimateMs = RenderEta.defaultMs;
  // JPEG data URL per picked image, started off the UI thread as soon as the image is chosen.
  final _jpegCache = Expando<Future<String>>();
  String? _statusNote;
  String? _error;
  bool _showOriginal = false;

  @override
  void initState() {
    super.initState();
    RenderEta.estimateMs().then((ms) => _estimateMs = ms);
    // Start empty so user can upload/select their own room and stone.
    // Only load stone into Step 2 if explicitly navigated with a preSelectedStoneId.
    if (widget.preSelectedStoneId != null) {
      _loadPreSelectedStone(widget.preSelectedStoneId!);
    }
  }

  @override
  void didUpdateWidget(covariant SimpleAIStudioScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preSelectedStoneId != widget.preSelectedStoneId || oldWidget.preSelectedColour != widget.preSelectedColour) {
      if (widget.preSelectedStoneId != null) {
        _loadPreSelectedStone(widget.preSelectedStoneId!);
      } else {
        setState(() {
          _designBytes = null;
          _preSelectedStoneName = null;
          _preSelectedStoneSpec = null;
        });
      }
    }
  }

  Future<void> _loadPreSelectedStone(String stoneId) async {
    setState(() => _loadingPreSelectedStone = true);
    try {
      Stone? stone;
      try {
        stone = await ref.read(stoneRepositoryProvider).getStoneById(stoneId);
      } catch (_) {}

      if (stone == null) {
        final all = ref.read(allStonesProvider).valueOrNull;
        if (all != null && all.isNotEmpty) {
          // Never fall back to an unrelated stone: a wrong design in the render is worse than none.
          stone = findStone(all, stoneId);
        }
      }
      if (stone == null) return;

      final colour = widget.preSelectedColour;
      final imageUrl = (colour != null && colour > 0 && colour < stone.images.length ? stone.images[colour] : null) ??
          stone.arTexture ??
          stone.arTextureUrl ??
          stone.mainImageUrl ??
          (stone.images.isNotEmpty ? stone.images.first : null);
      if (imageUrl == null || imageUrl.isEmpty) {
        if (mounted) {
          setState(() {
            _preSelectedStoneName = stone!.name;
            _preSelectedStoneSpec = _specFor(stone);
          });
        }
        return;
      }

      final bytes = await _loadImageBytes(imageUrl);
      if (!mounted) return;
      _setDesign(stone, imageUrl, bytes);
    } catch (e) {
      debugPrint('[SimpleAIStudio] Error loading stone $stoneId: $e');
    } finally {
      if (mounted) setState(() => _loadingPreSelectedStone = false);
    }
  }

  Future<void> _pick(bool isRoom) async {
    final palette = ref.read(themePaletteProvider);
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: palette.surface,
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
            _preSelectedStoneSpec = null;
            _selectedStone = null;
            _designUrl = null;
          }
          _resultImage = null;
          _error = null;
        });
        _prewarm();
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
      _setDesign(stone, result['imageUrl'] as String?, bytes);
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
          _preSelectedStoneSpec = null;
          _selectedStone = null;
          _designUrl = null;
        }
        _resultImage = null;
        _error = null;
      });
      _prewarm();

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

  /// Makes [stone] (shown as [imageUrl]) the Step 2 design.
  void _setDesign(Stone stone, String? imageUrl, Uint8List bytes) {
    setState(() {
      _designBytes = bytes;
      _preSelectedStoneName = stone.name;
      _preSelectedStoneSpec = _specFor(stone);
      _selectedStone = stone;
      _designUrl = imageUrl;
      _resultImage = null;
      _error = null;
    });
    _prewarm();
  }

  Future<String> _jpegFor(Uint8List bytes, int maxSide) =>
      _jpegCache[bytes] ??= compute(renderJpegDataUrl, (bytes, maxSide));

  /// Starts the resize/encode while the user is still on the screen, so Generate can upload at once.
  void _prewarm() {
    if (_roomBytes != null) _jpegFor(_roomBytes!, roomMaxSide).ignore();
    if (_designBytes != null) _jpegFor(_designBytes!, designMaxSide).ignore();
  }

  /// "Try it in another colour": renders the same stone with another of its catalogue colours.
  Future<void> _renderColour(StoneColour colour) async {
    final stone = _selectedStone;
    if (stone == null || _generating || _loadingSuggestion != null) return;
    HapticFeedback.selectionClick();
    setState(() => _loadingSuggestion = colour.imageUrl);
    try {
      final bytes = await _loadImageBytes(colour.imageUrl);
      if (!mounted) return;
      _loadingSuggestion = null;
      _setDesign(stone, colour.imageUrl, bytes);
      await _generate();
    } catch (e) {
      debugPrint('[AIStudio] colour load failed: $e');
      if (mounted) {
        setState(() => _loadingSuggestion = null);
        _showLoadError();
      }
    }
  }

  /// "You may also like": makes [stone] the design; the user taps Generate (one render per tap).
  Future<void> _selectRelated(Stone stone) async {
    if (_generating || _loadingSuggestion != null) return;
    final imageUrl = stone.arTexture ?? stone.mainImageUrl ?? (stone.images.isNotEmpty ? stone.images.first : null);
    if (imageUrl == null || imageUrl.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _loadingSuggestion = stone.id);
    try {
      final bytes = await _loadImageBytes(imageUrl);
      if (!mounted) return;
      _loadingSuggestion = null;
      _setDesign(stone, imageUrl, bytes);
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${stone.name} selected. Tap Generate to see it in your room.',
              style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
          backgroundColor: const Color(0xFF1E1E22),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      debugPrint('[AIStudio] related stone load failed: $e');
      if (mounted) {
        setState(() => _loadingSuggestion = null);
        _showLoadError();
      }
    }
  }

  void _showLoadError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Could not load that stone. Check your connection and try again.',
            style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// "Size 490x195 mm, thickness 35 mm" from the catalogue, or null if unknown.
  String? _specFor(Stone stone) {
    final size = stone.size.trim();
    final thickness = stone.thickness.trim();
    if (size.isEmpty && thickness.isEmpty) return null;
    return [
      if (size.isNotEmpty) 'size $size',
      if (thickness.isNotEmpty) 'thickness $thickness',
    ].join(', ');
  }

  bool _needsLogin = false;

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
    // Renders need an account (credits are per user). Ask up front instead of running the progress
    // animation into a server 401 with no way to log in.
    if (!ref.read(authRiverpodProvider).isLoggedIn) {
      setState(() {
        _needsLogin = true;
        _error = 'Log in to create your AI render (free credits included).';
      });
      return;
    }
    HapticFeedback.heavyImpact();
    final watch = Stopwatch()..start();
    setState(() {
      _needsLogin = false;
      _generating = true;
      _genStartedAt = DateTime.now();
      _genStage = 0;
      _uploadFraction = null;
      _genDone = false;
      // A failed re-render must show its error, which lives on the photo slots view.
      _resultImage = null;
      _error = null;
      _statusNote = null;
      _showOriginal = false;
    });
    void stage(int s) {
      if (mounted && _generating && s > _genStage) setState(() => _genStage = s);
    }

    String? generatedB64;
    String statusNote = 'AI render';
    // Any failure ends here as a message: the screen never shows a stand-in image as the AI result.
    String? blockedMessage;
    // Set on a 402 (plan limit): the reason is shown and the paywall opens.
    String? limitReason;
    bool offerUpgrade = false;
    // Stage timings for device logs (ms since the tap; no user data).
    int? encodedAt, uploadedAt, firstByteAt;

    try {
      // Usually already done by _prewarm; otherwise both encode in parallel off the UI thread.
      final images = await Future.wait([
        _jpegFor(_roomBytes!, roomMaxSide),
        _jpegFor(_designBytes!, designMaxSide),
      ]);
      encodedAt = watch.elapsedMilliseconds;
      stage(1);

      final data = await AIEndpointClient.post(
        '/api/generate-visualization',
        {
          'image': images[0],
          'designImage': images[1],
          'stoneName': _preSelectedStoneName ?? 'Natural Stone',
          if (_preSelectedStoneSpec != null) 'designSpec': _preSelectedStoneSpec,
        },
        onSendProgress: (sent, total) {
          if (total <= 0 || !mounted || !_generating) return;
          final f = sent / total;
          if (f >= 1) {
            uploadedAt ??= watch.elapsedMilliseconds;
            stage(2);
          } else if (f - (_uploadFraction ?? 0) >= 0.05) {
            setState(() => _uploadFraction = f);
          }
        },
        // The endpoint answers only when the render is done, so the first byte marks server time.
        onReceiveProgress: (_, _) => firstByteAt ??= watch.elapsedMilliseconds,
      );

      final returnedImage = data['resultImage'] as String?;
      if (returnedImage != null && returnedImage.isNotEmpty) {
        generatedB64 = returnedImage;
        final left = data['creditsRemaining'];
        final today = data['dailyRemaining'];
        statusNote = left is int && today is int
            ? 'AI render • $left credits left ($today more today)'
            : 'AI render';
      } else {
        blockedMessage = 'The AI did not return an image. Please try another photo.';
      }
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      final body = e.response?.data;
      final serverMessage = body is Map && body['error'] is String ? body['error'] as String : null;
      if (body is Map && body['code'] == 'login_required') _needsLogin = true;
      if (code == 402) {
        limitReason = limitReachedMessage(body);
        offerUpgrade = limitReachedUsage(body)?.plan != 'pro';
      }
      blockedMessage = switch (code) {
        402 => limitReason,
        401 || 429 || 502 || 504 => serverMessage ?? 'AI render is unavailable right now. Please try again.',
        503 => 'AI Studio is not set up on the server yet. Please contact Grazia support.',
        413 => 'The photos are too large. Please use smaller images.',
        _ => e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout
            ? 'The AI render took too long. Please try again.'
            : 'Could not reach the AI service. Check your connection and try again.',
      };
      debugPrint('[AIStudio] generate-visualization failed ($code): ${e.type}');
    } catch (e) {
      blockedMessage = 'Could not generate the render. Please try again.';
      debugPrint('[AIStudio] generate-visualization failed: ${e.runtimeType}');
    }

    final totalMs = watch.elapsedMilliseconds;
    final up = uploadedAt ?? encodedAt;
    debugPrint('[AIStudio] timing encode=${encodedAt}ms '
        'upload=${up != null && encodedAt != null ? up - encodedAt : null}ms '
        'server=${firstByteAt != null && up != null ? firstByteAt! - up : null}ms '
        'download=${firstByteAt != null ? totalMs - firstByteAt! : null}ms '
        'total=${totalMs}ms ok=${generatedB64 != null}');

    if (!mounted) return;
    // Renders and refusals both change the counts on the usage chip.
    ref.invalidate(aiUsageProvider);

    if (generatedB64 == null) {
      setState(() {
        _generating = false;
        _error = blockedMessage ?? 'Could not generate preview. Please try another photo.';
      });
      if (limitReason != null && offerUpgrade) openPaywall(context, reason: limitReason);
      return;
    }

    RenderEta.record(totalMs).then((_) => RenderEta.estimateMs()).then((ms) => _estimateMs = ms);
    // A short "Ready" beat at 100% so the card does not just vanish.
    setState(() => _genDone = true);
    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    setState(() {
      _resultImage = generatedB64;
      _generating = false;
      _statusNote = statusNote;
    });
    // The haptic fires from _RenderReveal when the render lands.
    _scrollToResult();
  }

  void _openFullscreenViewer() {
    if (_resultImage == null) return;
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.96),
        pageBuilder: (context, _, _) {
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
    await saveRenderToGallery(context, _resultBytes);
  }

  // WhatsApp has no URL scheme that takes an image, so this opens the share sheet with the
  // watermarked file; WhatsApp is one tap there and keeps the caption.
  Future<void> _shareToWhatsApp() => _shareResult();

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



  Future<void> _shareResult() async {
    if (_resultImage == null) return;
    HapticFeedback.mediumImpact();
    await shareRender(context, _resultBytes);
  }

  void _showApiInfo() {
    final palette = ref.read(themePaletteProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _ApiArchitectureSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canGenerate = _roomBytes != null && _designBytes != null && !_generating;
    final palette = ref.watch(themePaletteProvider);
    final isDark = ref.watch(themePaletteProvider.notifier).isDarkMode;
    final accentGold = isDark ? const Color(0xFFD4AF37) : const Color(0xFF8B6B23);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.surface,
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
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: palette.textPrimary, size: 18),
        ),
        title: Text(
          'AI Room Studio',
          style: GoogleFonts.playfairDisplay(
            color: palette.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _showApiInfo,
            icon: Icon(Icons.info_outline_rounded, color: accentGold, size: 22),
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
              startedAt: _genStartedAt,
              estimateMs: _estimateMs,
              stage: _genStage,
              uploadFraction: _uploadFraction,
              done: _genDone,
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
                          color: accentGold.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.check_rounded, color: accentGold, size: 14),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_roomLabel ?? "Living Room"} • ${_preSelectedStoneName ?? "Stone Cladding"}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: palette.textPrimary,
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
                  icon: Icon(Icons.replay_rounded, size: 14, color: accentGold),
                  label: Text(
                    'Change Photos',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: accentGold,
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
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isDark ? const Color(0xFFD4AF37).withValues(alpha: 0.35) : palette.border,
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? const Color(0xFFD4AF37).withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
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
                                  color: palette.textPrimary,
                                ),
                              ),
                              if (_statusNote != null)
                                Text(
                                  _statusNote!,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: accentGold,
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
                          _RenderReveal(
                            key: ObjectKey(_resultBytes),
                            resultBytes: _resultBytes,
                            originalBytes: _roomBytes,
                            showOriginal: _showOriginal,
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
                                _showOriginal
                                    ? 'ORIGINAL ROOM'
                                    : (_preSelectedStoneName ?? 'NATURAL STONE').toUpperCase(),
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


                    // Matching Collections Recommendation Chip
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: palette.surfaceDark,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: palette.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.layers_outlined, color: accentGold, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Selected Stone Design:',
                                  style: GoogleFonts.inter(fontSize: 11, color: palette.textSecondary),
                                ),
                                Text(
                                  _preSelectedStoneName ?? 'Natural Architectural Stone',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: palette.textPrimary,
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
                            icon: Icon(Icons.download_rounded, size: 16, color: palette.textPrimary),
                            label: Text(
                              'Save',
                              style: GoogleFonts.inter(color: palette.textPrimary, fontWeight: FontWeight.w600, fontSize: 12),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: palette.border),
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
                            // Scales down instead of wrapping to "WhatsAp / p" on narrow phones.
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'WhatsApp',
                                maxLines: 1,
                                style: GoogleFonts.inter(color: const Color(0xFF25D366), fontWeight: FontWeight.w600, fontSize: 12),
                              ),
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
                            icon: const Icon(Icons.share_outlined, size: 16, color: Colors.white),
                            label: Text(
                              'Share',
                              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentGold,
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
                        final s = _selectedStone;
                        context.push(s == null ? '/sample-order' : '/sample-order?stoneId=${Uri.encodeComponent(s.id)}');
                      },
                      icon: Icon(Icons.shopping_bag_outlined, size: 16, color: accentGold),
                      label: Text(
                        'Order Free Physical Sample Tile',
                        style: GoogleFonts.inter(color: accentGold, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: accentGold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_selectedStone != null) _buildSuggestions(_selectedStone!, palette, accentGold),
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
                    color: palette.textSecondary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accentGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: accentGold.withValues(alpha: 0.35), width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_rounded, color: accentGold, size: 11),
                      const SizedBox(width: 4),
                      Text(
                        'AI GEN 2.5',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: accentGold,
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
              subtitle: _roomLabel ?? 'Upload or take photo of your room / wall',
              bytes: _roomBytes,
              onTap: () => _pick(true),
              palette: palette,
              isDark: isDark,
            ),
            const SizedBox(height: 14),

            // Slot 2: Your Design
            if (_loadingPreSelectedStone)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: accentGold),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Loading selected stone texture…',
                      style: GoogleFonts.inter(fontSize: 12, color: palette.textSecondary),
                    ),
                  ],
                ),
              ),
            _LuxuryImageSlot(
              stepNumber: '2',
              label: 'Your Design',
              subtitle: _preSelectedStoneName != null
                  ? '$_preSelectedStoneName — tap to switch'
                  : 'Select stone from catalogue or upload photo',
              bytes: _designBytes,
              onTap: () => _pick(false),
              palette: palette,
              isDark: isDark,
            ),
            const SizedBox(height: 24),

            // Plan usage; tap opens the paywall. Renders nothing for guests.
            const Align(alignment: Alignment.centerLeft, child: AiUsageChip()),
            const SizedBox(height: 10),

            // Generate Action Button
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: () {
                  if (canGenerate) {
                    _generate();
                  } else {
                    HapticFeedback.lightImpact();
                    String msg = 'Please upload your room photo and select a stone design';
                    if (_roomBytes == null && _designBytes != null) {
                      msg = 'Please upload or select your room / wall photo (Step 1)';
                    } else if (_roomBytes != null && _designBytes == null) {
                      msg = 'Please select a stone design (Step 2)';
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: Color(0xFFD4AF37), size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(msg, style: GoogleFonts.inter(color: Colors.white, fontSize: 13))),
                          ],
                        ),
                        backgroundColor: const Color(0xFF1E1E22),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: canGenerate ? accentGold : palette.surfaceDark,
                  foregroundColor: canGenerate ? Colors.white : palette.textTertiary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: canGenerate ? accentGold : palette.border,
                      width: 1,
                    ),
                  ),
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
                    if (_needsLogin)
                      TextButton(
                        onPressed: () {
                          final back = widget.preSelectedStoneId == null
                              ? '/ai-viz'
                              : '/ai-viz?stoneId=${Uri.encodeComponent(widget.preSelectedStoneId!)}'
                                  '${widget.preSelectedColour == null ? '' : '&colour=${widget.preSelectedColour}'}';
                          context.push('/login?redirect=${Uri.encodeComponent(back)}');
                        },
                        child: Text('Log in', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
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

  /// Under a render: the stone's other catalogue colours (tap = new render, same plan limits)
  /// and related stones (tap = select). Tinted so it reads apart from the result card.
  Widget _buildSuggestions(Stone stone, LuxuryPalette palette, Color accentGold) {
    final colours = stoneColours(stone);
    final related = relatedStones(stone, ref.watch(allStonesProvider).valueOrNull ?? const []);
    if (colours.isEmpty && related.isEmpty) return const SizedBox.shrink();

    Widget heading(IconData icon, String text) => Row(
          children: [
            Icon(icon, size: 16, color: accentGold),
            const SizedBox(width: 6),
            Text(
              text,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: palette.textPrimary),
            ),
          ],
        );

    Widget tile({
      required String key,
      required String? imageUrl,
      required String label,
      required bool selected,
      required bool loading,
      required VoidCallback? onTap,
      double size = 76,
    }) =>
        Semantics(
          button: true,
          selected: selected,
          label: label,
          child: GestureDetector(
            key: ValueKey(key),
            onTap: onTap,
            child: SizedBox(
              width: size,
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: selected ? accentGold : palette.border, width: selected ? 2.5 : 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          SmartStoneImage(imageUrl: imageUrl, localAsset: imageUrl, palette: palette),
                          if (loading)
                            Container(
                              color: Colors.black.withValues(alpha: 0.55),
                              alignment: Alignment.center,
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: accentGold),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? accentGold : palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

    final busy = _generating || _loadingSuggestion != null;
    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: accentGold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentGold.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (colours.isNotEmpty) ...[
            heading(Icons.palette_outlined, 'Try it in another colour'),
            const SizedBox(height: 10),
            SizedBox(
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: colours.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final c = colours[i];
                  final selected = c.imageUrl == _designUrl;
                  return tile(
                    key: 'colour-$i',
                    imageUrl: c.imageUrl,
                    label: c.label,
                    selected: selected,
                    loading: _loadingSuggestion == c.imageUrl,
                    onTap: selected || busy ? null : () => _renderColour(c),
                  );
                },
              ),
            ),
          ],
          if (colours.isNotEmpty && related.isNotEmpty) const SizedBox(height: 10),
          if (related.isNotEmpty) ...[
            heading(Icons.auto_awesome_outlined, 'You may also like'),
            const SizedBox(height: 10),
            SizedBox(
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: related.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final r = related[i];
                  return tile(
                    key: 'related-${r.id}',
                    imageUrl: r.imageUrl,
                    label: r.name,
                    selected: false,
                    loading: _loadingSuggestion == r.id,
                    onTap: busy ? null : () => _selectRelated(r),
                  );
                },
              ),
            ),
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
  final LuxuryPalette palette;
  final bool isDark;

  const _LuxuryImageSlot({
    required this.stepNumber,
    required this.label,
    required this.subtitle,
    required this.bytes,
    required this.onTap,
    required this.palette,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = bytes != null && bytes!.isNotEmpty;
    final accentGold = isDark ? const Color(0xFFD4AF37) : const Color(0xFF8B6B23);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 195,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: hasImage
                ? accentGold.withValues(alpha: 0.6)
                : palette.border,
            width: hasImage ? 1.4 : 1.0,
          ),
          color: palette.surface,
          image: hasImage
              ? DecorationImage(
                  image: MemoryImage(bytes!),
                  fit: BoxFit.cover,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
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
                      color: palette.surfaceDark,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: accentGold.withValues(alpha: 0.5),
                        width: 1.2,
                      ),
                    ),
                    child: Icon(
                      stepNumber == '1'
                          ? Icons.add_photo_alternate_outlined
                          : Icons.texture_rounded,
                      size: 26,
                      color: accentGold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Step $stepNumber: $label',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: palette.textPrimary,
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
                        color: palette.textSecondary,
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
                          color: palette.surfaceDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: palette.border),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.camera_alt_outlined, size: 12, color: accentGold),
                            const SizedBox(width: 4),
                            Text('Camera', style: GoogleFonts.inter(color: palette.textPrimary, fontSize: 11)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: palette.surfaceDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: palette.border),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.photo_library_outlined, size: 12, color: accentGold),
                            const SizedBox(width: 4),
                            Text('Gallery', style: GoogleFonts.inter(color: palette.textPrimary, fontSize: 11)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: palette.surfaceDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: palette.border),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.auto_awesome_rounded, size: 12, color: accentGold),
                            const SizedBox(width: 4),
                            Text('Presets', style: GoogleFonts.inter(color: palette.textPrimary, fontSize: 11)),
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

/// Bytes of a catalogue image: a network URL or a bundled asset path.
Future<Uint8List> _loadImageBytes(String url) async {
  if (url.startsWith('http://') || url.startsWith('https://')) {
    final response = await Dio().get<List<int>>(url, options: Options(responseType: ResponseType.bytes));
    return Uint8List.fromList(response.data!);
  }
  return (await rootBundle.load(url)).buffer.asUint8List();
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

      final bytes = await _loadImageBytes(imageUrl);

      if (!mounted) return;
      Navigator.pop(context, {
        'source': 'stone_model',
        'stone': stone,
        'bytes': bytes,
        'imageUrl': imageUrl,
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
    final palette = ref.watch(themePaletteProvider);
    final isDark = ref.watch(themePaletteProvider.notifier).isDarkMode;
    final accentGold = isDark ? const Color(0xFFD4AF37) : const Color(0xFF8B6B23);

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
                  color: palette.textTertiary.withValues(alpha: 0.3),
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
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.isRoom
                            ? 'Upload your wall or choose a showroom preset'
                            : 'Upload custom sample or pick from Grazia collection',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: palette.textSecondary),
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
                        color: palette.surfaceDark,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: palette.border),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: accentGold.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.camera_alt_rounded, color: accentGold, size: 24),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Take Photo',
                            style: GoogleFonts.inter(color: palette.textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.isRoom ? 'Snap your wall' : 'Snap stone sample',
                            style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 11),
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
                        color: palette.surfaceDark,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: palette.border),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: accentGold.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.photo_library_rounded, color: accentGold, size: 24),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Choose Gallery',
                            style: GoogleFonts.inter(color: palette.textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Upload from device',
                            style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 11),
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
                        color: palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 130,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: presets.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
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
                                color: palette.surfaceDark,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: palette.border),
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
                                            color: palette.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          p.subtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            color: palette.textSecondary,
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
                        'BROWSE CATALOGUE (35 SERIES):',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: palette.textSecondary,
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
                                  separatorBuilder: (_, _) => const SizedBox(width: 12),
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
                                          color: palette.surfaceDark,
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: isLoading
                                                ? accentGold
                                                : palette.border,
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
                                                      errorBuilder: (_, _, _) => Center(
                                                        child: Icon(Icons.broken_image_outlined,
                                                            color: palette.textTertiary),
                                                      ),
                                                    )
                                                  else
                                                    Center(
                                                      child: Icon(Icons.texture_rounded, color: palette.textTertiary),
                                                    ),
                                                  if (isLoading)
                                                    Container(
                                                      color: Colors.black.withValues(alpha: 0.6),
                                                      child: Center(
                                                        child: SizedBox(
                                                          width: 22,
                                                          height: 22,
                                                          child: CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color: accentGold,
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
                                                      color: palette.textPrimary,
                                                    ),
                                                  ),
                                                  Text(
                                                    stone.collection,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 10,
                                                      color: palette.textSecondary,
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
                            loading: () => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: accentGold,
                                  ),
                                ),
                              ),
                            ),
                            error: (_, _) => const SizedBox.shrink(),
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

class _ApiArchitectureSheet extends ConsumerWidget {
  const _ApiArchitectureSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(themePaletteProvider);
    final isDark = ref.watch(themePaletteProvider.notifier).isDarkMode;
    final accentGold = isDark ? const Color(0xFFD4AF37) : const Color(0xFF8B6B23);

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
                    color: palette.textPrimary,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: palette.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _infoItem(
              icon: Icons.cloud_done_outlined,
              title: 'Backend API Endpoint',
              description: 'https://grazia-stones.vercel.app/api/generate-visualization',
              palette: palette,
              accentGold: accentGold,
            ),
            const SizedBox(height: 12),
            _infoItem(
              icon: Icons.psychology_outlined,
              title: 'Primary AI Model & API Key',
              description:
                  'Google Gemini 2.5 Flash Image Generation.\nAPI Key: GEMINI_API_KEY (stored securely in backend environment).',
              palette: palette,
              accentGold: accentGold,
            ),
            const SizedBox(height: 12),
            _infoItem(
              icon: Icons.filter_center_focus_rounded,
              title: 'Room & Wall Vision Detection',
              description: 'NVIDIA NIM Vision (Llama 3.2 11B Vision Instruct) via /api/wall-detect.',
              palette: palette,
              accentGold: accentGold,
            ),
            const SizedBox(height: 12),
            _infoItem(
              icon: Icons.bolt_rounded,
              title: 'Offline / Hybrid Neural Engine',
              description:
                  'If Gemini rate limits or connection drops, Grazia GPU Compositor seamlessly renders realistic multi-shade wall claddings instantly without breaking.',
              palette: palette,
              accentGold: accentGold,
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
    required LuxuryPalette palette,
    required Color accentGold,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: accentGold.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: accentGold, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(color: palette.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Animated Neural Synthesis Screen matching User's Dot Matrix AI generation design (Screenshots 3 & 4)
/// Lands a fresh render over the room photo it came from: a soft diagonal wipe with a gold
/// leading edge, blur-to-sharp and a slight scale settle, then a haptic as it lands. Reduce
/// Motion shows the render at once. Afterwards it hosts the Compare (before/after) cross-fade.
class _RenderReveal extends StatefulWidget {
  final Uint8List resultBytes;
  final Uint8List? originalBytes;
  final bool showOriginal;

  const _RenderReveal({
    super.key,
    required this.resultBytes,
    required this.originalBytes,
    required this.showOriginal,
  });

  @override
  State<_RenderReveal> createState() => _RenderRevealState();
}

class _RenderRevealState extends State<_RenderReveal> with SingleTickerProviderStateMixin {
  static const _feather = 0.22;

  late final MemoryImage _render = MemoryImage(widget.resultBytes);
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final Animation<double> _t = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      HapticFeedback.mediumImpact();
      return;
    }
    // Decode first so the wipe never runs over an empty frame.
    precacheImage(_render, context).then((_) {
      if (!mounted) return;
      _controller.forward().then((_) {
        if (mounted) HapticFeedback.mediumImpact();
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final render = Image(image: _render, fit: BoxFit.cover, width: double.infinity, gaplessPlayback: true);
    return Stack(
      children: [
        // The room photo: what the render wipes over, and the Compare view afterwards.
        if (widget.originalBytes != null)
          Positioned.fill(
            child: Image.memory(widget.originalBytes!, fit: BoxFit.cover, gaplessPlayback: true),
          ),
        AnimatedOpacity(
          opacity: widget.showOriginal ? 0 : 1,
          duration: const Duration(milliseconds: 250),
          child: AnimatedBuilder(
            animation: _t,
            child: render,
            builder: (context, child) {
              final t = _t.value;
              if (t >= 1) return child!;
              final edge = t * (1 + _feather) - _feather;
              final sigma = 14 * (1 - t);
              return ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (rect) => LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: const [Colors.white, Colors.white, Colors.transparent, Colors.transparent],
                  stops: [0, edge.clamp(0.0, 1.0), (edge + _feather).clamp(0.0, 1.0), 1],
                ).createShader(rect),
                child: Transform.scale(
                  scale: 1.06 - 0.06 * t,
                  child: ImageFiltered(
                    enabled: sigma > 0.3,
                    imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                    child: child,
                  ),
                ),
              );
            },
          ),
        ),
        // Gold light riding the wipe front, fading out as the render settles.
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _t,
              builder: (context, _) {
                final t = _t.value;
                if (t <= 0 || t >= 1) return const SizedBox.shrink();
                final edge = t * (1 + _feather) - _feather;
                return DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.transparent,
                        const Color(0xFFF3D98B).withValues(alpha: 0.45 * (1 - t)),
                        Colors.transparent,
                      ],
                      stops: [
                        edge.clamp(0.0, 1.0),
                        (edge + _feather / 2).clamp(0.0, 1.0),
                        (edge + _feather).clamp(0.0, 1.0),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// The "Creating image" card: real stages, a countdown from the user's own recent render
/// times that switches to "Almost there…" instead of reaching 0, and the dot-matrix fill.
class _NeuralSynthesisWidget extends StatefulWidget {
  final DateTime startedAt;
  final int estimateMs;
  /// 0 preparing photos, 1 uploading, 2 designing (upload finished, waiting on the AI).
  final int stage;
  final double? uploadFraction;
  final bool done;

  const _NeuralSynthesisWidget({
    required this.startedAt,
    required this.estimateMs,
    required this.stage,
    required this.uploadFraction,
    required this.done,
  });

  @override
  State<_NeuralSynthesisWidget> createState() => _NeuralSynthesisWidgetState();
}

class _NeuralSynthesisWidgetState extends State<_NeuralSynthesisWidget>
    with SingleTickerProviderStateMixin {
  static const _steps = ['Upload', 'Design', 'Finish'];

  late AnimationController _waveController;
  // Refreshes the countdown and stage text; the wave controller drives per-frame motion.
  late final Timer _clock;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _clock = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduce Motion: hold the dots and the shimmer still; the countdown, bar and text still update.
    if (MediaQuery.disableAnimationsOf(context)) {
      _waveController.stop();
    } else if (!_waveController.isAnimating) {
      _waveController.repeat();
    }
  }

  @override
  void dispose() {
    _clock.cancel();
    _waveController.dispose();
    super.dispose();
  }

  int get _elapsedMs => DateTime.now().difference(widget.startedAt).inMilliseconds;

  double get _progress => widget.done ? 1 : RenderEta.progress(_elapsedMs, widget.estimateMs);

  /// 0 preparing, 1 uploading, 2 designing, 3 finishing (late in the wait), 4 ready.
  int get _displayStage {
    if (widget.done) return 4;
    if (widget.stage == 2 && _elapsedMs > widget.estimateMs * 0.7) return 3;
    return widget.stage;
  }

  String get _statusText => switch (_displayStage) {
        0 => 'Preparing your photos',
        1 => widget.uploadFraction == null
            ? 'Uploading photo'
            : 'Uploading photo · ${(widget.uploadFraction! * 100).round()}%',
        2 => 'Designing your wall',
        3 => 'Adding finishing light',
        _ => 'Ready',
      };

  String get _timeText {
    if (widget.done) return 'Done';
    final left = RenderEta.secondsLeft(_elapsedMs, widget.estimateMs);
    return left == null ? 'Almost there…' : '~$left s left';
  }

  @override
  Widget build(BuildContext context) {
    // Upload is step 0, design 1, finish 2 (preparing counts as upload).
    final activeStep = switch (_displayStage) { 0 || 1 => 0, 2 => 1, 3 => 2, _ => 3 };

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
          // Animated Dot Matrix Painter, filled by the estimated progress every frame.
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AnimatedBuilder(
                animation: _waveController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _DotMatrixPainter(
                      progress: _progress,
                      wavePhase: _waveController.value,
                    ),
                  );
                },
              ),
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
                    // Breathing "live" dot (still under Reduce Motion).
                    AnimatedBuilder(
                      animation: _waveController,
                      builder: (context, _) => Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: const Color(0xFF38BDF8).withValues(
                            alpha: 0.55 + 0.45 * math.sin(_waveController.value * math.pi),
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Semantics(
                  liveRegion: true,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _statusText,
                      key: ValueKey(_displayStage),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                AnimatedBuilder(
                  animation: _waveController,
                  builder: (context, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: _progress,
                      minHeight: 3,
                      backgroundColor: const Color(0xFF131B2E),
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF38BDF8)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (var i = 0; i < _steps.length; i++) ...[
                      if (i > 0)
                        Container(
                          width: 14,
                          height: 1,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          color: const Color(0xFF334155),
                        ),
                      Icon(
                        i < activeStep ? Icons.check_circle_rounded : Icons.circle,
                        size: i < activeStep ? 12 : 7,
                        color: i <= activeStep ? const Color(0xFF38BDF8) : const Color(0xFF334155),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _steps[i],
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: i == activeStep ? FontWeight.w700 : FontWeight.w500,
                          color: i <= activeStep ? Colors.white : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Time left pill on bottom right
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
                _timeText,
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
    final cellH = (size.height - 130) / (rows + 1);
    const startY = 104.0; // below the header, bar and steps

    final inactivePaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;

    // Soft light band sweeping across while the render is made (off-canvas when the wave is held).
    final sweepX = (wavePhase * 1.6 - 0.3) * size.width;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x00FFFFFF), Color(0x12FFFFFF), Color(0x00FFFFFF)],
        ).createShader(Rect.fromLTWH(sweepX - size.width * 0.25, 0, size.width * 0.5, size.height)),
    );

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
