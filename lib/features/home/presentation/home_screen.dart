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

  late PageController _heroPageController;
  Timer? _heroTimer;
  int _currentHeroIndex = 0;

  @override
  void initState() {
    super.initState();
    _heroPageController = PageController();
    _loadData();
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _heroPageController.dispose();
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
      
      final results = await Future.wait([
        stoneRepo.getTrendingStones(limit: 20),
        stoneRepo.getCollections(),
      ]);

      if (mounted) {
        setState(() {
          _trendingStones = results[0] as List<Stone>;
          _collections = results[1] as List<Collection>;
          _isLoading = false;
        });
        if (_trendingStones != null && _trendingStones!.isNotEmpty) {
          _startHeroTimer(_trendingStones!.length.clamp(1, 5));
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
      drawer: _buildLuxuryDrawer(context, palette),
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.menu_rounded, color: palette.textPrimary, size: 24),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        centerTitle: true,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'GRAZIA',
              style: GoogleFonts.playfairDisplay(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.5,
                color: const Color(0xFFD4AF37),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 14, height: 0.8, color: const Color(0xFFD4AF37)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Text(
                    'STONES',
                    style: GoogleFonts.inter(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.2,
                      color: const Color(0xFFD4AF37),
                    ),
                  ),
                ),
                Container(width: 14, height: 0.8, color: const Color(0xFFD4AF37)),
              ],
            ),
            Text(
              'UNIT OF BNK STONES',
              style: GoogleFonts.inter(
                fontSize: 6.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.4,
                color: palette.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            icon: Icon(Icons.search_rounded, color: palette.textPrimary, size: 21),
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            icon: Icon(Icons.notifications_outlined, color: palette.textPrimary, size: 21),
            onPressed: () => _showNotificationsSheet(context, palette),
          ),
          Consumer(
            builder: (context, ref, _) {
              final cart = ref.watch(cartProvider);
              final count = cart.fold<int>(0, (sum, i) => sum + i.quantity);
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    icon: Icon(Icons.shopping_bag_outlined, color: palette.textPrimary, size: 21),
                    onPressed: () => context.push('/cart'),
                  ),
                  if (count > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: palette.primary,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 6),
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
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      // 1. Editorial Hero Section
                      SliverToBoxAdapter(
                        child: FadeInStagger(
                          index: 0,
                          child: _buildEditorialHero(palette),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 18)),

                      // 2. Interactive Feature Hub (AR, AI Studio, Calculator, Samples)
                      SliverToBoxAdapter(
                        child: FadeInStagger(
                          index: 1,
                          child: _buildFeatureHub(palette),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 24)),

                      // 3. Curated Collections Gateway
                      SliverToBoxAdapter(
                        child: FadeInStagger(
                          index: 2,
                          child: _buildCollectionsHeader(palette),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 14)),

                      SliverToBoxAdapter(
                        child: FadeInStagger(
                          index: 3,
                          child: _buildCollectionsList(palette),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 28)),

                      // 4. Featured Masterpieces Section
                      SliverToBoxAdapter(
                        child: FadeInStagger(
                          index: 4,
                          child: _buildTrendingHeader(palette),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 14)),

                      SliverToBoxAdapter(
                        child: FadeInStagger(
                          index: 5,
                          child: _buildTrendingCarousel(palette),
                        ),
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

                      const SliverToBoxAdapter(child: SizedBox(height: 100)),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // ── 1. Auto-Looping Editorial Hero Carousel ──
  Widget _buildEditorialHero(LuxuryPalette palette) {
    final heroStones = (_trendingStones != null && _trendingStones!.isNotEmpty)
        ? _trendingStones!.take(5).toList()
        : <Stone>[];

    return Container(
      height: 270,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
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
            if (heroStones.isNotEmpty)
              PageView.builder(
                controller: _heroPageController,
                itemCount: heroStones.length,
                onPageChanged: (idx) {
                  setState(() => _currentHeroIndex = idx);
                },
                itemBuilder: (context, index) {
                  final stone = heroStones[index];
                  return Stack(
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
                              Colors.black.withValues(alpha: 0.20),
                              Colors.black.withValues(alpha: 0.65),
                              Colors.black.withValues(alpha: 0.95),
                            ],
                            stops: const [0.0, 0.45, 1.0],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Transform Walls.\nTransform Spaces.',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${stone.name} • ${stone.collection.toUpperCase()}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFFD4AF37),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                ApplePressable(
                                  onTap: () => context.push('/scan-space'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD4AF37),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.camera_alt_outlined, color: Colors.black, size: 14),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Scan My Wall',
                                          style: GoogleFonts.inter(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ApplePressable(
                                  onTap: () => context.push('/stones/${stone.id}'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.white38),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Explore Stone',
                                          style: GoogleFonts.inter(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 12),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              )
            else
              Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/hero_banner_1.png',
                    fit: BoxFit.cover,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.2),
                          Colors.black.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Transform Walls.\nTransform Spaces.',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Innovative Stone Panels for Extraordinary Spaces',
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

            // Top Right Dots Indicator Overlay
            if (heroStones.isNotEmpty)
              Positioned(
                top: 16,
                right: 16,
                child: Row(
                  children: List.generate(
                    heroStones.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      width: _currentHeroIndex == i ? 16 : 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: _currentHeroIndex == i
                            ? const Color(0xFFD4AF37)
                            : Colors.white.withValues(alpha: 0.4),
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

  // ── 2. Signature 2x2 Feature Grid (Client Reference Screen 3) ──
  Widget _buildFeatureHub(LuxuryPalette palette) {
    const cardBg = Color(0xFFFBF9F5);
    const borderColor = Color(0xFFE5DDD0);
    const titleColor = Color(0xFF141210);
    const subtitleColor = Color(0xFF6B655B);

    final items = [
      {
        'title': 'AI Design Studio',
        'subtitle': 'Visualize with AI',
        'icon': Icons.auto_awesome_rounded,
        'route': '/ai-studio',
      },
      {
        'title': 'Scan My Space',
        'subtitle': 'Measure with Camera',
        'icon': Icons.camera_alt_outlined,
        'route': '/scan-space',
      },
      {
        'title': 'VR Showroom',
        'subtitle': 'Explore in 3D',
        'icon': Icons.view_in_ar_rounded,
        'route': '/vr-showroom',
      },
      {
        'title': 'Explore Collections',
        'subtitle': 'Panels, Mosaics & More',
        'icon': Icons.grid_view_rounded,
        'route': '/collections',
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.50,
        ),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final item = items[i];
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              context.push(item['route'] as String);
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor, width: 1.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                        width: 0.8,
                      ),
                    ),
                    child: Icon(
                      item['icon'] as IconData,
                      size: 20,
                      color: const Color(0xFFD4AF37),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    item['title'] as String,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item['subtitle'] as String,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: subtitleColor,
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
    );
  }

  // ── Luxury Drawer (Matches Hamburger Menu) ──
  Widget _buildLuxuryDrawer(BuildContext context, LuxuryPalette palette) {
    return Drawer(
      backgroundColor: palette.background,
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Brand Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: palette.surface,
                border: Border(bottom: BorderSide(color: palette.border)),
              ),
              child: Row(
                children: [
                  const GraziaLogo(
                    variant: GraziaLogoVariant.emblem,
                    height: 38,
                    colorStyle: GraziaLogoColor.gold,
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GRAZIA STONES',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: const Color(0xFFD4AF37),
                        ),
                      ),
                      Text(
                        'UNIT OF BNK STONES',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.0,
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Navigation Links
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildDrawerItem(
                    context,
                    icon: Icons.auto_awesome_rounded,
                    title: 'AI Design Studio',
                    subtitle: 'Visualize with AI',
                    route: '/ai-studio',
                    palette: palette,
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.camera_alt_outlined,
                    title: 'Scan My Space',
                    subtitle: 'Measure wall with camera',
                    route: '/scan-space',
                    palette: palette,
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.view_in_ar_rounded,
                    title: 'VR Showroom',
                    subtitle: '360° virtual spaces',
                    route: '/vr-showroom',
                    palette: palette,
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.grid_view_rounded,
                    title: 'Collections',
                    subtitle: 'Panels, mosaics & art',
                    route: '/collections',
                    palette: palette,
                  ),
                  const Divider(height: 16),
                  _buildDrawerItem(
                    context,
                    icon: Icons.architecture_rounded,
                    title: 'Grazia Pro',
                    subtitle: 'For architects & designers',
                    route: '/pro',
                    palette: palette,
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.download_rounded,
                    title: 'Download Resources',
                    subtitle: 'CAD DWG files & textures',
                    route: '/resources',
                    palette: palette,
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.calculate_outlined,
                    title: 'Project Calculator',
                    subtitle: 'BOQ & area estimation',
                    route: '/boq-calculator',
                    palette: palette,
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.store_mall_directory_outlined,
                    title: 'Find a Dealer',
                    subtitle: 'Showrooms in Kanpur & global',
                    route: '/dealers',
                    palette: palette,
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.request_quote_outlined,
                    title: 'Request a Quotation',
                    subtitle: 'Custom project enquiry',
                    route: '/quotes/new',
                    palette: palette,
                  ),
                  const Divider(height: 16),
                  _buildDrawerItem(
                    context,
                    icon: Icons.info_outline_rounded,
                    title: 'About Grazia Stones',
                    subtitle: 'Brand heritage & craftsmanship',
                    route: '/about',
                    palette: palette,
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.support_agent_rounded,
                    title: 'Help & Concierge',
                    subtitle: '24/7 dedicated support',
                    route: '/support',
                    palette: palette,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
    required LuxuryPalette palette,
  }) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.border),
        ),
        child: Icon(icon, size: 18, color: const Color(0xFFD4AF37)),
      ),
      title: Text(
        title,
        style: GoogleFonts.playfairDisplay(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: palette.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.inter(
          fontSize: 10,
          color: palette.textSecondary,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12),
      onTap: () {
        Navigator.pop(context);
        context.push(route);
      },
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

  Widget _buildCollectionsList(LuxuryPalette palette) {
    final collections = _collections ?? [];
    if (collections.isEmpty) return const SizedBox.shrink();

    final displayCollections = collections.take(6).toList();
    final itemCount = displayCollections.length + 1;

    return SizedBox(
      height: 154,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (index == displayCollections.length) {
            return Container(
              width: 140,
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
              child: ApplePressable(
                onTap: () => context.push('/collections'),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: palette.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.grid_view_rounded, color: palette.primary, size: 20),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'All Collections',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '17 Series →',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: palette.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final col = displayCollections[index];
          final matchingStone = _trendingStones
              ?.where((s) =>
                  s.collection.toLowerCase().contains(col.name.toLowerCase()) ||
                  col.name.toLowerCase().contains(s.collection.toLowerCase()))
              .firstOrNull;

          return ApplePressable(
            onTap: () => context.push('/collections/${col.id}'),
            child: Container(
              width: 175,
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: palette.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    SmartStoneImage(
                      imageUrl: (col.imageUrl != null && col.imageUrl!.isNotEmpty)
                          ? col.imageUrl
                          : matchingStone?.imageUrl,
                      localAsset: (col.imageUrl == null || col.imageUrl!.isEmpty) &&
                              matchingStone?.imageUrl == null
                          ? 'assets/images/placeholder_stone.png'
                          : null,
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
                            Colors.black.withValues(alpha: 0.8),
                          ],
                          stops: const [0.2, 1.0],
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
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${col.stoneCount} Surfaces',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.85),
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

  Widget _buildTrendingCarousel(LuxuryPalette palette) {
    final allStones = _trendingStones ?? [];
    if (allStones.isEmpty) return const SizedBox.shrink();

    final displayStones = allStones.take(6).toList();
    final itemCount = displayStones.length + 1;

    return SizedBox(
      height: 295,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          if (index == displayStones.length) {
            return Container(
              width: 175,
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: palette.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ApplePressable(
                onTap: () => context.push('/catalogue'),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: palette.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.arrow_forward_rounded, color: palette.primary, size: 24),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Full Catalogue',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: palette.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Browse all 18+ surfaces →',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: palette.primary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          final stone = displayStones[index];
          final isWishlisted = ref.watch(
            wishlistProvider.select((w) => w.contains(stone.id)),
          );

          return ApplePressable(
            onTap: () => context.push('/stones/${stone.id}'),
            child: Container(
              width: 195,
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: palette.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(19),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
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
                                  Colors.black.withValues(alpha: 0.45),
                                ],
                                stops: const [0.55, 1.0],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: ApplePressable(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                ref
                                    .read(wishlistProvider.notifier)
                                    .toggleStone(stone.id);
                              },
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: palette.surface.withValues(alpha: 0.94),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.12),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  isWishlisted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                  size: 16,
                                  color: isWishlisted ? palette.primary : palette.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            left: 8,
                            child: ApplePressable(
                              onTap: () => context.push('/live-ai?stoneId=${stone.id}'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFFD4AF37).withValues(alpha: 0.6),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.view_in_ar_rounded, size: 13, color: Color(0xFFD4AF37)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'AR View',
                                      style: GoogleFonts.inter(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
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
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stone.name,
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
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
                              fontSize: 11,
                              color: palette.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '₹${stone.pricePerSqFt.toInt()}/sqft',
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: palette.primary,
                                ),
                              ),
                              Icon(Icons.arrow_forward_rounded, size: 14, color: palette.primary),
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
        },
      ),
    );
  }

  // ── 5. Architectural Portals (Catalogue, Experience Center, Custom Quotes) ──
  Widget _buildArchitecturalPortals(LuxuryPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ARCHITECTURAL SHOWROOM',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.0,
              color: palette.textTertiary,
            ),
          ),
          const SizedBox(height: 14),

          // Portal 1: Full Architectural Catalogue
          ApplePressable(
            onTap: () => context.push('/catalogue'),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: palette.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: palette.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.auto_stories_rounded, color: palette.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Full Architectural Catalogue',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: palette.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Explore all collections, finish types & technical specifications',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: palette.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: palette.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.arrow_forward_ios_rounded, size: 12, color: palette.primary),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Portal 2: Kanpur Experience Center & Dealer Network
          ApplePressable(
            onTap: () => context.push('/dealers'),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: palette.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: palette.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.storefront_rounded, color: palette.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kanpur Flagship & Dealer Network',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: palette.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '123/477 Kalpi Road, Fazalganj & verified regional partner showrooms',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: palette.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: palette.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.arrow_forward_ios_rounded, size: 12, color: palette.primary),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Portal 3: Custom Project Quotation & Doorstep Samples
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  palette.surface,
                  palette.surfaceDark,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: palette.primary.withValues(alpha: 0.25)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 14,
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
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: palette.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.request_quote_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Architectural Concierge',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: palette.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Certified estimates & physical sample swatches',
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
                Row(
                  children: [
                    Expanded(
                      child: ApplePressable(
                        onTap: () => context.push('/quotes'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            gradient: palette.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: palette.primary.withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              'Request Quote',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ApplePressable(
                        onTap: () => context.push('/sample-order'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: palette.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: palette.border, width: 1.1),
                          ),
                          child: Center(
                            child: Text(
                              'Order Swatches',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: palette.textPrimary,
                              ),
                            ),
                          ),
                        ),
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

  // ── 9. Official Brand & Kanpur Headquarters Signature ──
  Widget _buildBrandFooter(LuxuryPalette palette) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          const GraziaLogo(
            variant: GraziaLogoVariant.full,
            height: 48,
            colorStyle: GraziaLogoColor.gold,
            enableGlow: false,
          ),
          const SizedBox(height: 12),
          Text(
            'STONES THAT INSPIRE',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 4.0,
              color: palette.primary,
            ),
          ),
          const SizedBox(height: 14),
          Divider(color: palette.border, thickness: 0.8),
          const SizedBox(height: 14),
          // Interactive Head Office Address
          ApplePressable(
            onTap: () => _launchUrl('https://maps.google.com/?q=Fazalganj+Kanpur+123/477+Kalpi+Road'),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on_outlined, size: 16, color: palette.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Head Office: 123/477, Kalpi Road, Fazalganj, Kanpur, Uttar Pradesh',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: palette.textSecondary,
                      height: 1.4,
                      decoration: TextDecoration.underline,
                      decorationColor: palette.primary.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.open_in_new_rounded, size: 12, color: palette.primary),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Interactive Phone Contact
          ApplePressable(
            onTap: () => _launchUrl('tel:+919839846105'),
            child: Row(
              children: [
                Icon(Icons.phone_outlined, size: 16, color: palette.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '+91 9839846105 / 7518102550',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: palette.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: palette.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.call, size: 10, color: palette.primary),
                      const SizedBox(width: 3),
                      Text(
                        'Call',
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
          ),
          const SizedBox(height: 10),
          // Interactive Email Contact
          ApplePressable(
            onTap: () => _launchUrl('mailto:hello@graziastones.com'),
            child: Row(
              children: [
                Icon(Icons.mail_outline_rounded, size: 16, color: palette.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'hello@graziastones.com',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: palette.textSecondary,
                      decoration: TextDecoration.underline,
                      decorationColor: palette.primary.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: palette.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.mail, size: 10, color: palette.primary),
                      const SizedBox(width: 3),
                      Text(
                        'Email',
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
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              InkWell(
                onTap: () => context.push('/about'),
                child: Text(
                  'About Us',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: palette.primary,
                  ),
                ),
              ),
              Text('•', style: TextStyle(color: palette.textTertiary, fontSize: 11)),
              InkWell(
                onTap: () => context.push('/privacy'),
                child: Text(
                  'Privacy Policy',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: palette.textSecondary,
                  ),
                ),
              ),
              Text('•', style: TextStyle(color: palette.textTertiary, fontSize: 11)),
              InkWell(
                onTap: () => context.push('/terms'),
                child: Text(
                  'Terms of Service',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: palette.textSecondary,
                  ),
                ),
              ),
              Text('•', style: TextStyle(color: palette.textTertiary, fontSize: 11)),
              InkWell(
                onTap: () => context.push('/help'),
                child: Text(
                  'Help Desk',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: palette.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '© 2026 Grazia Stones Private Limited. All rights reserved.',
            style: GoogleFonts.inter(
              fontSize: 10,
              color: palette.textTertiary,
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

