import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/typography.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/shared/widgets/smart_stone_image.dart';
import 'package:grazia_stones/shared/widgets/loading_skeleton.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/core/models/collection.dart';
import 'package:grazia_stones/core/widgets/animated_widgets.dart';
import 'package:grazia_stones/core/widgets/error_handler_widget.dart';
import 'package:grazia_stones/shared/widgets/grazia_logo.dart';
import 'package:grazia_stones/features/cart/presentation/cart_screen.dart';
import 'package:grazia_stones/features/wishlist/providers/wishlist_provider.dart';
import 'package:grazia_stones/core/repositories/notification_repository.dart';
import 'package:grazia_stones/core/services/storage_service.dart';
import 'package:grazia_stones/features/onboarding/presentation/widgets/app_interactive_tour_overlay.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  List<Stone>? _trendingStones;
  List<Collection>? _collections;
  Collection? _exclusiveCollection;
  Collection? _premiumSurfaceCollection;
  List<Stone>? _exclusiveStones;
  List<Stone>? _premiumSurfaceStones;
  bool _isLoading = true;
  Object? _loadError;

  final GlobalKey _firstArKey = GlobalKey();
  final GlobalKey _firstAddKey = GlobalKey();

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted && !StorageService.instance.hasSeenAppTour()) {
          _launchInteractiveTour();
        }
      });
    });
  }

  void _launchInteractiveTour() {
    debugPrint('🚀 [Tour] Launching interactive tour, hasSeen: ${StorageService.instance.hasSeenAppTour()}');
    final palette = ref.read(themePaletteProvider);
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'App Tour',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return AppInteractiveTourOverlay(
          palette: palette,
          arKey: _firstArKey,
          addKey: _firstAddKey,
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
      
      final trendingFuture = stoneRepo.getTrendingStones(limit: 30);
      final collectionsFuture = stoneRepo.getCollections();

      final initialResults = await Future.wait([
        trendingFuture,
        collectionsFuture,
      ]);

      final trendingStones = initialResults[0] as List<Stone>;
      final collections = initialResults[1] as List<Collection>;

      Collection? exclusiveCol;
      Collection? premiumSurfaceCol;
      for (final c in collections) {
        final name = c.name.toLowerCase();
        if (exclusiveCol == null && (name.contains('classic') || name.contains('grande') || name.contains('country'))) {
          exclusiveCol = c;
        }
        if (premiumSurfaceCol == null && (name.contains('3d') || name.contains('designer') || name.contains('verona') || name.contains('florentine') || name.contains('hexa'))) {
          premiumSurfaceCol = c;
        }
      }
      exclusiveCol ??= collections.isNotEmpty ? collections.first : null;
      premiumSurfaceCol ??= collections.length > 1 ? collections[1] : exclusiveCol;

      List<Stone> exclusiveStones = [];
      List<Stone> premiumSurfaceStones = [];

      if (exclusiveCol != null) {
        try {
          exclusiveStones = await stoneRepo.getStonesByCollection(exclusiveCol.id, limit: 12);
        } catch (_) {}
      }
      if (premiumSurfaceCol != null) {
        try {
          premiumSurfaceStones = await stoneRepo.getStonesByCollection(premiumSurfaceCol.id, limit: 12);
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _trendingStones = trendingStones;
          _collections = collections;
          _exclusiveCollection = exclusiveCol;
          _premiumSurfaceCollection = premiumSurfaceCol;
          _exclusiveStones = exclusiveStones.isNotEmpty ? exclusiveStones : trendingStones.skip(4).take(8).toList();
          _premiumSurfaceStones = premiumSurfaceStones.isNotEmpty ? premiumSurfaceStones : trendingStones.take(8).toList();
          _isLoading = false;
        });
        debugPrint('🔍 Home screen loaded: ${_trendingStones?.length} stones, ${_collections?.length} collections, ${_exclusiveStones?.length} exclusive, ${_premiumSurfaceStones?.length} premium surface');
        for (final c in _collections ?? []) {
          debugPrint('📂 COLLECTION: id=${c.id}, name=${c.name}');
        }
        if (_trendingStones != null && _trendingStones!.isNotEmpty) {
          _startHeroTimer(5);
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

    return Scaffold(
      backgroundColor: palette.background,
      drawerEnableOpenDragGesture: false,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'GRAZIA',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.2,
                    color: const Color(0xFFD4AF37),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'STONES',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                    color: const Color(0xFFD4AF37),
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
        actions: [
          _buildAppBarActionBtn(
            icon: Icon(Icons.explore_outlined, color: palette.primary, size: 20),
            onTap: () => _launchInteractiveTour(),
            palette: palette,
          ),
          _buildAppBarActionBtn(
            icon: Icon(Icons.search_rounded, color: palette.textPrimary, size: 20),
            onTap: () => context.push('/search'),
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
                      // 1. Editorial Hero Section
                      SliverToBoxAdapter(
                        child: FadeInStagger(
                          index: 0,
                          child: _buildEditorialHero(palette),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 14)),

                      // 2. Curated Collections Gateway (36 Series)
                      SliverToBoxAdapter(
                        child: FadeInStagger(
                          index: 1,
                          child: _buildCollectionsHeader(palette),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 12)),

                      _buildCollectionsSliverGrid(palette),

                      const SliverToBoxAdapter(child: SizedBox(height: 14)),

                      SliverToBoxAdapter(
                        child: _buildViewAllCollectionsButton(palette),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 24)),

                      // 3. Featured Masterpieces Section (VERTICAL 2-COLUMN LUXURY GRID)
                      SliverToBoxAdapter(
                        child: FadeInStagger(
                          index: 2,
                          child: _buildTrendingHeader(palette),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 12)),

                      _buildTrendingProductsSliver(palette),

                      const SliverToBoxAdapter(child: SizedBox(height: 14)),

                      SliverToBoxAdapter(
                        child: _buildViewAllCatalogueButton(palette),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 24)),

                      // 4. Exclusive Collection Section (4 Stone Items in 2x2 Grid)
                      SliverToBoxAdapter(
                        child: FadeInStagger(
                          index: 3,
                          child: _buildExclusiveHeader(palette),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 12)),

                      _buildExclusiveProductsSliver(palette),

                      const SliverToBoxAdapter(child: SizedBox(height: 14)),

                      SliverToBoxAdapter(
                        child: _buildViewAllExclusiveButton(palette),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 24)),

                      // 4B. Premium Surface Collection (4 Stone Items in 2x2 Grid)
                      SliverToBoxAdapter(
                        child: FadeInStagger(
                          index: 4,
                          child: _buildPremiumSurfaceHeader(palette),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 12)),

                      _buildPremiumSurfaceProductsSliver(palette),

                      const SliverToBoxAdapter(child: SizedBox(height: 14)),

                      SliverToBoxAdapter(
                        child: _buildViewAllPremiumSurfaceButton(palette),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 24)),

                      // 4C. Natural Stone Ledge Series (4 Stone Items in 2x2 Grid)
                      SliverToBoxAdapter(
                        child: FadeInStagger(
                          index: 5,
                          child: _buildArchitecturalLedgeHeader(palette),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 12)),

                      _buildArchitecturalLedgeProductsSliver(palette),

                      const SliverToBoxAdapter(child: SizedBox(height: 14)),

                      SliverToBoxAdapter(
                        child: _buildViewAllArchitecturalLedgeButton(palette),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 28)),

                      // 5. Architectural Portals (Catalogue, Kanpur Experience Center, Custom Quotes)
                      SliverToBoxAdapter(
                        child: FadeInStagger(
                          index: 6,
                          child: _buildArchitecturalPortals(palette),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 28)),

                      // 6. Refined Brand Signature
                      SliverToBoxAdapter(
                        child: FadeInStagger(
                          index: 7,
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
  }

  // ── 1. Auto-Looping Editorial Hero Carousel (Luxury Architectural Rooms & Designs) ──
  Widget _buildEditorialHero(LuxuryPalette palette) {
    final slides = <Widget>[
      // Slide 1: Luxury Master Bedroom Suite (Travertine Accent Wall)
      _buildLuxuryEditorialSlide(
        badge: 'MASTER BEDROOM SUITE',
        title: 'Travertine Accent Wall',
        subtitle: 'Textured stone headboard with ambient warm cove lighting',
        imagePath: 'assets/images/hero_luxury_bedroom.jpg',
        onTap: () => context.push('/custom-design'),
      ),
      // Slide 2: Penthouse Living Room & Fireplace (Charcoal Granite)
      _buildLuxuryEditorialSlide(
        badge: 'LIVING ROOM ARCHITECTURE',
        title: 'Charcoal Hearth & Lounge',
        subtitle: 'Dramatic split-face stone wall with vertical LED channels',
        imagePath: 'assets/images/hero_luxury_fireplace.jpg',
        onTap: () => context.push('/scan-space'),
      ),
      // Slide 3: Curved 3D Fluted Quartzite Dining & Bar
      _buildLuxuryEditorialSlide(
        badge: 'BESPOKE 3D FLUTED',
        title: 'Curved Dining Feature Wall',
        subtitle: '3D fluted quartzite stone with brushed brass metal inlays',
        imagePath: 'assets/images/hero_luxury_dining_fluted.jpg',
        onTap: () => context.push('/custom-design'),
      ),
      // Slide 4: Signature Grazia Living Lounge
      _buildLuxuryEditorialSlide(
        badge: 'SIGNATURE RESIDENCE',
        title: 'Transform Walls. Spaces.',
        subtitle: 'Innovative stone panels for extraordinary luxury interiors',
        imagePath: 'assets/images/home_hero_living_room.jpg',
        onTap: () => context.push('/catalogue'),
      ),
      // Slide 5: Modern Villa Residence
      _buildLuxuryEditorialSlide(
        badge: 'VILLA ARCHITECTURE',
        title: 'Bespoke Facades & Patios',
        subtitle: 'Handcrafted architectural natural stone crafted for generations',
        imagePath: 'assets/images/onboarding_hero_room.jpg',
        onTap: () => context.push('/custom-design'),
      ),
    ];

    return Container(
      height: 184,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
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

            // Top Right Dots Indicator Overlay
            if (slides.length > 1)
              Positioned(
                top: 14,
                right: 16,
                child: Row(
                  children: List.generate(
                    slides.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      width: _currentHeroIndex == i ? 16 : 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: _currentHeroIndex == i
                            ? const Color(0xFFD4AF37)
                            : Colors.white.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
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
          Image.asset(
            imagePath,
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          // Luxury Architectural Gradient Overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.35),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.45),
                  Colors.black.withValues(alpha: 0.92),
                ],
                stops: const [0.0, 0.25, 0.55, 1.0],
              ),
            ),
          ),
          // Top Left Micro-Badge
          Positioned(
            top: 13,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.6),
                  width: 0.8,
                ),
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
                  const SizedBox(width: 5),
                  Text(
                    badge,
                    style: GoogleFonts.inter(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: const Color(0xFFD4AF37),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Bottom Content
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.15,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withValues(alpha: 0.85),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Explore',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFD4AF37),
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 9,
                          color: Color(0xFFD4AF37),
                        ),
                      ],
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

  // ── 3. Curated Collections Gateway ──
  Widget _buildCollectionsHeader(LuxuryPalette palette) {
    final count = _collections?.length ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                'CURATED COLLECTIONS',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                  color: palette.textTertiary,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: palette.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count Series',
                    style: GoogleFonts.inter(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: palette.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          ApplePressable(
            onTap: () => context.push('/collections'),
            child: Row(
              children: [
                Text(
                  'Explore All',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: palette.primary,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.arrow_forward_ios_rounded, size: 11, color: palette.primary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionsSliverGrid(LuxuryPalette palette) {
    final collections = _collections ?? [];
    if (collections.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    // Show 8 prominent curated collections in a 2x4 luxury grid
    final displayCollections = collections.take(8).toList();

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.05,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final col = displayCollections[index];
            return _buildCollectionCard(col, palette);
          },
          childCount: displayCollections.length,
        ),
      ),
    );
  }

  Widget _buildCollectionCard(Collection col, LuxuryPalette palette) {
    final matchingStone = _trendingStones
        ?.where((s) =>
            s.collection.toLowerCase().contains(col.name.toLowerCase()) ||
            col.name.toLowerCase().contains(s.collection.toLowerCase()))
        .firstOrNull;

    return ApplePressable(
      onTap: () => context.push('/collections/${col.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Stack(
            fit: StackFit.expand,
            children: [
              SmartStoneImage(
                imageUrl: col.effectiveBannerImage,
                fit: BoxFit.cover,
                palette: palette,
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.35),
                      Colors.black.withValues(alpha: 0.90),
                    ],
                    stops: const [0.15, 0.55, 1.0],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      col.name,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          '${col.stoneCount} Surfaces',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 9,
                            color: Color(0xFFD4AF37),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewAllCollectionsButton(LuxuryPalette palette) {
    final count = _collections?.length ?? 36;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ApplePressable(
        onTap: () => context.push('/collections'),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Explore All $count+ Series & Finishes',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFD4AF37),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 15,
                color: Color(0xFFD4AF37),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 4. Featured Masterpieces Section ──
  Widget _buildTrendingHeader(LuxuryPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'FEATURED MASTERPIECES',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.0,
              color: palette.textTertiary,
            ),
          ),
          ApplePressable(
            onTap: () => context.push('/catalogue'),
            child: Row(
              children: [
                Text(
                  'Full Catalogue',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: palette.primary,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.arrow_forward_ios_rounded, size: 11, color: palette.primary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExclusiveHeader(LuxuryPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                'EXCLUSIVE COLLECTION',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                  color: palette.textTertiary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Signature',
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFD4AF37),
                  ),
                ),
              ),
            ],
          ),
          ApplePressable(
            onTap: () => context.push('/collections/${_exclusiveCollection?.id ?? "classic-ledge-series"}'),
            child: Row(
              children: [
                Text(
                  'View All',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: palette.primary,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.arrow_forward_ios_rounded, size: 11, color: palette.primary),
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
        width: 38,
        height: 38,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: palette.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: palette.border.withValues(alpha: 0.8),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
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

  Widget _buildTrendingProductsSliver(LuxuryPalette palette) {
    final allStones = _trendingStones ?? [];
    if (allStones.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final displayStones = allStones.take(8).toList();

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.70,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final stone = displayStones[index];
            return _buildProductCard(
              stone,
              palette,
              arKey: index == 0 ? _firstArKey : null,
              addKey: index == 0 ? _firstAddKey : null,
            );
          },
          childCount: displayStones.length,
        ),
      ),
    );
  }

  Widget _buildExclusiveProductsSliver(LuxuryPalette palette) {
    final exclusive = _exclusiveStones ?? [];
    final displayStones = exclusive.isNotEmpty
        ? exclusive.take(8).toList()
        : (_trendingStones != null && _trendingStones!.length > 8
            ? _trendingStones!.skip(8).take(8).toList()
            : <Stone>[]);

    if (displayStones.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.70,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final stone = displayStones[index];
            return _buildProductCard(stone, palette);
          },
          childCount: displayStones.length,
        ),
      ),
    );
  }

  // ── 4B. Premium Surface Collection (4 Items in 2x2 Grid) ──
  Widget _buildPremiumSurfaceHeader(LuxuryPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    'PREMIUM SURFACES',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.8,
                      color: palette.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '3D Relief',
                    style: GoogleFonts.inter(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFD4AF37),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ApplePressable(
            onTap: () => context.push('/collections/${_premiumSurfaceCollection?.id ?? "designer-3d-collection"}'),
            child: Row(
              children: [
                Text(
                  'View All',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: palette.primary,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.arrow_forward_ios_rounded, size: 11, color: palette.primary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumSurfaceProductsSliver(LuxuryPalette palette) {
    final premium = _premiumSurfaceStones ?? [];
    final displayStones = premium.isNotEmpty
        ? premium.take(8).toList()
        : (_trendingStones != null && _trendingStones!.length > 16
            ? _trendingStones!.skip(16).take(8).toList()
            : <Stone>[]);

    if (displayStones.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.70,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final stone = displayStones[index];
            return _buildProductCard(stone, palette);
          },
          childCount: displayStones.length,
        ),
      ),
    );
  }

  // ── 4C. Architectural Ledge & Wall Series (8 Items in 2x4 Grid) ──
  Widget _buildArchitecturalLedgeHeader(LuxuryPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    'NATURAL STONE LEDGE',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.8,
                      color: palette.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Authentic',
                    style: GoogleFonts.inter(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFD4AF37),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ApplePressable(
            onTap: () => context.push('/catalogue'),
            child: Row(
              children: [
                Text(
                  'View All',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: palette.primary,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.arrow_forward_ios_rounded, size: 11, color: palette.primary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArchitecturalLedgeProductsSliver(LuxuryPalette palette) {
    final allStones = _trendingStones ?? [];
    // Skip first 8 (shown in Featured Masterpieces), take next 8
    final displayStones = allStones.length > 8 ? allStones.skip(8).take(8).toList() : allStones.take(8).toList();

    if (displayStones.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.70,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final stone = displayStones[index];
            return _buildProductCard(stone, palette);
          },
          childCount: displayStones.length,
        ),
      ),
    );
  }

  Widget _buildProductCard(
    Stone stone,
    LuxuryPalette palette, {
    Key? arKey,
    Key? addKey,
  }) {
    final isWishlisted = ref.watch(
      wishlistProvider.select((w) => w.contains(stone.id)),
    );

    return ApplePressable(
      onTap: () => context.push('/stones/${stone.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: palette.border, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 11,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    SmartStoneImage(
                      imageUrl: stone.imageUrl,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      palette: palette,
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.50),
                          ],
                          stops: const [0.55, 1.0],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 7,
                      right: 7,
                      child: ApplePressable(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          ref
                              .read(wishlistProvider.notifier)
                              .toggleStone(stone.id);
                        },
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: palette.surface.withValues(alpha: 0.92),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Icon(
                            isWishlisted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            size: 15,
                            color: isWishlisted ? palette.primary : palette.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 7,
                      left: 7,
                      child: ApplePressable(
                        onTap: () => context.push('/live-ai?stoneId=${stone.id}'),
                        child: Container(
                          key: arKey,
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFD4AF37).withValues(alpha: 0.7),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.view_in_ar_rounded, size: 11, color: Color(0xFFD4AF37)),
                              const SizedBox(width: 3),
                              Text(
                                'AR',
                                style: GoogleFonts.inter(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 7,
                      right: 7,
                      child: ApplePressable(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          ref.read(cartProvider.notifier).addItem(
                            stone,
                            quantity: 1,
                          );
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${stone.name} added to cart',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                              backgroundColor: const Color(0xFFD4AF37),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: Container(
                          key: addKey,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.shopping_bag_outlined, size: 10, color: Colors.black),
                              const SizedBox(width: 3),
                              Text(
                                '+ Add',
                                style: GoogleFonts.inter(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      stone.name,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stone.collection,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: palette.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₹${stone.pricePerSqFt.toInt()}/sqft',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: palette.primary,
                          ),
                        ),
                        Icon(Icons.arrow_forward_rounded, size: 13, color: palette.primary),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewAllCatalogueButton(LuxuryPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ApplePressable(
        onTap: () => context.push('/catalogue'),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Explore All 20+ Masterpieces in Catalogue',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFD4AF37),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 15,
                color: Color(0xFFD4AF37),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewAllExclusiveButton(LuxuryPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ApplePressable(
        onTap: () => context.push('/collections/${_exclusiveCollection?.id ?? "classic-ledge-series"}'),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Explore Exclusive Collection',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFD4AF37),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 15,
                color: Color(0xFFD4AF37),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewAllPremiumSurfaceButton(LuxuryPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ApplePressable(
        onTap: () => context.push('/collections/${_premiumSurfaceCollection?.id ?? "designer-3d-collection"}'),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Explore All Premium Surface Designs',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFD4AF37),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 15,
                color: Color(0xFFD4AF37),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewAllArchitecturalLedgeButton(LuxuryPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ApplePressable(
        onTap: () => context.push('/catalogue'),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Explore Natural Stone Ledge & Wall Series',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFD4AF37),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 15,
                color: Color(0xFFD4AF37),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 5. Architectural Portals (Catalogue, Experience Center, Custom Quotes) ──
  Widget _buildArchitecturalPortals(LuxuryPalette palette) {
    final allStones = _trendingStones ?? [];
    final archStones = allStones.length > 16
        ? allStones.skip(16).take(8).toList()
        : (allStones.length > 8 ? allStones.skip(8).take(8).toList() : allStones.take(8).toList());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ARCHITECTURAL CATALOGUE',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                  color: palette.textTertiary,
                ),
              ),
              InkWell(
                onTap: () => context.push('/catalogue'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '100+ SURFACES',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: palette.primary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded, size: 14, color: palette.primary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2x2 Grid of 4 Architectural Stone Products (with Image, Price, AR, + Add)
          if (archStones.isNotEmpty) ...[
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: archStones.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.70,
              ),
              itemBuilder: (context, index) {
                return _buildProductCard(archStones[index], palette);
              },
            ),
            const SizedBox(height: 14),

            // Button to Explore Full Architectural Catalogue
            ApplePressable(
              onTap: () => context.push('/catalogue'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: palette.primary.withValues(alpha: 0.35)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_stories_rounded, size: 16, color: palette.primary),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Explore Architectural Catalogue (100+ Stones)',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.arrow_forward_rounded, size: 14, color: palette.primary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Bespoke Custom Stone Studio Card
            ApplePressable(
              onTap: () => context.push('/custom-design'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF1E1C18),
                      Color(0xFF141310),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.5), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.architecture_rounded, color: Color(0xFFD4AF37), size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'BESPOKE CUSTOM DESIGN STUDIO',
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.6,
                                  color: const Color(0xFFD4AF37),
                                ),
                              ),
                              Text(
                                '3D Pattern & CNC Carved Stone',
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Design custom fluted wall panels, bookmatched slabs, and hexagonal patterns tailored to your wall dimensions with instant budget estimates.',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: Colors.white.withValues(alpha: 0.75),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.touch_app_rounded, size: 14, color: Color(0xFFD4AF37)),
                            const SizedBox(width: 4),
                            Text(
                              'Interactive 3D Preview',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFD4AF37)),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Open Studio',
                                style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.black),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward_rounded, size: 13, color: Colors.black),
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

