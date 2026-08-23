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
import 'package:grazia_stones/core/widgets/error_handler_widget.dart';
import 'package:grazia_stones/shared/widgets/grazia_logo.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  List<Stone>? _trendingStones;
  List<Collection>? _collections;
  final Set<String> _wishlistedIds = {};
  bool _isLoading = true;

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
        stoneRepo.getTrendingStones(limit: 10),
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
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // 1. Editorial Hero Section
                  SliverToBoxAdapter(
                    child: _buildEditorialHero(palette),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // 2. Quick Action AR Card
                  SliverToBoxAdapter(
                    child: _buildQuickActionARCard(palette),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 28)),

                  // 3. Trending Stones Section
                  SliverToBoxAdapter(
                    child: _buildTrendingHeader(palette),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 14)),

                  SliverToBoxAdapter(
                    child: _buildTrendingCarousel(palette),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 28)),

                  // 4. Curated Collections
                  SliverToBoxAdapter(
                    child: _buildCollectionsHeader(palette),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 14)),

                  SliverToBoxAdapter(
                    child: _buildCollectionsList(palette),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 28)),

                  // 5. Room Upload AI Visualization Card
                  SliverToBoxAdapter(
                    child: _buildAIStudioPromoCard(palette),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 32)),

                  // 6. Why Grazia Stones (4 Pillars)
                  SliverToBoxAdapter(
                    child: _buildWhyGraziaPillars(palette),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 28)),

                  // 7. Architectural Consultation / Dealer CTA
                  SliverToBoxAdapter(
                    child: _buildConsultationCTA(palette),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
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
      height: 260,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
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
                    Colors.black.withValues(alpha: 0.15),
                    Colors.black.withValues(alpha: 0.75),
                  ],
                  stops: const [0.3, 1.0],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Natural Stone.\nDesigned for Living.',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Discover surfaces that transform spaces.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () => context.push('/collections'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: palette.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Explore Collection',
                            style: GoogleFonts.inter(
                              fontSize: 12,
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
            ),
          ],
        ),
      ),
    );
  }

  // ── 2. Quick Action AR Card ──
  Widget _buildQuickActionARCard(LuxuryPalette palette) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: palette.primaryGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: palette.primary.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.view_in_ar_outlined, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live AR Visualization',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Point your camera at any wall to preview stone in real-time.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: palette.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Flexible is required here: Row gives non-flex children an
          // unbounded max-width, and ElevatedButton's min-tap-target
          // wrapper (_InputPadding) throws on infinite width constraints.
          Flexible(
            child: ElevatedButton(
              onPressed: () => context.push('/live-ai'),
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(
                'Open AR →',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. Trending Header & Carousel ──
  Widget _buildTrendingHeader(LuxuryPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
    final stones = _trendingStones ?? [];
    if (stones.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 250,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: stones.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final stone = stones[index];
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/stones/${stone.id}');
            },
            child: Container(
              width: 175,
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dominant image
                    Expanded(
                      flex: 3,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          SmartStoneImage(
                            imageUrl: stone.imageUrl,
                            fit: BoxFit.cover,
                            palette: palette,
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  if (_wishlistedIds.contains(stone.id)) {
                                    _wishlistedIds.remove(stone.id);
                                  } else {
                                    _wishlistedIds.add(stone.id);
                                  }
                                });
                              },
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: palette.surface.withValues(alpha: 0.9),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _wishlistedIds.contains(stone.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                  size: 15,
                                  color: _wishlistedIds.contains(stone.id) ? palette.primary : palette.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Metadata
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stone.name,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
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
                          Text(
                            '₹${stone.pricePerSqFt.toInt()} / sq ft',
                            style: GoogleFonts.inter(
                              fontSize: 12,
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
          GestureDetector(
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
      height: 130,
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

          return GestureDetector(
            onTap: () => context.push('/collections/${col.id}'),
            child: Container(
              width: 160,
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
                  fit: StackFit.expand,
                  children: [
                    SmartStoneImage(
                      imageUrl: matchingStone?.imageUrl,
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
                            Colors.black.withValues(alpha: 0.7),
                          ],
                          stops: const [0.3, 1.0],
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
                              color: Colors.white.withValues(alpha: 0.8),
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

  // ── 5. Room Upload AI Visualization Promo Card ──
  Widget _buildAIStudioPromoCard(LuxuryPalette palette) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: palette.primary.withValues(alpha: 0.1),
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
              fontSize: 20,
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
          ElevatedButton.icon(
            onPressed: () => context.push('/ai-viz'),
            icon: const Icon(Icons.photo_camera_outlined, size: 18),
            label: const Text('Try AI Studio →'),
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
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
        borderRadius: BorderRadius.circular(20),
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
                child: OutlinedButton(
                  onPressed: () => context.push('/dealers'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.textPrimary,
                    side: BorderSide(color: palette.border, width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Find Showroom'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => context.push('/quotes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Request Quote'),
                ),
              ),
            ],
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

