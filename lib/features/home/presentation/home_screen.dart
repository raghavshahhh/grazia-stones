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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);
    final isDark = ref.watch(themePaletteProvider.notifier).isDarkMode;

    return Scaffold(
      backgroundColor: palette.background,
      extendBody: true,
      appBar: GraziaAppBar(
        title: 'GRAZIA',
        actions: [
          _buildGlassIconButton(
            icon: isDark ? Icons.wb_sunny_outlined : Icons.nightlight_round_outlined,
            onTap: () => ref.read(themePaletteProvider.notifier).toggleTheme(),
          ),
          const SizedBox(width: 4),
          _buildGlassIconButton(
            icon: Icons.notifications_outlined,
            onTap: () => _showNotificationsSheet(context),
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

  Widget _buildLoading(LuxuryPalette palette) {
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

  Widget _buildContent(LuxuryPalette palette) {
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

  void _showNotificationsSheet(BuildContext context) {
    final palette = GLuxuryPalettes.gold;
    final notifications = [
      {'title': 'Welcome to Grazia!', 'subtitle': 'Discover our luxury stone collections', 'time': 'Just now', 'icon': Icons.star_outline},
      {'title': 'New Collection Arrived', 'subtitle': 'Explore the Royal Heritage marble series', 'time': '2h ago', 'icon': Icons.diamond_outlined},
      {'title': 'Order Shipped', 'subtitle': 'Your sample order is on the way', 'time': '1d ago', 'icon': Icons.local_shipping_outlined},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.45,
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: palette.textTertiary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text('Notifications', style: GLuxuryTypography.h2.copyWith(color: palette.textPrimary)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: notifications.length,
                itemBuilder: (ctx, i) {
                  final n = notifications[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
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
                  );
                },
              ),
            ),
          ],
        ),
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
