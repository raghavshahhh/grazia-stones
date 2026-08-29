import 'package:flutter/material.dart';
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

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  List<Stone>? _trendingStones;
  List<Collection>? _collections;
  final Set<String> _wishlistedIds = {};
  String _selectedCategory = 'All';
  bool _isLoading = true;

  final List<String> _categories = [
    'All',
    'Ledge Stone',
    'Cultured Stone',
    'Rustic Brick',
    'Designer 3D',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
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
      }
    } catch (e) {
      debugPrint('❌ Home screen error: $e');
      if (mounted) {
        setState(() {
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
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GraziaLogo(variant: GraziaLogoVariant.emblem, height: 28),
            const SizedBox(width: 10),
            Text(
              'GRAZIA STONES',
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 3.5,
                color: palette.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search_rounded, color: palette.textPrimary, size: 22),
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: palette.textPrimary, size: 22),
            onPressed: () => _showNotificationsSheet(context, palette),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? _buildLoading(palette)
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

                      // 3. Category Filter Chips
                      SliverToBoxAdapter(
                        child: FadeInStagger(
                          index: 2,
                          child: _buildCategoryChips(palette),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 18)),

                      // 4. Trending Stones Section
                      SliverToBoxAdapter(
                        child: FadeInStagger(
                          index: 3,
                          child: _buildTrendingHeader(palette),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 14)),

                      SliverToBoxAdapter(
                        child: FadeInStagger(
                          index: 4,
                          child: _buildTrendingCarousel(palette),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 30)),

                      // 5. Curated Collections
                      SliverToBoxAdapter(
                        child: FadeInStagger(
                          index: 5,
                          child: _buildCollectionsHeader(palette),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 14)),

                      SliverToBoxAdapter(
                        child: FadeInStagger(
                          index: 6,
                          child: _buildCollectionsList(palette),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 28)),

                      // 5B. Full Architectural Product Grid
                      SliverToBoxAdapter(
                        child: FadeInStagger(
                          index: 7,
                          child: _buildAllProductsHeader(palette),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 14)),

                      SliverToBoxAdapter(
                        child: FadeInStagger(
                          index: 8,
                          child: _buildAllProductsGrid(palette),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 30)),

                      // 6. Room Upload AI Visualization Card
                      SliverToBoxAdapter(
                        child: FadeInStagger(
                          index: 9,
                          child: _buildAIStudioPromoCard(palette),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 32)),

                      // 7. Why Grazia Stones (4 Pillars)
                      SliverToBoxAdapter(
                        child: FadeInStagger(
                          index: 8,
                          child: _buildWhyGraziaPillars(palette),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 30)),

                      // 8. Architectural Consultation / Dealer CTA
                      SliverToBoxAdapter(
                        child: FadeInStagger(
                          index: 9,
                          child: _buildConsultationCTA(palette),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 30)),

                      // 9. Official Brand & Kanpur Headquarters Signature
                      SliverToBoxAdapter(
                        child: FadeInStagger(
                          index: 10,
                          child: _buildBrandFooter(palette),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 140)),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // ── 1. Editorial Hero ──
  Widget _buildEditorialHero(LuxuryPalette palette) {
    final heroStone = (_trendingStones != null && _trendingStones!.isNotEmpty)
        ? _trendingStones!.first
        : null;

    return Container(
      height: 280,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            SmartStoneImage(
              imageUrl: heroStone?.imageUrl,
              fit: BoxFit.cover,
              palette: palette,
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    Colors.black.withValues(alpha: 0.65),
                    Colors.black.withValues(alpha: 0.95),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Gold badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const GraziaLogo(
                          variant: GraziaLogoVariant.emblem,
                          height: 14,
                          colorStyle: GraziaLogoColor.gold,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '2025 ARCHITECTURAL CATALOGUE',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.0,
                            color: const Color(0xFFD4AF37),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    'Natural Stone.\nDesigned for Living.',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Discover architectural surfaces that transform spaces.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ApplePressable(
                        onTap: () => context.push('/live-ai'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: palette.primaryGradient,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: palette.primary.withValues(alpha: 0.45),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.view_in_ar_rounded, color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Visualize in AR',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ApplePressable(
                        onTap: () => context.push('/collections'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Explore Stones',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 14),
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
        ),
      ),
    );
  }

  // ── 2. Feature Hub (AR, AI Studio, Measure, Samples) ──
  Widget _buildFeatureHub(LuxuryPalette palette) {
    final features = [
      {
        'icon': Icons.view_in_ar_rounded,
        'label': 'Live AR Wall',
        'sub': 'Real-time Camera',
        'route': '/live-ai',
        'highlight': true,
      },
      {
        'icon': Icons.auto_awesome_rounded,
        'label': 'AI Studio',
        'sub': 'Photo Visualizer',
        'route': '/ai-viz',
        'highlight': false,
      },
      {
        'icon': Icons.architecture_rounded,
        'label': '3D Wall Calc',
        'sub': 'Proportional 3D',
        'route': '/measure',
        'highlight': false,
      },
      {
        'icon': Icons.inventory_2_outlined,
        'label': 'Sample Box',
        'sub': 'Order Swatches',
        'route': '/sample-order',
        'highlight': false,
      },
    ];

    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: features.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final f = features[index];
          final isHighlight = f['highlight'] as bool;

          return ApplePressable(
            onTap: () => context.push(f['route'] as String),
            child: Container(
              width: 158,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isHighlight
                      ? palette.primary.withValues(alpha: 0.5)
                      : palette.border,
                  width: isHighlight ? 1.2 : 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isHighlight
                        ? palette.primary.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.02),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: isHighlight
                          ? palette.primaryGradient
                          : LinearGradient(
                              colors: [
                                palette.primary.withValues(alpha: 0.15),
                                palette.primary.withValues(alpha: 0.05),
                              ],
                            ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      f['icon'] as IconData,
                      color: isHighlight ? Colors.white : palette.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          f['label'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: palette.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          f['sub'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: palette.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
  }

  // ── 3. Category Filter Chips ──
  Widget _buildCategoryChips(LuxuryPalette palette) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selectedCategory == cat;

          return ApplePressable(
            onTap: () {
              setState(() {
                _selectedCategory = cat;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: isSelected ? palette.primaryGradient : null,
                color: isSelected ? null : palette.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? Colors.transparent : palette.border,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: palette.primary.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  cat,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : palette.textSecondary,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── 4. Trending Header & Carousel ──
  Widget _buildTrendingHeader(LuxuryPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                'TRENDING STONES',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                  color: palette.textTertiary,
                ),
              ),
              if (_selectedCategory != 'All') ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: palette.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _selectedCategory,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: palette.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          GestureDetector(
            onTap: () => context.push('/collections'),
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

  Widget _buildTrendingCarousel(LuxuryPalette palette) {
    final allStones = _trendingStones ?? [];
    if (allStones.isEmpty) return const SizedBox.shrink();

    // Filter by selected category if not 'All'
    final stones = _selectedCategory == 'All'
        ? allStones
        : allStones.where((s) {
            final cat = _selectedCategory.toLowerCase();
            return s.collection.toLowerCase().contains(cat) ||
                s.name.toLowerCase().contains(cat) ||
                s.category.toLowerCase().contains(cat) ||
                s.description.toLowerCase().contains(cat);
          }).toList();

    final displayStones = stones.isEmpty ? allStones : stones;

    return SizedBox(
      height: 295,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: displayStones.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final stone = displayStones[index];
          final isWishlisted = _wishlistedIds.contains(stone.id);

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
                    // Dominant image with AR and Wishlist overlays
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
                          // Gradient bottom shadow on image
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
                          // Top Right: Wishlist Icon
                          Positioned(
                            top: 8,
                            right: 8,
                            child: ApplePressable(
                              onTap: () {
                                setState(() {
                                  if (_wishlistedIds.contains(stone.id)) {
                                    _wishlistedIds.remove(stone.id);
                                  } else {
                                    _wishlistedIds.add(stone.id);
                                  }
                                });
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
                          // Bottom Left: 1-Tap AR Button
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
                    // Metadata section
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

  // ── 4. Curated Collections ──
  Widget _buildCollectionsHeader(LuxuryPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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

    return SizedBox(
      height: 136,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: collections.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final col = collections[index];
          final matchingStone = _trendingStones
              ?.where((s) => s.collection.toLowerCase().contains(col.name.toLowerCase()) || col.name.toLowerCase().contains(s.collection.toLowerCase()))
              .firstOrNull;

          return ApplePressable(
            onTap: () => context.push('/collections/${col.id}'),
            child: Container(
              width: 165,
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
                      localAsset: (col.imageUrl == null || col.imageUrl!.isEmpty) && matchingStone?.imageUrl == null
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
                            Colors.black.withValues(alpha: 0.75),
                          ],
                          stops: const [0.25, 1.0],
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

  // ── 4B. Full Architectural Product Grid with 1-Tap Quick Add ──
  Widget _buildAllProductsHeader(LuxuryPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
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
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: GLuxuryPalettes.gold.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_trendingStones?.length ?? 0} Products',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: GLuxuryPalettes.gold.primary,
                  ),
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () => context.push('/catalogue'),
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

  Widget _buildAllProductsGrid(LuxuryPalette palette) {
    final stones = _trendingStones ?? [];
    if (stones.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: stones.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.72,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemBuilder: (context, index) {
          final stone = stones[index];
          return ApplePressable(
            onTap: () => context.push('/stone/${stone.id}'),
            child: Container(
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: palette.border, width: 0.8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          child: SmartStoneImage(
                            imageUrl: stone.imageUrl,
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                            palette: palette,
                          ),
                        ),
                        // Quick 1-Tap Add to Cart Button
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: ApplePressable(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              ref.read(cartProvider.notifier).addItem(stone);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${stone.name} added to Project Cart'),
                                  duration: const Duration(seconds: 1),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: GLuxuryPalettes.gold.primary,
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: GLuxuryPalettes.gold.primary,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: GLuxuryPalettes.gold.primary.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.add_shopping_cart_rounded, size: 13, color: Colors.black),
                                  const SizedBox(width: 4),
                                  Text(
                                    '+ Add',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
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
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stone.name,
                          style: GoogleFonts.inter(
                            fontSize: 13,
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
                            fontSize: 10.5,
                            color: palette.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '₹${stone.pricePerSqFt.toInt()}/sqft',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: palette.primary,
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
  }

  // ── 5. Room Upload AI Visualization Promo Card ──
  Widget _buildAIStudioPromoCard(LuxuryPalette palette) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: palette.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.auto_awesome_outlined, color: palette.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                'AI Visualization Studio',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Transform Your Space',
            style: GoogleFonts.playfairDisplay(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Upload a room photo and let AI render premium stone surfaces on walls and floors with photorealistic lighting in seconds.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: palette.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          ApplePressable(
            onTap: () => context.push('/ai-viz'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
              decoration: BoxDecoration(
                gradient: palette.primaryGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: palette.primary.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.photo_camera_outlined, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Try AI Studio →',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 6. Why Grazia Stones 4 Pillars (2x2 Grid) ──
  Widget _buildWhyGraziaPillars(LuxuryPalette palette) {
    final pillars = [
      {
        'icon': Icons.diamond_outlined,
        'title': 'Curated Excellence',
        'desc': 'Handpicked natural stone from premier quarries worldwide.',
      },
      {
        'icon': Icons.view_in_ar_outlined,
        'title': 'Precision Visualization',
        'desc': 'Real-time AR & AI rendering true to scale and architectural lighting.',
      },
      {
        'icon': Icons.verified_outlined,
        'title': 'Architectural Grade',
        'desc': 'Certified standards for luxury residential and commercial projects.',
      },
      {
        'icon': Icons.inventory_2_outlined,
        'title': 'Doorstep Samples',
        'desc': 'Free physical sample swatches delivered anywhere across India.',
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WHY GRAZIA STONES',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.0,
              color: palette.textTertiary,
            ),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 4,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.95,
            ),
            itemBuilder: (context, i) {
              final p = pillars[i];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(18),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(p['icon'] as IconData, color: palette.primary, size: 24),
                    const SizedBox(height: 10),
                    Text(
                      p['title'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      p['desc'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: palette.textSecondary,
                        height: 1.35,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── 7. Architectural Consultation CTA ──
  Widget _buildConsultationCTA(LuxuryPalette palette) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: palette.surfaceDark,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Need Architectural Consultation?',
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Connect with an authorized Grazia dealer or request a personalized project quotation.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: palette.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ApplePressable(
                  onTap: () => context.push('/dealers'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: palette.border, width: 1.2),
                    ),
                    child: Center(
                      child: Text(
                        'Find Showroom',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ApplePressable(
                  onTap: () => context.push('/quotes'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: palette.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: palette.primary.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'Request Quote',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
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
          Row(
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
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.phone_outlined, size: 16, color: palette.primary),
              const SizedBox(width: 8),
              Text(
                '+91 9839846105 / 7518102550',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.mail_outline_rounded, size: 16, color: palette.primary),
              const SizedBox(width: 8),
              Text(
                'hello@graziastones.com',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  color: palette.textSecondary,
                ),
              ),
            ],
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
    final notifications = [
      {'title': 'Welcome to Grazia Stones', 'subtitle': 'Discover our luxury natural surfaces', 'time': 'Just now', 'icon': Icons.diamond_outlined},
      {'title': 'New Collection Arrived', 'subtitle': 'Explore the Royal Heritage marble series', 'time': '2h ago', 'icon': Icons.auto_awesome_outlined},
      {'title': 'Order Status Update', 'subtitle': 'Your sample order has been confirmed', 'time': '1d ago', 'icon': Icons.local_shipping_outlined},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: palette.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Notifications',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ...notifications.map((n) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: palette.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: palette.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(n['icon'] as IconData, color: palette.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n['title'] as String, style: GLuxuryTypography.bodyMedium.copyWith(color: palette.textPrimary, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(n['subtitle'] as String, style: GLuxuryTypography.bodySmall.copyWith(color: palette.textSecondary)),
                      ],
                    ),
                  ),
                  Text(n['time'] as String, style: GLuxuryTypography.bodySmall.copyWith(color: palette.textTertiary, fontSize: 11)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}

