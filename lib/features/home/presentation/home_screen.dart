import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/services/mock_data_service.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/spacing.dart';
import 'package:grazia_stones/shared/theme/typography.dart';
import 'package:grazia_stones/shared/widgets/grazia_app_bar.dart';
import 'package:grazia_stones/shared/widgets/loading_skeleton.dart';
import 'package:grazia_stones/features/home/presentation/widgets/home_hero_carousel.dart';
import 'package:grazia_stones/features/home/presentation/widgets/home_quick_actions.dart';
import 'package:grazia_stones/features/home/presentation/widgets/home_collection_strip.dart';
import 'package:grazia_stones/features/home/presentation/widgets/home_trending_grid.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final palette = GLuxuryPalettes.gold;

    return Scaffold(
      backgroundColor: palette.background,
      extendBody: true,
      appBar: GraziaAppBar(
        title: 'GRAZIA',
        actions: [
          _buildGlassIconButton(
            icon: Icons.notifications_outlined,
            onTap: () {},
          ),
          const SizedBox(width: 4),
          _buildGlassIconButton(
            icon: Icons.search_rounded,
            onTap: () => context.push('/search'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading ? _buildLoading(palette) : _buildContent(palette),
    );
  }

  Widget _buildGlassIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final palette = GLuxuryPalettes.gold;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: palette.primary.withValues(alpha: 0.1),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: palette.textPrimary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: palette.border,
              width: 0.5,
            ),
          ),
          child: Icon(icon, size: 18, color: palette.textSecondary),
        ),
      ),
    );
  }

  Widget _buildLoading(GoldPalette palette) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          const LoadingSkeleton(width: double.infinity, height: 220),
          GLuxurySpacing.gapBase,
          Padding(
            padding: GLuxurySpacing.horizontalBase,
            child: Row(
              children: List.generate(
                4,
                (_) => const Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: LoadingSkeleton(width: double.infinity, height: 80),
                  ),
                ),
              ),
            ),
          ),
          GLuxurySpacing.gapXl,
          Padding(
            padding: GLuxurySpacing.horizontalBase,
            child: const LoadingSkeleton(height: 24, width: 180),
          ),
          GLuxurySpacing.gapMd,
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: GLuxurySpacing.horizontalBase,
              itemCount: 4,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, _) => const LoadingSkeleton(
                width: 120,
                height: 160,
                borderRadius: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(GoldPalette palette) {
    final trendingStones = MockDataService.getTrendingStones();
    final collections = MockDataService.collections;
    final quickActions = [
      {'icon': Icons.auto_awesome_outlined, 'label': 'AI Viz', 'route': '/ai-viz'},
      {'icon': Icons.camera_alt_outlined, 'label': 'AR View', 'route': '/ar-view'},
      {'icon': Icons.straighten_outlined, 'label': 'Measure', 'route': null},
      {'icon': Icons.request_quote_outlined, 'label': 'Quote', 'route': '/quotes'},
    ];

    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _isLoading = true);
        await _loadData();
      },
      color: palette.primary,
      backgroundColor: palette.background,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: HomeHeroCarousel(stones: trendingStones),
          ),
          SliverToBoxAdapter(child: GLuxurySpacing.gapXl),
          SliverToBoxAdapter(child: _SectionTitle(title: 'Quick Actions')),
          SliverToBoxAdapter(child: GLuxurySpacing.gapMd),
          SliverToBoxAdapter(
            child: HomeQuickActions(
              actions: quickActions,
              onActionTap: (i) {
                final route = quickActions[i]['route'] as String?;
                if (route != null) context.push(route);
              },
            ),
          ),
          SliverToBoxAdapter(child: GLuxurySpacing.gapXxl),
          SliverToBoxAdapter(
            child: _SectionTitle(
              title: 'Collections',
              actionLabel: 'View All',
              onAction: () => context.push('/collections'),
            ),
          ),
          SliverToBoxAdapter(child: GLuxurySpacing.gapMd),
          SliverToBoxAdapter(
            child: HomeCollectionStrip(
              collections: collections,
              onCollectionTap: (c) =>
                  context.push('/collections/${c.id}'),
            ),
          ),
          SliverToBoxAdapter(child: GLuxurySpacing.gapXxl),
          const SliverToBoxAdapter(
            child: _SectionTitle(title: 'Trending Stones'),
          ),
          SliverToBoxAdapter(child: GLuxurySpacing.gapMd),
          const SliverToBoxAdapter(child: HomeTrendingGrid()),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionTitle({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final palette = GLuxuryPalettes.gold;
    return Padding(
      padding: GLuxurySpacing.horizontalBase,
      child: Row(
        children: [
          Text(
            title,
            style: GLuxuryTypography.h3.copyWith(
              color: palette.textPrimary,
            ),
          ),
          const Spacer(),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Row(
                children: [
                  Text(
                    actionLabel!,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: palette.primary.withValues(alpha: 0.7),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 10,
                    color: palette.primary.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
