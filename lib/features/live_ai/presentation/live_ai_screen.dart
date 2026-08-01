import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:grazia_stones/core/constants/app_colors.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/core/services/mock_data_service.dart';

class LiveAIScreen extends StatefulWidget {
  const LiveAIScreen({super.key});

  @override
  State<LiveAIScreen> createState() => _LiveAIScreenState();
}

class _LiveAIScreenState extends State<LiveAIScreen>
    with TickerProviderStateMixin {
  int _selectedStoneIndex = 0;
  double _overlayScale = 1.0;
  double _overlayOpacity = 0.85;
  Offset _overlayPosition = Offset.zero;
  bool _isAnalyzing = false;
  bool _showInfo = true;
  late AnimationController _pulseController;
  late AnimationController _scanController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scanAnimation;
  late PageController _tileController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.linear),
    );

    _tileController = PageController(viewportFraction: 0.22, initialPage: 0);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = MediaQuery.of(context).size;
      setState(() {
        _overlayPosition = Offset(size.width * 0.15, size.height * 0.2);
      });
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanController.dispose();
    _tileController.dispose();
    super.dispose();
  }

  Stone get _selectedStone => MockDataService.stones[_selectedStoneIndex];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera-like background
          _buildCameraBackground(),

          // AI scan lines
          _buildScanLines(),

          // Stone overlay on wall
          _buildStoneOverlay(),

          // Top bar with AI status
          _buildTopBar(),

          // AI analysis badges
          if (_showInfo) _buildAnalysisBadges(),

          // Size / Opacity controls
          _buildControls(),

          // Bottom stone tiles
          _buildBottomTiles(),
        ],
      ),
    );
  }

  Widget _buildCameraBackground() {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A1A2E),
              Color(0xFF16213E),
              Color(0xFF0F3460),
              Color(0xFF1A1A2E),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Simulated room wall texture
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.03),
                      Colors.white.withOpacity(0.01),
                      Colors.white.withOpacity(0.04),
                    ],
                  ),
                ),
              ),
            ),
            // Grid lines (room perspective)
            ..._buildRoomGrid(),
            // Center crosshair
            _buildCrosshair(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRoomGrid() {
    return List.generate(5, (i) {
      return Positioned(
        top: 0,
        bottom: 0,
        left: (i + 1) * (MediaQuery.of(context).size.width / 6),
        child: Container(
          width: 0.5,
          color: AppColors.goldWarm.withOpacity(0.06),
        ),
      );
    });
  }

  Widget _buildCrosshair() {
    return Center(
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Container(
            width: 40 * _pulseAnimation.value,
            height: 40 * _pulseAnimation.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.goldWarm.withOpacity(0.3 * _pulseAnimation.value),
                width: 1.5,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildScanLines() {
    return AnimatedBuilder(
      animation: _scanAnimation,
      builder: (context, child) {
        return Positioned(
          top: _scanAnimation.value * MediaQuery.of(context).size.height,
          left: 0,
          right: 0,
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.goldWarm.withOpacity(0.0),
                  AppColors.goldWarm.withOpacity(0.4),
                  AppColors.goldWarm.withOpacity(0.0),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStoneOverlay() {
    return Positioned(
      left: _overlayPosition.dx,
      top: _overlayPosition.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _overlayPosition += details.delta;
          });
        },
        onScaleUpdate: (details) {
          setState(() {
            _overlayScale = (_overlayScale * details.scale).clamp(0.5, 3.0);
          });
        },
        child: Opacity(
          opacity: _overlayOpacity,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _overlayScale,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.goldWarm.withOpacity(0.15 * _pulseAnimation.value),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Stone image
                        Image.network(
                          _selectedStone.imageUrl ?? '',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _selectedStone.availableColors
                                    .map((c) => Color(
                                        int.parse(c.replaceFirst('#', '0xFF'))))
                                    .toList(),
                              ),
                            ),
                          ),
                        ),
                        // Glass overlay
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: AppColors.goldWarm.withOpacity(0.5),
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        // Stone name badge
                        Positioned(
                          bottom: 8,
                          left: 8,
                          right: 8,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: AppColors.goldWarm.withOpacity(0.2),
                                    width: 0.5,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _selectedStone.name,
                                      style: const TextStyle(
                                        color: AppColors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '₹${_selectedStone.pricePerSqFt}/sq ft  •  ${_selectedStone.finish}',
                                      style: TextStyle(
                                        color: AppColors.goldWarm,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w500,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Corner handles
                        ..._buildCornerHandles(),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCornerHandles() {
    return [
      Positioned(
        top: -2,
        left: -2,
        child: _buildHandle(),
      ),
      Positioned(
        top: -2,
        right: -2,
        child: _buildHandle(),
      ),
      Positioned(
        bottom: 40,
        left: -2,
        child: _buildHandle(),
      ),
      Positioned(
        bottom: 40,
        right: -2,
        child: _buildHandle(),
      ),
    ];
  }

  Widget _buildHandle() {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: AppColors.goldWarm,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.goldWarm.withOpacity(0.5),
            blurRadius: 6,
          ),
        ],
      ),
      child: const Icon(Icons.center_focus_strong, size: 8, color: Colors.black),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: EdgeInsets.fromLTRB(
                16, MediaQuery.of(context).padding.top + 8, 16, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.black.withOpacity(0.0),
                ],
              ),
            ),
            child: Row(
              children: [
                // AI Status dot
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isAnalyzing
                            ? AppColors.goldWarm
                            : AppColors.success,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_isAnalyzing
                                    ? AppColors.goldWarm
                                    : AppColors.success)
                                .withOpacity(0.6 * _pulseAnimation.value),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                Text(
                  _isAnalyzing ? 'AI ANALYZING...' : 'LIVE AI READY',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _isAnalyzing
                        ? AppColors.goldWarm
                        : AppColors.success,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                // Toggle info
                GestureDetector(
                  onTap: () => setState(() => _showInfo = !_showInfo),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _showInfo
                              ? Icons.info_outline_rounded
                              : Icons.info_outline_rounded,
                          size: 14,
                          color: AppColors.silverLight,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _showInfo ? 'INFO ON' : 'INFO OFF',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: AppColors.silverLight,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnalysisBadges() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 60,
      left: 16,
      right: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBadge(
            icon: Icons.category_outlined,
            label: 'MATERIAL',
            value: _selectedStone.finish,
            color: AppColors.goldWarm,
          ),
          const SizedBox(height: 8),
          _buildBadge(
            icon: Icons.location_on_outlined,
            label: 'ORIGIN',
            value: _selectedStone.origin,
            color: AppColors.info,
          ),
          const SizedBox(height: 8),
          _buildBadge(
            icon: Icons.straighten_outlined,
            label: 'THICKNESS',
            value: _selectedStone.thickness,
            color: AppColors.warning,
          ),
          const SizedBox(height: 8),
          _buildBadge(
            icon: Icons.star_outline_rounded,
            label: 'RATING',
            value: '${_selectedStone.rating} (${_selectedStone.reviewCount})',
            color: AppColors.goldLight,
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 7,
                      fontWeight: FontWeight.w600,
                      color: color.withOpacity(0.7),
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Positioned(
      right: 16,
      top: MediaQuery.of(context).size.height * 0.35,
      child: Column(
        children: [
          _buildControlButton(
            icon: Icons.add,
            onTap: () =>
                setState(() => _overlayScale = (_overlayScale + 0.2).clamp(0.5, 3.0)),
          ),
          const SizedBox(height: 12),
          _buildControlButton(
            icon: Icons.remove,
            onTap: () =>
                setState(() => _overlayScale = (_overlayScale - 0.2).clamp(0.5, 3.0)),
          ),
          const SizedBox(height: 12),
          _buildControlButton(
            icon: Icons.opacity,
            onTap: () {
              setState(() {
                _overlayOpacity = _overlayOpacity >= 0.9 ? 0.3 : _overlayOpacity + 0.15;
              });
            },
          ),
          const SizedBox(height: 12),
          _buildControlButton(
            icon: Icons.center_focus_strong,
            onTap: () {
              final size = MediaQuery.of(context).size;
              setState(() {
                _overlayPosition =
                    Offset(size.width * 0.15, size.height * 0.2);
                _overlayScale = 1.0;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.goldWarm.withOpacity(0.2),
                width: 0.5,
              ),
            ),
            child: Icon(icon, size: 20, color: AppColors.goldWarm),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomTiles() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.9),
                  Colors.black.withOpacity(0.7),
                  Colors.black.withOpacity(0.0),
                ],
              ),
            ),
            child: Column(
              children: [
                // Drag handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // "SELECT STONE" label
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 20,
                        height: 0.5,
                        color: AppColors.goldWarm.withOpacity(0.3),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'SWIPE TO SELECT STONE',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: AppColors.goldWarm.withOpacity(0.6),
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 20,
                        height: 0.5,
                        color: AppColors.goldWarm.withOpacity(0.3),
                      ),
                    ],
                  ),
                ),
                // Stone tiles
                Expanded(
                  child: PageView.builder(
                    controller: _tileController,
                    itemCount: MockDataService.stones.length,
                    onPageChanged: (index) {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _selectedStoneIndex = index;
                        _isAnalyzing = true;
                      });
                      Future.delayed(const Duration(milliseconds: 1200), () {
                        if (mounted) setState(() => _isAnalyzing = false);
                      });
                    },
                    itemBuilder: (context, index) {
                      final stone = MockDataService.stones[index];
                      final isSelected = index == _selectedStoneIndex;
                      return AnimatedScale(
                        scale: isSelected ? 1.0 : 0.85,
                        duration: const Duration(milliseconds: 300),
                        child: GestureDetector(
                          onTap: () {
                            _tileController.animateToPage(
                              index,
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOutCubic,
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.goldWarm
                                    : AppColors.goldWarm.withOpacity(0.15),
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color:
                                            AppColors.goldWarm.withOpacity(0.25),
                                        blurRadius: 12,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // Stone image
                                  Image.network(
                                    stone.imageUrl ?? '',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: stone.availableColors
                                              .map((c) => Color(int.parse(
                                                  c.replaceFirst(
                                                      '#', '0xFF'))))
                                              .toList(),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Label overlay
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 4),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withOpacity(0.8),
                                          ],
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            stone.name,
                                            style: const TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.white,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            '₹${stone.pricePerSqFt}/sqft',
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 8,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.goldWarm,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Selected indicator
                                  if (isSelected)
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: AppColors.goldWarm,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.goldWarm
                                                  .withOpacity(0.5),
                                              blurRadius: 6,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(Icons.check,
                                            size: 10, color: Colors.black),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
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
