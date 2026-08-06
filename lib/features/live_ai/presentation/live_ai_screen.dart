import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/constants/app_colors.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/core/services/mock_data_service.dart';
import 'widgets/ar_camera_view.dart';

/// Premium Luxury Live AI Screen - Real Camera + Wall Texture Visualization
class LiveAIScreen extends StatefulWidget {
  const LiveAIScreen({super.key});

  @override
  State<LiveAIScreen> createState() => _LiveAIScreenState();
}

class _LiveAIScreenState extends State<LiveAIScreen>
    with TickerProviderStateMixin {
  // Stone selection state
  int _selectedStoneIndex = 0;
  List<Stone> _filteredStones = MockDataService.stones;

  // Category filter state
  String _selectedCategory = 'All';
  final List<String> _categories = [
    'All',
    'Marble',
    'Granite',
    'Quartz',
    'Ceramic',
    'Outdoor',
    'Premium',
  ];

  // Camera state (defaults to true so camera opens immediately on screen enter!)
  bool _cameraReady = false;
  final bool _wallDetected = true;

  // Texture mapping state
  final double _textureOpacity = 0.80; // Realistic 80% opacity

  // Controllers
  late PageController _stonePageController;
  late ScrollController _categoryScrollController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _stonePageController = PageController(
      viewportFraction: 0.23,
      initialPage: 0,
    );
    _categoryScrollController = ScrollController();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _updateFilteredStones();
  }

  @override
  void dispose() {
    _stonePageController.dispose();
    _categoryScrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _updateFilteredStones() {
    setState(() {
      if (_selectedCategory == 'All') {
        _filteredStones = MockDataService.stones;
      } else {
        _filteredStones = MockDataService.stones
            .where((s) =>
                s.category.toLowerCase().contains(_selectedCategory.toLowerCase()) ||
                s.collection.toLowerCase().contains(_selectedCategory.toLowerCase()))
            .toList();
        if (_filteredStones.isEmpty) {
          _filteredStones = MockDataService.stones;
        }
      }
      _selectedStoneIndex = 0;
    });
  }

  Stone get _selectedStone => _filteredStones.isEmpty
      ? MockDataService.stones.first
      : _filteredStones[_selectedStoneIndex % _filteredStones.length];

  void _selectStone(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedStoneIndex = index;
    });

    final stone = _selectedStone;
    final path = stone.images.isNotEmpty ? stone.images.first : null;
    if (path != null && _cameraReady) {
      ARCameraView.updateStone(path, _textureOpacity);
    }
  }

  void _navigateToProduct() {
    HapticFeedback.mediumImpact();
    context.push('/stones/${_selectedStone.id}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. FULL-SCREEN REAL CAMERA FEED (100% of screen)
          _buildFullScreenCamera(),

          // 2. WALL GUIDANCE TOAST
          _buildWallGuidanceToast(),

          // 3. MINIMAL LUXURY TOP BAR (← Back, Title, Search)
          _buildMinimalTopBar(),

          // 4. FLOATING GLASSMORPHISM BOTTOM PANEL (Sitting cleanly above Bottom Nav)
          _buildFloatingBottomPanel(),
        ],
      ),
    );
  }

  /// 1. Full-Screen Camera Feed
  Widget _buildFullScreenCamera() {
    final assetPath =
        _selectedStone.images.isNotEmpty ? _selectedStone.images.first : null;

    return Positioned.fill(
      child: ARCameraView(
        key: const ValueKey('ar-camera-view-main'),
        stoneImagePath: assetPath,
        opacity: _textureOpacity,
        onReady: () {
          if (!mounted) return;
          setState(() => _cameraReady = true);
          if (assetPath != null) {
            ARCameraView.updateStone(assetPath, _textureOpacity);
          }
          ARCameraView.showWallBoundary(true);
        },
        onError: () {},
      ),
    );
  }

  /// 2. Wall Guidance Toast
  Widget _buildWallGuidanceToast() {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 62,
      left: 0,
      right: 0,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.goldWarm.withValues(alpha: 0.35),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Icon(
                        Icons.videocam_outlined,
                        size: 14,
                        color: AppColors.goldWarm.withValues(alpha: _pulseAnimation.value),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Point camera towards a flat wall',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 3. Minimal Luxury Top Bar
  Widget _buildMinimalTopBar() {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(12, topPadding + 6, 12, 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.85),
              Colors.black.withValues(alpha: 0.0),
            ],
          ),
        ),
        child: Row(
          children: [
            // Back Button
            IconButton(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/home');
                }
              },
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 0.8,
                  ),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 15,
                  color: Colors.white,
                ),
              ),
            ),

            const Spacer(),

            // Title
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'LIVE AI VISUALIZER',
                  style: TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.goldWarm,
                    letterSpacing: 2.2,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'REAL-TIME WALL MAPPING',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.7),
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Search Button
            IconButton(
              onPressed: () => context.push('/search'),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 0.8,
                  ),
                ),
                child: const Icon(
                  Icons.search_rounded,
                  size: 17,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 4. Floating Glassmorphism Bottom Panel (Positioned above GraziaBottomNav)
  Widget _buildFloatingBottomPanel() {
    final stone = _selectedStone;

    return Positioned(
      bottom: 82.0, // Floating cleanly above bottom navigation bar!
      left: 12,
      right: 12,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.goldWarm.withValues(alpha: 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 30,
                  spreadRadius: 6,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle bar
                Container(
                  width: 36,
                  height: 3.5,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // ── ROW 1: Horizontal Category Chips ──
                SizedBox(
                  height: 32,
                  child: ListView.separated(
                    controller: _categoryScrollController,
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final isSelected = category == _selectedCategory;

                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedCategory = category;
                            _updateFilteredStones();
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.goldWarm
                                : Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.goldWarm
                                  : Colors.white.withValues(alpha: 0.15),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                              color: isSelected ? Colors.black : Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),

                // ── ROW 2: Circular Stone Thumbnails (Instagram Stories Filter Style) ──
                SizedBox(
                  height: 82,
                  child: PageView.builder(
                    controller: _stonePageController,
                    itemCount: _filteredStones.length,
                    onPageChanged: (index) => _selectStone(index),
                    itemBuilder: (context, index) {
                      final item = _filteredStones[index];
                      final isSelected = index == _selectedStoneIndex;
                      final thumbPath = item.images.isNotEmpty
                          ? item.images.first
                          : 'assets/images/placeholder_stone.png';

                      return GestureDetector(
                        onTap: () {
                          _stonePageController.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOutCubic,
                          );
                          _selectStone(index);
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: isSelected ? 56 : 48,
                              height: isSelected ? 56 : 48,
                              padding: const EdgeInsets.all(2.5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: isSelected
                                    ? const LinearGradient(
                                        colors: [
                                          AppColors.goldWarm,
                                          AppColors.goldLight,
                                          AppColors.goldWarm,
                                        ],
                                      )
                                    : null,
                                border: !isSelected
                                    ? Border.all(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        width: 1,
                                      )
                                    : null,
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: AppColors.goldWarm.withValues(alpha: 0.5),
                                          blurRadius: 14,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black,
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    thumbPath,
                                    fit: BoxFit.cover,
                                    errorBuilder: (ctx, err, stack) => Container(
                                      color: const Color(0xFF222222),
                                      child: const Icon(
                                        Icons.texture,
                                        color: AppColors.goldWarm,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              item.productCode.isNotEmpty
                                  ? item.productCode
                                  : item.name.split(' ').first,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 9,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected
                                    ? AppColors.goldWarm
                                    : Colors.white.withValues(alpha: 0.75),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 10),

                // ── ROW 3: Product Info + Direct View Product Button ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Stone Thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          stone.images.isNotEmpty
                              ? stone.images.first
                              : 'assets/images/placeholder_stone.png',
                          width: 38,
                          height: 38,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) => Container(
                            width: 38,
                            height: 38,
                            color: const Color(0xFF2A2A2A),
                            child: const Icon(
                              Icons.texture,
                              color: AppColors.goldWarm,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Stone Title & Price (Clean horizontal layout)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              stone.name,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₹${stone.pricePerSqFt}/sq.ft',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.goldWarm,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      // View Product Button (Direct Navigation to /stones/:id)
                      ElevatedButton(
                        onPressed: _navigateToProduct,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.goldWarm,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'View Product',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward_rounded, size: 12),
                          ],
                        ),
                      ),
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
}
