import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/typography.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/shared/widgets/loading_skeleton.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/core/models/collection.dart';
import 'package:grazia_stones/core/widgets/animated_widgets.dart';
import 'package:grazia_stones/core/widgets/error_handler_widget.dart';
import 'package:grazia_stones/shared/widgets/grazia_logo.dart';
import 'package:grazia_stones/features/cart/presentation/cart_screen.dart';
import 'package:grazia_stones/core/repositories/notification_repository.dart';
import 'package:grazia_stones/core/services/storage_service.dart';
import 'package:grazia_stones/features/onboarding/presentation/widgets/app_interactive_tour_overlay.dart';
import 'package:grazia_stones/shared/widgets/grazia_bottom_nav.dart';
import 'package:grazia_stones/shared/widgets/smart_stone_image.dart';
import 'package:grazia_stones/core/providers/stone_providers.dart' show allStonesProvider;
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  List<Stone>? _trendingStones;
  List<Collection>? _collections;
  bool _isLoading = true;
  Object? _loadError;

  final GlobalKey _mayaBannerKey = GlobalKey();
  final GlobalKey _mayaAppBarKey = GlobalKey();

  late PageController _heroPageController;
  late final ScrollController _scrollController;
  Timer? _heroTimer;
  int _currentHeroIndex = 0;

  @override
  void initState() {
    super.initState();
    _heroPageController = PageController();
    _scrollController = ScrollController();
    _loadData();
  }

  void _launchInteractiveTour() {
    StorageService.instance.setHasSeenAppTour(true);
    debugPrint('🚀 [Tour] Launching interactive tour, marked as seen');
    final palette = ref.read(themePaletteProvider);
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'App Tour',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return AppInteractiveTourOverlay(
          palette: palette,
          mayaKey: _mayaAppBarKey,
          collectionsKey: GraziaBottomNav.collectionsKey,
          onDismiss: () {
            StorageService.instance.setHasSeenAppTour(true);
            Navigator.of(dialogContext, rootNavigator: true).pop();
          },
        );
      },
      transitionBuilder: (context, anim, secondaryAnim, child) {
        return FadeTransition(opacity: anim, child: child);
      },
    );
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _heroPageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startHeroTimer(int itemCount) {
    _heroTimer?.cancel();
    if (itemCount <= 1) return;
    _heroTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted || !_heroPageController.hasClients) return;
      final nextIndex = (_currentHeroIndex + 1) % itemCount;
      _heroPageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  Future<void> _launchUrl(String urlString) async {
    try {
      final uri = Uri.parse(urlString);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Could not launch url: $urlString, error: $e');
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final stoneRepo = ref.read(stoneRepositoryProvider);
      
      final trendingStones = await stoneRepo.getTrendingStones(limit: 30);
      final collections = await stoneRepo.getCollections();

      if (mounted) {
        setState(() {
          _trendingStones = trendingStones;
          _collections = collections;
          _isLoading = false;
        });
        debugPrint('🔍 Home screen loaded: ${_trendingStones?.length} stones, ${_collections?.length} collections');
        for (final c in _collections ?? []) {
          debugPrint('📂 COLLECTION: id=${c.id}, name=${c.name}');
        }
        if (_trendingStones != null && _trendingStones!.isNotEmpty) {
          _startHeroTimer(6);
        }
        if (!StorageService.instance.hasSeenAppTour() && ref.read(appLaunchCompleteProvider)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _launchInteractiveTour();
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Home screen error: $e');
      if (mounted) {
        setState(() {
          _loadError = e;
          _isLoading = false;
        });
        showErrorSnackbar(context, e, onRetry: _loadData);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);
    final isDark = ref.watch(themePaletteProvider.notifier).isDarkMode;
    final isLaunchComplete = ref.watch(appLaunchCompleteProvider);

    ref.listen<bool>(appLaunchCompleteProvider, (prev, isComplete) {
      if (isComplete && !StorageService.instance.hasSeenAppTour()) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _launchInteractiveTour();
        });
      }
    });

    final homeScaffold = Scaffold(
      backgroundColor: palette.background,
      drawerEnableOpenDragGesture: false,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 14,
        centerTitle: false,
        title: Opacity(
          opacity: isLaunchComplete ? 1.0 : 0.0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _launchInteractiveTour,
            onLongPress: () {
              HapticFeedback.heavyImpact();
              ref.read(appLaunchCompleteProvider.notifier).state = false;
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'assets/brand/grazia-emblem-gold.png',
                height: 22,
                width: 22,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'GRAZIA',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.8,
                          color: isDark ? const Color(0xFFD4AF37) : const Color(0xFF8B6B23),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'STONES',
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: isDark ? const Color(0xFFD4AF37) : const Color(0xFF8B6B23),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'UNIT OF BNK STONES',
                    style: GoogleFonts.inter(
                      fontSize: 7.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
          _buildMayaAppBarActionBtn(palette, isDark),
          _buildAppBarActionBtn(
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: palette.primary,
              size: 19,
            ),
            onTap: () {
              HapticFeedback.lightImpact();
              ref.read(themePaletteProvider.notifier).toggleTheme();
            },
            palette: palette,
          ),
          _buildAppBarActionBtn(
            icon: Icon(Icons.notifications_outlined, color: palette.textPrimary, size: 20),
            onTap: () => _showNotificationsSheet(context, palette),
            palette: palette,
          ),
          Consumer(
            builder: (context, ref, _) {
              final cart = ref.watch(cartProvider);
              final count = cart.fold<int>(0, (sum, i) => sum + i.quantity);
              return _buildAppBarActionBtn(
                icon: Icon(Icons.shopping_bag_outlined, color: palette.textPrimary, size: 20),
                onTap: () => context.push('/cart'),
                palette: palette,
                badge: count > 0
                    ? Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Color(0xFFD4AF37),
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : null,
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? _buildLoading(palette)
          : (_trendingStones == null && _collections == null)
              ? ErrorHandlerWidget(
                  error: _loadError ?? 'Unable to connect to catalogue service',
                  onRetry: _loadData,
                  palette: palette,
                )
              : RefreshIndicator(
              onRefresh: _loadData,
              color: palette.primary,
              backgroundColor: palette.surface,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      // 0. Architectural Luxury Search Bar
                      SliverToBoxAdapter(
                        child: FadeInStagger(
                          index: 0,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                            child: _buildLuxurySearchBar(palette, isDark),
                          ),
                        ),
                      ),

                      // 1. Editorial Hero Section
                      SliverToBoxAdapter(
                        child: FadeInStagger(
                          index: 1,
                          child: _buildEditorialHero(palette),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 16)),

                      // 1.2 Luxury Architectural Features Quick-Action Dock (AI Studio, AR, VR, Scan, Sample Kit)
                      SliverToBoxAdapter(
                        child: _buildFeaturesQuickDock(palette),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 16)),

                      // 1.5 Maya AI Interactive Architectural Consultation Bar
                      SliverToBoxAdapter(
                        child: _buildMayaAiBanner(palette),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 20)),

                      // 2. Architectural Portals (Catalogue, Kanpur Experience Center, Custom Quotes)
                      SliverToBoxAdapter(
                        child: FadeInStagger(
                          index: 1,
                          child: _buildArchitecturalPortals(palette),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 24)),

                      // 3. Refined Brand Signature
                      SliverToBoxAdapter(
                        child: FadeInStagger(
                          index: 2,
                          child: _buildBrandFooter(palette),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 150)),
                    ],
                  ),
                ),
              ),
            ),
    );

    return homeScaffold;
  }

  DateTime? _lastNavTime;
  void _openFeaturedStone({
    required String stoneId,
    required String collectionIdOrName,
  }) {
    final now = DateTime.now();
    if (_lastNavTime != null && now.difference(_lastNavTime!) < const Duration(milliseconds: 600)) {
      return;
    }
    _lastNavTime = now;
    HapticFeedback.lightImpact();
    context.push('/stones/$stoneId');
  }

  String? _findStoneImageUrl(String stoneId, {String? fallback}) {
    final allStones = ref.watch(allStonesProvider).value ?? _trendingStones;
    if (allStones != null) {
      for (final s in allStones) {
        if (s.id == stoneId) {
          final img = s.mainImageUrl ?? (s.images.isNotEmpty ? s.images.first : null);
          if (img != null && img.isNotEmpty) return img;
        }
      }
    }
    return fallback;
  }

  // ── 1. Auto-Looping Editorial Hero Carousel (Top Premium Stones & Signature Series) ──
  Widget _buildEditorialHero(LuxuryPalette palette) {
    final screenSize = MediaQuery.of(context).size;
    final heroHeight = (screenSize.height * 0.48).clamp(385.0, 420.0);

    final slides = <Widget>[
      // Slide 1: Turquoise Lava Panel (Exclusive Collection)
      _buildLuxuryEditorialSlide(
        badge: 'EXCLUSIVE COLLECTION',
        title: 'Turquoise Lava Panel',
        subtitle: 'Oxidized copper & turquoise patina composite metallic relief panel',
        imagePath: 'assets/images/hero_luxury_dining_fluted.jpg',
        networkImageUrl: _findStoneImageUrl(
          '736c7850-cf60-4345-ab1c-88e6812ea287',
          fallback: 'https://jrrmjtbauimrrxwjvmzh.supabase.co/storage/v1/object/public/stone-images/exclusive_collection/turquoise_lava_panel.jpg',
        ),
        ctaText: 'View Stone & Specs',
        onTap: () => _openFeaturedStone(
          stoneId: '736c7850-cf60-4345-ab1c-88e6812ea287',
          collectionIdOrName: 'Exclusive Collection',
        ),
      ),
      // Slide 2: Midnight Scallop Mosaic (Exclusive Collection)
      _buildLuxuryEditorialSlide(
        badge: 'EXCLUSIVE COLLECTION',
        title: 'Midnight Scallop Mosaic',
        subtitle: 'Handcrafted midnight brass scallop wall with architectural luster',
        imagePath: 'assets/images/auth_luxury_background.jpg',
        networkImageUrl: _findStoneImageUrl(
          '6f6bd01c-a23e-4912-8656-65717cdfae38',
          fallback: 'https://jrrmjtbauimrrxwjvmzh.supabase.co/storage/v1/object/public/stone-images/exclusive_collection/midnight_scallop_mosaic.jpg',
        ),
        ctaText: 'View Stone & Specs',
        onTap: () => _openFeaturedStone(
          stoneId: '6f6bd01c-a23e-4912-8656-65717cdfae38',
          collectionIdOrName: 'Exclusive Collection',
        ),
      ),
      // Slide 3: Turquoise Floral Heritage (Exclusive Collection)
      _buildLuxuryEditorialSlide(
        badge: 'EXCLUSIVE COLLECTION',
        title: 'Turquoise Floral Heritage',
        subtitle: 'Intricate handcrafted floral bas-relief panels in vintage turquoise brass',
        imagePath: 'assets/images/hero_luxury_bedroom.jpg',
        networkImageUrl: _findStoneImageUrl(
          '8c599c3a-d101-4618-a2a4-c566f6b8234b',
          fallback: 'https://jrrmjtbauimrrxwjvmzh.supabase.co/storage/v1/object/public/stone-images/exclusive_collection/turquoise_floral_heritage.jpg',
        ),
        ctaText: 'View Stone & Specs',
        onTap: () => _openFeaturedStone(
          stoneId: '8c599c3a-d101-4618-a2a4-c566f6b8234b',
          collectionIdOrName: 'Exclusive Collection',
        ),
      ),
      // Slide 4: Cosmic Flutes (Premium Surface Collection)
      _buildLuxuryEditorialSlide(
        badge: 'PREMIUM SURFACE',
        title: 'Cosmic Flutes',
        subtitle: 'Contemporary sculptural fluted panels with ambient architectural shadows',
        imagePath: 'assets/images/hero_luxury_dining_fluted.jpg',
        networkImageUrl: _findStoneImageUrl(
          '55427fc9-f86f-4c97-b955-fd42be60be7e',
        ),
        ctaText: 'View Stone & Specs',
        onTap: () => _openFeaturedStone(
          stoneId: '55427fc9-f86f-4c97-b955-fd42be60be7e',
          collectionIdOrName: 'Premium Surface Collection',
        ),
      ),
      // Slide 5: Grande Ledge Slate (Cultured Stone Series)
      _buildLuxuryEditorialSlide(
        badge: 'CULTURED STONE SERIES',
        title: 'Grande Ledge Series',
        subtitle: 'Deep textured natural split-face stone panels for luxury feature walls',
        imagePath: 'assets/images/hero_luxury_fireplace.jpg',
        networkImageUrl: _findStoneImageUrl(
          'bbf2cb9e-cae5-464e-984a-7cc2f61e7cd2',
        ),
        ctaText: 'View Stone & Specs',
        onTap: () => _openFeaturedStone(
          stoneId: 'bbf2cb9e-cae5-464e-984a-7cc2f61e7cd2',
          collectionIdOrName: 'Grande Ledge Series',
        ),
      ),
      // Slide 6: Pietra Luxe Panel (Premium Surface Collection)
      _buildLuxuryEditorialSlide(
        badge: 'PREMIUM SURFACE',
        title: 'Pietra Luxe Panel',
        subtitle: 'Architectural monolithic surface with timeless understated elegance',
        imagePath: 'assets/images/onboarding_hero_room.jpg',
        networkImageUrl: _findStoneImageUrl(
          'eacef3fe-34d2-4d6b-b86a-9803d97db55e',
        ),
        ctaText: 'View Stone & Specs',
        onTap: () => _openFeaturedStone(
          stoneId: 'eacef3fe-34d2-4d6b-b86a-9803d97db55e',
          collectionIdOrName: 'Premium Surface Collection',
        ),
      ),
    ];

    final isDark = ref.watch(themePaletteProvider.notifier).isDarkMode;

    return Container(
      height: heroHeight,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.10) : palette.border,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.45)
                : const Color(0xFF2C2416).withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
          if (isDark)
            BoxShadow(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.08),
              blurRadius: 20,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _heroPageController,
              itemCount: slides.length,
              onPageChanged: (idx) {
                setState(() => _currentHeroIndex = idx);
              },
              itemBuilder: (context, index) => slides[index],
            ),

            // Top Right Indicator Pill Overlay
            if (slides.length > 1)
              Positioned(
                top: 14,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.60),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '0${_currentHeroIndex + 1} ',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFD4AF37),
                        ),
                      ),
                      Text(
                        '/ 0${slides.length}',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white60,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Micro dots
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          slides.length,
                          (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            width: _currentHeroIndex == i ? 10 : 3.5,
                            height: 3.5,
                            decoration: BoxDecoration(
                              color: _currentHeroIndex == i
                                  ? const Color(0xFFD4AF37)
                                  : Colors.white.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
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

  Widget _buildLuxuryEditorialSlide({
    required String badge,
    required String title,
    required String subtitle,
    required String imagePath,
    String? networkImageUrl,
    required String ctaText,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          networkImageUrl != null && networkImageUrl.isNotEmpty
              ? SmartStoneImage(
                  imageUrl: networkImageUrl,
                  localAsset: imagePath,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                )
              : Image.asset(
                  imagePath,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
          // Luxury Architectural Cinematic Gradient Overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.40),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.35),
                  Colors.black.withValues(alpha: 0.82),
                  Colors.black.withValues(alpha: 0.95),
                ],
                stops: const [0.0, 0.22, 0.48, 0.76, 1.0],
              ),
            ),
          ),
          // Top Left Micro-Badge
          Positioned(
            top: 14,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.70),
                  width: 0.9,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: Color(0xFFD4AF37),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5.5),
                  Text(
                    badge,
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.3,
                      color: const Color(0xFFD4AF37),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Bottom Content & Editorial Details
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Small Gold Category Accent
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome, size: 10, color: Color(0xFFD4AF37)),
                    const SizedBox(width: 4),
                    Text(
                      'NATURAL ARCHITECTURAL STONE',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),

                // Main Title (Playfair Display)
                Text(
                  title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.15,
                    letterSpacing: 0.3,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.8),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // Subtitle Narrative
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFFE2DDD5),
                    height: 1.38,
                    letterSpacing: 0.15,
                  ),
                ),
                const SizedBox(height: 12),

                // Bottom Action Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Tap to view hint
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.touch_app_outlined, size: 11, color: Colors.white.withValues(alpha: 0.7)),
                          const SizedBox(width: 4),
                          Text(
                            'Tap to view stone & specs',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Gold Luxury CTA Pill Button
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            ctaText,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 13,
                            color: Colors.black,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }





  Widget _buildAppBarActionBtn({
    required Widget icon,
    required VoidCallback onTap,
    required LuxuryPalette palette,
    Widget? badge,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          color: palette.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: palette.border.withValues(alpha: 0.8),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            icon,
            ?badge,
          ],
        ),
      ),
    );
  }

  Widget _buildMayaAppBarActionBtn(LuxuryPalette palette, bool isDark) {
    return GestureDetector(
      key: _mayaAppBarKey,
      onTap: () {
        HapticFeedback.lightImpact();
        context.push('/maya-ai');
      },
      child: Container(
        width: 38,
        height: 38,
        margin: const EdgeInsets.only(right: 6),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFD4AF37),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withValues(alpha: isDark ? 0.35 : 0.25),
                    blurRadius: 8,
                    spreadRadius: 0.5,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/maya_avatar.jpg',
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Icon(
                    Icons.auto_awesome_rounded,
                    color: isDark ? const Color(0xFFD4AF37) : const Color(0xFF8B6B23),
                    size: 18,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 1,
              right: 1,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: palette.surface,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 0. Architectural Luxury Search Bar ──
  Widget _buildLuxurySearchBar(LuxuryPalette palette, bool isDark) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push('/search');
      },
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? const Color(0xFFD4AF37).withValues(alpha: 0.3)
                : palette.border,
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : const Color(0xFF2C2416).withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              color: isDark ? const Color(0xFFD4AF37) : const Color(0xFF8B6B23),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Search 35 collections, ledges, flutes, marble...',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: palette.textTertiary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (isDark ? const Color(0xFFD4AF37) : const Color(0xFF8B6B23))
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 13,
                    color: isDark ? const Color(0xFFD4AF37) : const Color(0xFF8B6B23),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Filter',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFD4AF37) : const Color(0xFF8B6B23),
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

  // ── 1.2 Luxury Architectural Features Quick-Action Dock (Unified Champagne Gold Theme) ──
  Widget _buildFeaturesQuickDock(LuxuryPalette palette) {
    final isDark = ref.watch(themePaletteProvider.notifier).isDarkMode;
    final goldAccent = isDark ? const Color(0xFFD4AF37) : const Color(0xFF8B6B23);
    final features = [
      {
        'title': 'AI Studio',
        'subtitle': '4K Wall Generator',
        'badge': 'AI 4K',
        'icon': Icons.auto_awesome_rounded,
        'route': '/ai-viz',
      },
      {
        'title': 'Live AR',
        'subtitle': 'True-Scale Wall View',
        'badge': '3D AR',
        'icon': Icons.view_in_ar_rounded,
        'route': '/live-ai',
      },
      {
        'title': 'Scan Space',
        'subtitle': 'Auto Dimension & BOQ',
        'badge': 'CAD / BOQ',
        'icon': Icons.straighten_rounded,
        'route': '/measure',
      },
      {
        'title': 'Tile Visualizer',
        'subtitle': '3D Wall & Layout Grid',
        'badge': '3D WALL',
        'icon': Icons.grid_goldenratio_rounded,
        'route': '/measure/tile-visualizer',
      },
      {
        'title': 'Sample Kit',
        'subtitle': 'Real Stone Box Delivery',
        'badge': 'BOX',
        'icon': Icons.inventory_2_outlined,
        'route': '/sample-order',
      },
      {
        'title': 'Bespoke Atelier',
        'subtitle': 'Custom CNC & Inlays',
        'badge': 'BESPOKE',
        'icon': Icons.architecture_rounded,
        'route': '/custom-design',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 3.5,
                    height: 13,
                    decoration: BoxDecoration(
                      color: goldAccent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ARCHITECTURAL SUITE',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                      color: goldAccent,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: goldAccent.withValues(alpha: isDark ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: goldAccent.withValues(alpha: isDark ? 0.35 : 0.25),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  '6 Interactive Tools',
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: goldAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 2-by-2 Paired Luxury Feature Cards (Unified Gold)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              // Pair 1: AI Studio & Live AR
              Row(
                children: [
                  Expanded(child: _buildLuxuryFeatureCard(features[0], goldAccent, palette, isDark)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildLuxuryFeatureCard(features[1], goldAccent, palette, isDark)),
                ],
              ),
              const SizedBox(height: 10),
              // Pair 2: Scan Space & Tile Visualizer
              Row(
                children: [
                  Expanded(child: _buildLuxuryFeatureCard(features[2], goldAccent, palette, isDark)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildLuxuryFeatureCard(features[3], goldAccent, palette, isDark)),
                ],
              ),
              const SizedBox(height: 10),
              // Pair 3: Sample Kit & Bespoke Atelier
              Row(
                children: [
                  Expanded(child: _buildLuxuryFeatureCard(features[4], goldAccent, palette, isDark)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildLuxuryFeatureCard(features[5], goldAccent, palette, isDark)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLuxuryFeatureCard(Map<String, dynamic> item, Color accent, LuxuryPalette palette, bool isDark) {
    return ApplePressable(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push(item['route'] as String);
      },
      child: Container(
        height: 116,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [
                    Color(0xFF1E1A14),
                    Color(0xFF12100C),
                  ]
                : const [
                    Color(0xFFFFFFFF),
                    Color(0xFFFAF9F6),
                  ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? accent.withValues(alpha: 0.28) : palette.border,
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.45)
                  : const Color(0xFF2C2416).withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
            if (isDark)
              BoxShadow(
                color: accent.withValues(alpha: 0.08),
                blurRadius: 16,
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Row: Big Glowing Icon Container + Badge & Arrow
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isDark ? 0.14 : 0.09),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: accent.withValues(alpha: isDark ? 0.45 : 0.25),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: isDark ? 0.12 : 0.06),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Icon(
                    item['icon'] as IconData,
                    size: 23,
                    color: accent,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: isDark ? 0.14 : 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: accent.withValues(alpha: isDark ? 0.40 : 0.22),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        item['badge'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: accent,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_outward_rounded,
                      size: 13,
                      color: accent.withValues(alpha: 0.75),
                    ),
                  ],
                ),
              ],
            ),
            // Bottom Details: Title & Subtitle
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item['title'] as String,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                    letterSpacing: 0.15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2.5),
                Text(
                  item['subtitle'] as String,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                    color: palette.textSecondary,
                    height: 1.15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMayaAiBanner(LuxuryPalette palette) {
    final isDark = ref.watch(themePaletteProvider.notifier).isDarkMode;
    return Container(
      key: _mayaBannerKey,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF1E1E22), Color(0xFF141416)]
              : const [Color(0xFFFFFFFF), Color(0xFFFBF8F2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFFD4AF37).withValues(alpha: 0.4) : palette.border,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? const Color(0xFFD4AF37).withValues(alpha: 0.08)
                : const Color(0xFF2C2416).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/maya-ai');
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Glowing Maya Avatar Character
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFD4AF37),
                          width: 1.6,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD4AF37).withValues(alpha: isDark ? 0.35 : 0.25),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/maya_avatar.jpg',
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.auto_awesome_rounded,
                            color: Color(0xFFD4AF37),
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF1E1E22) : Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),

                // Text Description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Maya AI Assistant',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: palette.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4AF37).withValues(alpha: isDark ? 0.2 : 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'HINDI / ENG',
                              style: GoogleFonts.inter(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFFD4AF37) : const Color(0xFF8B6B23),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Poochiye: Living room, exterior ya 3D stone design suggestions',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Pill Action Button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Chat',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.black),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 5. Architectural Portals (Catalogue, Experience Center, Custom Quotes) ──
  Widget _buildArchitecturalPortals(LuxuryPalette palette) {
    final isDark = ref.watch(themePaletteProvider.notifier).isDarkMode;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [


          // ── Luxury Collections Portal Banner (Switches directly to Collections tab) ──
          ApplePressable(
            onTap: () {
              HapticFeedback.mediumImpact();
              context.go('/collections');
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? const [
                          Color(0xFF22201C),
                          Color(0xFF141311),
                        ]
                      : const [
                          Color(0xFFFFFFFF),
                          Color(0xFFFAF7F0),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFFD4AF37).withValues(alpha: 0.40)
                      : const Color(0xFFD4AF37).withValues(alpha: 0.45),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.45)
                        : const Color(0xFF8B6B23).withValues(alpha: 0.08),
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4AF37).withValues(alpha: isDark ? 0.20 : 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFD4AF37).withValues(alpha: isDark ? 0.45 : 0.30),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.grid_view_rounded,
                              size: 12,
                              color: isDark ? const Color(0xFFD4AF37) : const Color(0xFF8B6B23),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '35 SIGNATURE COLLECTIONS',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: isDark ? const Color(0xFFD4AF37) : const Color(0xFF8B6B23),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : const Color(0xFFEFE9DC),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '100+ Surfaces',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFD4AF37) : const Color(0xFF8B6B23),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Explore All Collections',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: palette.textPrimary,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Browse cultured ledges, 3D fluted panels, antique bricks, and bespoke architectural stone series.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: palette.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 14,
                            color: isDark ? const Color(0xFFD4AF37) : const Color(0xFF8B6B23),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Curated Series Catalogue',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFD4AF37) : const Color(0xFF8B6B23),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE5C158), Color(0xFFC59B27)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFD4AF37).withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'View Collections',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 13,
                              color: Colors.black,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          ],
        ),
      );
    }

  // ── 9. Official Brand & Kanpur Headquarters Signature ──
  Widget _buildBrandFooter(LuxuryPalette palette) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          // Logo & tagline
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const GraziaLogo(
                variant: GraziaLogoVariant.emblem,
                height: 28,
                colorStyle: GraziaLogoColor.gold,
                enableGlow: false,
              ),
              const SizedBox(width: 8),
              Text(
                'STONES THAT INSPIRE',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3.0,
                  color: palette.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3 Compact 1-Tap Action Chips in a single clean row
          Row(
            children: [
              Expanded(
                child: ApplePressable(
                  onTap: () => _launchUrl('https://maps.google.com/?q=Fazalganj+Kanpur+123/477+Kalpi+Road'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                    decoration: BoxDecoration(
                      color: palette.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: palette.border, width: 0.8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_on_outlined, size: 13, color: palette.primary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Kanpur HQ',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: palette.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ApplePressable(
                  onTap: () => _launchUrl('tel:+919839846105'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                    decoration: BoxDecoration(
                      color: palette.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: palette.border, width: 0.8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.call_outlined, size: 13, color: palette.primary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Call Us',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: palette.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ApplePressable(
                  onTap: () => _launchUrl('mailto:hello@graziastones.com'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                    decoration: BoxDecoration(
                      color: palette.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: palette.border, width: 0.8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.mail_outline_rounded, size: 13, color: palette.primary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Email',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: palette.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Divider(color: palette.border, thickness: 0.6),
          const SizedBox(height: 10),

          // Policy Links Row
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 4,
            children: [
              InkWell(
                onTap: () => context.push('/about'),
                child: Text(
                  'About Us',
                  style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: palette.primary),
                ),
              ),
              Text('•', style: TextStyle(color: palette.textTertiary, fontSize: 10)),
              InkWell(
                onTap: () => context.push('/privacy'),
                child: Text(
                  'Privacy Policy',
                  style: GoogleFonts.inter(fontSize: 10.5, color: palette.textSecondary),
                ),
              ),
              Text('•', style: TextStyle(color: palette.textTertiary, fontSize: 10)),
              InkWell(
                onTap: () => context.push('/terms'),
                child: Text(
                  'Terms of Service',
                  style: GoogleFonts.inter(fontSize: 10.5, color: palette.textSecondary),
                ),
              ),
              Text('•', style: TextStyle(color: palette.textTertiary, fontSize: 10)),
              InkWell(
                onTap: () => context.push('/help'),
                child: Text(
                  'Help Desk',
                  style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: palette.primary),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Copyright
          Text(
            '© 2026 Grazia Stones Private Limited • Unit of BNK Stones',
            style: GoogleFonts.inter(
              fontSize: 9.5,
              color: palette.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 14),

          // BIG BOLD CAPITAL "GRAZIA STONES" at the very bottom
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'GRAZIA STONES',
              style: GoogleFonts.playfairDisplay(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: 6.0,
                color: const Color(0xFFD4AF37).withValues(alpha: 0.32),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildLoading(LuxuryPalette palette) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const LoadingSkeleton(width: double.infinity, height: 260, borderRadius: 20),
          const SizedBox(height: 16),
          const LoadingSkeleton(width: double.infinity, height: 80, borderRadius: 16),
          const SizedBox(height: 24),
          const LoadingSkeleton(width: 180, height: 20, borderRadius: 4),
          const SizedBox(height: 14),
          SizedBox(
            height: 240,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, _) => const LoadingSkeleton(width: 175, height: 240, borderRadius: 16),
            ),
          ),
        ],
      ),
    );
  }

  void _showNotificationsSheet(BuildContext context, LuxuryPalette palette) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.35,
        maxChildSize: 0.94,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: palette.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 28,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Drag handle
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: palette.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Header title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Notifications',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: palette.textPrimary,
                      ),
                    ),
                    FutureBuilder<int>(
                      future: notificationRepositoryProvider.getUnreadCount(),
                      builder: (context, snapshot) {
                        final unread = snapshot.data ?? 0;
                        if (unread == 0) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: GLuxuryPalettes.gold.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$unread New',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: GLuxuryPalettes.gold.primary,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),

              // Real notifications from Supabase — never fabricated
              Expanded(
                child: FutureBuilder<List<AppNotification>>(
                  future: notificationRepositoryProvider.getNotifications(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final notifications = snapshot.data ?? [];
                    if (notifications.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_none_rounded,
                                size: 44, color: palette.textTertiary),
                            const SizedBox(height: 12),
                            Text(
                              'No notifications yet',
                              style: GLuxuryTypography.bodyMedium.copyWith(
                                color: palette.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Order, quote and sample updates will appear here.',
                              style: GLuxuryTypography.bodySmall.copyWith(
                                color: palette.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(18),
                      itemCount: notifications.length,
                      itemBuilder: (context, index) {
                        final n = notifications[index];
                        final icon = switch (n.type) {
                          'order' => Icons.inventory_2_outlined,
                          'quote' => Icons.request_quote_outlined,
                          'sample' => Icons.inventory_outlined,
                          'success' => Icons.check_circle_outline,
                          'warning' => Icons.warning_amber_outlined,
                          _ => Icons.diamond_outlined,
                        };
                        final timeLabel = _formatNotificationTime(n.createdAt);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: palette.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: palette.border, width: 0.8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: GLuxuryPalettes.gold.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(icon, color: GLuxuryPalettes.gold.primary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            n.title,
                                            style: GLuxuryTypography.bodyMedium.copyWith(
                                              color: palette.textPrimary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          timeLabel,
                                          style: GoogleFonts.inter(
                                            fontSize: 10.5,
                                            color: palette.textTertiary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      n.body,
                                      style: GLuxuryTypography.bodySmall.copyWith(
                                        color: palette.textSecondary,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatNotificationTime(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }
}

