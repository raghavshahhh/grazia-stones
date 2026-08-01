import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:grazia_stones/core/constants/app_colors.dart';
import 'package:grazia_stones/core/constants/app_strings.dart';
import 'package:grazia_stones/core/services/mock_data_service.dart';
import 'package:grazia_stones/core/widgets/animated_widgets.dart';
import 'package:grazia_stones/shared/widgets/grazia_app_bar.dart';
import 'package:grazia_stones/shared/widgets/grazia_bottom_nav.dart';
import 'package:grazia_stones/shared/widgets/loading_skeleton.dart';
import 'package:grazia_stones/features/home/presentation/widgets/home_hero_carousel.dart';
import 'package:grazia_stones/features/home/presentation/widgets/home_quick_actions.dart';
import 'package:grazia_stones/features/home/presentation/widgets/home_collection_strip.dart';
import 'package:grazia_stones/features/home/presentation/widgets/home_trending_grid.dart';
import 'package:grazia_stones/features/collections/presentation/collection_list_screen.dart';
import 'package:grazia_stones/features/cart/presentation/cart_screen.dart';
import 'package:grazia_stones/features/live_ai/presentation/live_ai_screen.dart';
import 'package:grazia_stones/features/profile/presentation/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentNavIndex = 0;
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

  Widget _buildCurrentScreen() {
    switch (_currentNavIndex) {
      case 0:
        return _isLoading ? _buildLoading() : _buildContent();
      case 1:
        return const CollectionListScreen();
      case 2:
        return const LiveAIScreen();
      case 3:
        return const CartScreen();
      case 4:
        return const ProfileScreen();
      default:
        return _isLoading ? _buildLoading() : _buildContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.charcoal,
      extendBody: true,
      appBar: _currentNavIndex == 0
          ? GraziaAppBar(
              title: AppStrings.appName,
              actions: [
                _buildGlassIconButton(
                  icon: Icons.notifications_outlined,
                  onTap: () {},
                ),
                const SizedBox(width: 4),
                _buildGlassIconButton(
                  icon: Icons.search_rounded,
                  onTap: () => Navigator.pushNamed(context, '/search'),
                ),
                const SizedBox(width: 8),
              ],
            )
          : null,
      body: _buildCurrentScreen(),
      bottomNavigationBar: GraziaBottomNav(
        currentIndex: _currentNavIndex,
        onTap: (i) => setState(() => _currentNavIndex = i),
      ),
    );
  }

  Widget _buildGlassIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: AppColors.goldWarm.withOpacity(0.1),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.white.withOpacity(0.06),
              width: 0.5,
            ),
          ),
          child: Icon(icon, size: 18, color: AppColors.silverLight),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          const LoadingSkeleton(width: double.infinity, height: 220),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: LoadingSkeleton(height: 24, width: 180),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, __) => const LoadingSkeleton(
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

  Widget _buildContent() {
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
      color: AppColors.goldWarm,
      backgroundColor: AppColors.charcoal,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Hero Carousel (uses trendingStones for hero images)
          SliverToBoxAdapter(
            child: FadeInStagger(
              index: 0,
              child: HomeHeroCarousel(stones: trendingStones),
            ),
          ),

          // Section title: Quick Actions
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          const SliverToBoxAdapter(child: _SectionTitle(title: 'Quick Actions')),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // Quick Actions
          SliverToBoxAdapter(
            child: FadeInStagger(
              index: 1,
              child: HomeQuickActions(
                actions: quickActions,
                onActionTap: (i) {
                  final route = quickActions[i]['route'] as String?;
                  if (route != null) Navigator.pushNamed(context, route);
                },
              ),
            ),
          ),

          // Section title: Collections
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
          SliverToBoxAdapter(
            child: _SectionTitle(
              title: 'Collections',
              actionLabel: AppStrings.viewAll,
              onAction: () => Navigator.pushNamed(context, '/collections'),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // Collection Strip
          SliverToBoxAdapter(
            child: FadeInStagger(
              index: 2,
              child: HomeCollectionStrip(
                collections: collections,
                onCollectionTap: (c) => Navigator.pushNamed(
                  context,
                  '/collection-detail',
                  arguments: c.id,
                ),
              ),
            ),
          ),

          // Section title: Trending
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
          const SliverToBoxAdapter(
            child: _SectionTitle(title: 'Trending Stones'),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // Trending Grid
          const SliverToBoxAdapter(
            child: FadeInStagger(index: 3, child: HomeTrendingGrid()),
          ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.white,
              letterSpacing: 0.5,
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
                      color: AppColors.goldWarm.withOpacity(0.7),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 10,
                    color: AppColors.goldWarm.withOpacity(0.5),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
