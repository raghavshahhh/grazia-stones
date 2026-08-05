import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/constants/app_colors.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/core/services/mock_data_service.dart';

import 'widgets/ar_camera_view.dart';

/// Redesigned Luxury Live AI Screen
/// TilesView / IKEA Place style AR experience for Grazia Stones
class LiveAIScreen extends StatefulWidget {
  const LiveAIScreen({super.key});

  @override
  State<LiveAIScreen> createState() => _LiveAIScreenState();
}

class _LiveAIScreenState extends State<LiveAIScreen>
    with TickerProviderStateMixin {
  // Category selection
  String _selectedCategory = 'All';
  final List<String> _categories = [
    'All',
    'Ledge',
    'Marble',
    'Granite',
    'Quartz',
    'Ceramic',
    'Outdoor'
  ];

  // Selected stone state
  int _selectedStoneIndex = 0;
  List<Stone> _filteredStones = MockDataService.stones;

  // Camera & AR state
  bool _cameraReady = false;

  // Perspective & Surface Overlay Controls
  double _surfaceScale = 1.0;
  final double _surfaceOpacity = 0.82;
  final double _surfaceRotation = 0.0; // Radians
  Offset? _surfaceCenter;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late ScrollController _categoryScrollController;
  late PageController _stonePageController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _categoryScrollController = ScrollController();
    _stonePageController =
        PageController(viewportFraction: 0.23, initialPage: 0);

    _updateFilteredStones();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _categoryScrollController.dispose();
    _stonePageController.dispose();
    super.dispose();
  }

  void _updateFilteredStones() {
    if (_selectedCategory == 'All') {
      _filteredStones = MockDataService.stones;
    } else {
      _filteredStones = MockDataService.stones
          .where((s) =>
              s.category.toLowerCase().contains(_selectedCategory.toLowerCase()) ||
              s.name.toLowerCase().contains(_selectedCategory.toLowerCase()))
          .toList();
      if (_filteredStones.isEmpty) {
        _filteredStones = MockDataService.stones;
      }
    }
    _selectedStoneIndex = 0;
  }

  Stone get _selectedStone =>
      _filteredStones[_selectedStoneIndex % _filteredStones.length];

  void _selectStone(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedStoneIndex = index;
    });

    final stone = _selectedStone;
    final path = stone.images.isNotEmpty ? stone.images.first : null;
    if (path != null) {
      ARCameraView.updateStone(path, _surfaceOpacity);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // Initialize surface center at middle of wall view
    _surfaceCenter ??= Offset(size.width * 0.5, size.height * 0.38);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 100% Full Screen Real Camera Feed
          _buildCameraFeed(),

          // Perspective Wall Surface & Controls
          _buildPerspectiveWallSurface(size),

          // Wall Detection Guidance Toast
          _buildWallGuidanceToast(),

          // Minimal Luxury Top Bar (Back, Title, Search)
          _buildTopBar(),

          // Floating Glassmorphism Bottom Panel (Instagram Filter Style)
          _buildFloatingBottomPanel(),
        ],
      ),
    );
  }

  // ── 1. 100% Full Screen Camera Feed ──
  Widget _buildCameraFeed() {
    final assetPath =
        _selectedStone.images.isNotEmpty ? _selectedStone.images.first : null;

    return Positioned.fill(
      child: ARCameraView(
        key: const ValueKey('ar-camera-view'),
        stoneImagePath: _cameraReady ? assetPath : null,
        opacity: _surfaceOpacity,
        onReady: () {
          if (!mounted) return;
          setState(() => _cameraReady = true);
          if (assetPath != null) {
            ARCameraView.updateStone(assetPath, _surfaceOpacity);
          }
          ARCameraView.showWallBoundary(true);
        },
        onError: () {},
      ),
    );
  }

  // ── 2. Wall Guidance Banner ──
  Widget _buildWallGuidanceToast() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 60,
      left: 0,
      right: 0,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.goldWarm.withValues(alpha: 0.3),
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
                        color: AppColors.goldWarm
                            .withValues(alpha: _pulseAnimation.value),
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

  // ── 3. Perspective Wall Surface with Interactive Warping ──
  Widget _buildPerspectiveWallSurface(Size size) {
    final center = _surfaceCenter!;
    final stone = _selectedStone;
    final imagePath = stone.images.isNotEmpty
        ? stone.images.first
        : 'assets/images/placeholder_stone.png';

    const double baseWidth = 240.0;
    const double baseHeight = 180.0;

    return Positioned(
      left: center.dx - (baseWidth * _surfaceScale) / 2,
      top: center.dy - (baseHeight * _surfaceScale) / 2,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _surfaceCenter = _surfaceCenter! + details.delta;
          });
        },
        child: Transform.rotate(
          angle: _surfaceRotation,
          child: Transform.scale(
            scale: _surfaceScale,
            child: Container(
              width: baseWidth,
              height: baseHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 4,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Stone Texture Layer with Multiply Blend Mode Opacity
                    Opacity(
                      opacity: _surfaceOpacity,
                      child: Image.asset(
                        imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => Container(
                          color: const Color(0xFF2A2A2A),
                          child: const Center(
                            child: Icon(Icons.texture,
                                color: AppColors.goldWarm, size: 32),
                          ),
                        ),
                      ),
                    ),

                    // Subtle Edge Feathering / Realistic Light Highlight Overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.15),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.25),
                          ],
                        ),
                        border: Border.all(
                          color: AppColors.goldWarm.withValues(alpha: 0.5),
                          width: 1.2,
                        ),
                      ),
                    ),

                    // Luxury Corner Brackets
                    ..._buildCornerBrackets(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCornerBrackets() {
    return const [
      Positioned(top: 4, left: 4, child: _CornerBracket(top: true, left: true)),
      Positioned(
          top: 4, right: 4, child: _CornerBracket(top: true, left: false)),
      Positioned(
          bottom: 4, left: 4, child: _CornerBracket(top: false, left: true)),
      Positioned(
          bottom: 4, right: 4, child: _CornerBracket(top: false, left: false)),
    ];
  }

  // ── 4. Minimal Top Bar (← Back, Title, Search) ──
  Widget _buildTopBar() {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(16, topPadding + 6, 16, 12),
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
            // Back button
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
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 0.8,
                  ),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 16, color: Colors.white),
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
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'REAL-TIME WALL TEXTURE MAPPING',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.6),
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
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 0.8,
                  ),
                ),
                child: const Icon(Icons.search_rounded,
                    size: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 5. Floating Glassmorphism Bottom Panel (Instagram Style) ──
  Widget _buildFloatingBottomPanel() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final stone = _selectedStone;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding + 14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.82),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: AppColors.goldWarm.withValues(alpha: 0.25),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 30,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top drag line indicator
                Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
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
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final isSelected = cat == _selectedCategory;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedCategory = cat;
                            _updateFilteredStones();
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
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
                            cat,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected ? Colors.black : Colors.white,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 14),

                // ── ROW 2: Circular Stone Thumbnails (Instagram Filter Style) ──
                SizedBox(
                  height: 84,
                  child: PageView.builder(
                    controller: _stonePageController,
                    itemCount: _filteredStones.length,
                    onPageChanged: (index) {
                      _selectStone(index);
                    },
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
                              width: isSelected ? 58 : 50,
                              height: isSelected ? 58 : 50,
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
                                        color:
                                            Colors.white.withValues(alpha: 0.2),
                                        width: 1,
                                      )
                                    : null,
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: AppColors.goldWarm
                                              .withValues(alpha: 0.5),
                                          blurRadius: 14,
                                          spreadRadius: 2,
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
                                    errorBuilder: (ctx, err, stack) =>
                                        Container(
                                      color: const Color(0xFF222222),
                                      child: const Icon(Icons.texture,
                                          color: AppColors.goldWarm, size: 20),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.name.split(' ').first,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 9,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? AppColors.goldWarm
                                    : Colors.white.withValues(alpha: 0.7),
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

                const SizedBox(height: 12),

                // ── ROW 3: Product Detail Strip & Direct View Product Button ──
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Thumbnail preview
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          stone.images.isNotEmpty
                              ? stone.images.first
                              : 'assets/images/placeholder_stone.png',
                          width: 38,
                          height: 38,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Stone Title & Price
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
                            ),
                          ],
                        ),
                      ),

                      // Direct "View Product →" Button
                      ElevatedButton(
                        onPressed: () => context.push('/stones/${stone.id}'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.goldWarm,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
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
                            Icon(Icons.arrow_forward_rounded, size: 13),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── ROW 4: Action Buttons (Wishlist, Share, Sample, 3D) ──
                Row(
                  children: [
                    _buildActionButton(
                      icon: Icons.favorite_border_rounded,
                      label: 'Wishlist',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${stone.name} added to Wishlist!'),
                            backgroundColor: AppColors.goldWarm,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildActionButton(
                      icon: Icons.share_outlined,
                      label: 'Share',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Sharing stone visualizer link...'),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildActionButton(
                      icon: Icons.inventory_2_outlined,
                      label: 'Sample',
                      onTap: () => context.push('/sample-order'),
                    ),
                    const SizedBox(width: 8),
                    _buildActionButton(
                      icon: Icons.view_in_ar_rounded,
                      label: '3D View',
                      onTap: () => context.push('/ar-view'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 0.6,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppColors.goldWarm),
              const SizedBox(height: 3),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Corner bracket decoration for perspective wall overlay
class _CornerBracket extends StatelessWidget {
  final bool top;
  final bool left;

  const _CornerBracket({required this.top, required this.left});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        border: Border(
          top: top
              ? const BorderSide(color: AppColors.goldWarm, width: 2)
              : BorderSide.none,
          bottom: !top
              ? const BorderSide(color: AppColors.goldWarm, width: 2)
              : BorderSide.none,
          left: left
              ? const BorderSide(color: AppColors.goldWarm, width: 2)
              : BorderSide.none,
          right: !left
              ? const BorderSide(color: AppColors.goldWarm, width: 2)
              : BorderSide.none,
        ),
      ),
    );
  }
}
