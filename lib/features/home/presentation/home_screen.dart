import 'package:flutter/material.dart';
import 'package:grazia_stones/core/constants/app_colors.dart';
import 'package:grazia_stones/core/constants/app_strings.dart';
import 'package:grazia_stones/core/widgets/animated_widgets.dart';
import 'package:grazia_stones/shared/widgets/grazia_app_bar.dart';
import 'package:grazia_stones/shared/widgets/grazia_bottom_nav.dart';
import 'package:grazia_stones/shared/widgets/loading_skeleton.dart';
import 'package:grazia_stones/features/home/presentation/widgets/home_hero_carousel.dart';
import 'package:grazia_stones/features/home/presentation/widgets/home_quick_actions.dart';
import 'package:grazia_stones/features/home/presentation/widgets/home_collection_strip.dart';
import 'package:grazia_stones/features/home/presentation/widgets/home_trending_grid.dart';
import 'package:grazia_stones/features/collections/presentation/collection_list_screen.dart';
import 'package:grazia_stones/features/ai_viz/presentation/ai_viz_screen.dart';
import 'package:grazia_stones/features/cart/presentation/cart_screen.dart';
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
        return const AIScreen();
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
      appBar: _currentNavIndex == 0
          ? GraziaAppBar(
              title: AppStrings.appName,
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined,
                      color: AppColors.textSecondary),
                  onPressed: () {},
                ),
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
          const SliverToBoxAdapter(
            child: FadeInStagger(index: 0, child: HomeHeroCarousel()),
          ),
          const SliverToBoxAdapter(
            child: FadeInStagger(index: 1, child: HomeQuickActions()),
          ),
          const SliverToBoxAdapter(
            child: FadeInStagger(index: 2, child: HomeCollectionStrip()),
          ),
          const SliverToBoxAdapter(
            child: FadeInStagger(index: 3, child: HomeTrendingGrid()),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}
