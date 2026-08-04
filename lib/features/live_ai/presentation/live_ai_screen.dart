import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:grazia_stones/core/constants/app_colors.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/core/services/mock_data_service.dart';

import 'widgets/web_camera_view.dart';

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
  Offset? _overlayPosition;
  bool _isAnalyzing = false;
  bool _showInfo = true;
  bool _cameraReady = false;
  bool _cameraError = false;
  bool _detecting = false;
  double _detectionConfidence = 0.0;

  late AnimationController _pulseController;
  late AnimationController _scanController;
  late AnimationController _detectController;
  late AnimationController _confidenceController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scanAnimation;
  late Animation<double> _detectAnimation;
  late Animation<double> _confidenceAnimation;
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

    _detectController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _detectAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _detectController, curve: Curves.easeOutCubic),
    );

    _confidenceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _confidenceAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _confidenceController, curve: Curves.easeOut),
    );

    _tileController = PageController(viewportFraction: 0.22, initialPage: 0);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanController.dispose();
    _detectController.dispose();
    _confidenceController.dispose();
    _tileController.dispose();
    super.dispose();
  }

  Stone get _selectedStone => MockDataService.stones[_selectedStoneIndex];

  void _startDetection() {
    setState(() {
      _detecting = true;
      _isAnalyzing = true;
      _detectionConfidence = 0.0;
    });
    _detectController.forward(from: 0);
    _confidenceController.forward(from: 0);

    // Simulate detection progress
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _detectionConfidence = 0.34);
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _detectionConfidence = 0.67);
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _detectionConfidence = 0.95;
          _detecting = false;
          _isAnalyzing = false;
        });
        HapticFeedback.mediumImpact();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    _overlayPosition ??= Offset(size.width * 0.12, size.height * 0.18);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Real camera feed
          _buildCameraFeed(),

          // AI scan lines
          _buildScanLines(),

          // Stone detection overlay
          _buildStoneOverlay(),

          // Corner detection brackets
          if (_detecting || _detectionConfidence > 0)
            _buildDetectionBrackets(),

          // Top bar
          _buildTopBar(),

          // AI analysis badges
          if (_showInfo && _detectionConfidence > 0.5) _buildAnalysisBadges(),

          // Confidence meter
          if (_detecting) _buildConfidenceMeter(),

          // Size / Opacity controls
          _buildControls(),

          // Bottom stone tiles
          _buildBottomTiles(),
        ],
      ),
    );
  }

  // ── Camera Feed ──
  Widget _buildCameraFeed() {
    return Positioned.fill(
      child: Stack(
        children: [
          // Real camera or fallback
          if (!_cameraError)
            WebCameraView(
              onReady: () => setState(() => _cameraReady = true),
              onError: () => setState(() => _cameraError = true),
            ),

          // Fallback gradient if camera fails
          if (_cameraError || !_cameraReady)
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF0D0D0D),
                    Color(0xFF1A1A1A),
                    Color(0xFF0D0D0D),
                  ],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.camera_alt_outlined,
                        size: 48, color: AppColors.goldWarm.withValues(alpha:0.4)),
                    const SizedBox(height: 12),
                    Text(
                      _cameraError ? 'Camera unavailable' : 'Initializing camera...',
                      style: TextStyle(
                        color: AppColors.silverLight.withValues(alpha:0.5),
                        fontSize: 13,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Dark vignette overlay for premium feel
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha:0.3),
                  ],
                ),
              ),
            ),
          ),

          // Center crosshair
          _buildCrosshair(),
        ],
      ),
    );
  }

  // ── Crosshair ──
  Widget _buildCrosshair() {
    return Center(
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Container(
            width: 50 * _pulseAnimation.value,
            height: 50 * _pulseAnimation.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.goldWarm
                    .withValues(alpha:0.25 * _pulseAnimation.value),
                width: 1.5,
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Scan Lines ──
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
                  AppColors.goldWarm.withValues(alpha:0.0),
                  AppColors.goldWarm.withValues(alpha:0.5),
                  AppColors.goldWarm.withValues(alpha:0.0),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Stone Overlay ──
  Widget _buildStoneOverlay() {
    return Positioned(
      left: _overlayPosition!.dx,
      top: _overlayPosition!.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() => _overlayPosition = _overlayPosition! + details.delta);
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
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.goldWarm.withValues(alpha:
                            0.2 * _pulseAnimation.value),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha:0.5),
                        blurRadius: 40,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Stone image
                        Image.network(
                          _selectedStone.imageUrl ?? '',
                          fit: BoxFit.cover,
errorBuilder: (_, _, _) => Container(
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
                        // Animated border
                        AnimatedBuilder(
                          animation: _detecting
                              ? _detectAnimation
                              : _pulseAnimation,
                          builder: (context, child) {
                            final progress = _detecting
                                ? _detectAnimation.value
                                : _pulseAnimation.value;
                            return Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: _detecting
                                      ? AppColors.goldWarm
                                          .withValues(alpha:0.6 + 0.4 * progress)
                                      : AppColors.goldWarm
                                          .withValues(alpha:0.4 * progress),
                                  width: _detecting ? 2.5 : 1.5,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            );
                          },
                        ),
                        // Shimmer overlay on detection
                        if (_detecting)
                          Positioned.fill(
                            child: AnimatedBuilder(
                              animation: _detectAnimation,
                              builder: (context, child) {
                                return Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment(
                                          -1 + 2 * _detectAnimation.value, 0),
                                      end: Alignment(
                                          -0.5 + 2 * _detectAnimation.value, 0),
                                      colors: [
                                        Colors.transparent,
                                        AppColors.goldWarm.withValues(alpha:0.15),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        // Stone name badge
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(12),
                              bottomRight: Radius.circular(12),
                            ),
                            child: BackdropFilter(
                              filter:
                                  ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha:0.6),
                                  border: Border(
                                    top: BorderSide(
                                      color:
                                          AppColors.goldWarm.withValues(alpha:0.2),
                                      width: 0.5,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _selectedStone.name,
                                      style: const TextStyle(
                                        color: AppColors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'Inter',
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Text(
                                          '₹${_selectedStone.pricePerSqFt}/sq ft',
                                          style: const TextStyle(
                                            color: AppColors.goldWarm,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            fontFamily: 'Inter',
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          width: 3,
                                          height: 3,
                                          decoration: const BoxDecoration(
                                            color: AppColors.goldWarm,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _selectedStone.finish,
                                          style: TextStyle(
                                            color: AppColors.silverLight
                                                .withValues(alpha:0.7),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                            fontFamily: 'Inter',
                                          ),
                                        ),
                                      ],
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
      Positioned(top: -3, left: -3, child: _buildHandle()),
      Positioned(top: -3, right: -3, child: _buildHandle()),
      Positioned(bottom: 43, left: -3, child: _buildHandle()),
      Positioned(bottom: 43, right: -3, child: _buildHandle()),
    ];
  }

  Widget _buildHandle() {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: AppColors.goldWarm,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.goldWarm.withValues(alpha:0.6),
            blurRadius: 8,
          ),
        ],
      ),
      child: const Icon(Icons.center_focus_strong,
          size: 9, color: Colors.black),
    );
  }

  // ── Detection Brackets (animated corner brackets during detection) ──
  Widget _buildDetectionBrackets() {
    return Positioned(
      left: _overlayPosition!.dx - 12,
      top: _overlayPosition!.dy - 12,
      child: AnimatedBuilder(
        animation: _detecting ? _detectAnimation : _pulseAnimation,
        builder: (context, child) {
          final opacity = _detecting
              ? _detectAnimation.value
              : _pulseAnimation.value * 0.5;
          final color = _detectionConfidence > 0.8
              ? AppColors.success
              : AppColors.goldWarm;
          return Transform.scale(
            scale: _overlayScale,
            child: SizedBox(
              width: 224,
              height: 224,
              child: CustomPaint(
                painter: _BracketPainter(
                  color: color.withValues(alpha:opacity * 0.7),
                  strokeWidth: 2.5,
                  cornerSize: 24,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Top Bar ──
  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: EdgeInsets.fromLTRB(
                16, MediaQuery.of(context).padding.top + 8, 16, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha:0.75),
                  Colors.black.withValues(alpha:0.0),
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
                      width: 9,
                      height: 9,
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
                                .withValues(alpha:0.7 * _pulseAnimation.value),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 10),
                Text(
                  _isAnalyzing ? 'AI ANALYZING...' : 'LIVE AI READY',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _isAnalyzing
                        ? AppColors.goldWarm
                        : AppColors.success,
                    letterSpacing: 1.8,
                  ),
                ),
                const Spacer(),
                // Camera status
                if (_cameraReady)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha:0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha:0.3),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'CAM',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 8),
                // Toggle info
                GestureDetector(
                  onTap: () => setState(() => _showInfo = !_showInfo),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha:0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha:0.1),
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

  // ── Analysis Badges ──
  Widget _buildAnalysisBadges() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 60,
      left: 16,
      right: 16,
      child: AnimatedBuilder(
        animation: _confidenceAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _confidenceAnimation.value,
            child: Transform.translate(
              offset: Offset(0, 20 * (1 - _confidenceAnimation.value)),
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
                    value: _selectedStone.origin ?? 'India',
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
                    value:
                        '${_selectedStone.rating} (${_selectedStone.reviewCount})',
                    color: AppColors.goldLight,
                  ),
                ],
              ),
            ),
          );
        },
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
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha:0.45),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color.withValues(alpha:0.25),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 7),
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
                      color: color.withValues(alpha:0.7),
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

  // ── Confidence Meter ──
  Widget _buildConfidenceMeter() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 60,
      right: 16,
      child: AnimatedBuilder(
        animation: _confidenceAnimation,
        builder: (context, child) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                width: 52,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha:0.5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.goldWarm.withValues(alpha:0.2),
                    width: 0.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Circular progress
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: _detectionConfidence,
                            strokeWidth: 3,
                            backgroundColor:
                                AppColors.goldWarm.withValues(alpha:0.15),
                            valueColor: AlwaysStoppedAnimation(
                              _detectionConfidence > 0.8
                                  ? AppColors.success
                                  : AppColors.goldWarm,
                            ),
                            strokeCap: StrokeCap.round,
                          ),
                          Center(
                            child: Text(
                              '${(_detectionConfidence * 100).toInt()}',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _detectionConfidence > 0.8
                                    ? AppColors.success
                                    : AppColors.goldWarm,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'MATCH',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 6,
                        fontWeight: FontWeight.w700,
                        color: AppColors.goldWarm.withValues(alpha:0.6),
                        letterSpacing: 1.2,
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

  // ── Controls ──
  Widget _buildControls() {
    return Positioned(
      right: 16,
      top: MediaQuery.of(context).size.height * 0.38,
      child: Column(
        children: [
          _buildControlButton(
            icon: Icons.add,
            onTap: () => setState(
                () => _overlayScale = (_overlayScale + 0.2).clamp(0.5, 3.0)),
          ),
          const SizedBox(height: 12),
          _buildControlButton(
            icon: Icons.remove,
            onTap: () => setState(
                () => _overlayScale = (_overlayScale - 0.2).clamp(0.5, 3.0)),
          ),
          const SizedBox(height: 12),
          _buildControlButton(
            icon: Icons.opacity,
            onTap: () {
              setState(() {
                _overlayOpacity =
                    _overlayOpacity >= 0.9 ? 0.3 : _overlayOpacity + 0.15;
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
                    Offset(size.width * 0.12, size.height * 0.18);
                _overlayScale = 1.0;
              });
            },
          ),
          const SizedBox(height: 12),
          _buildControlButton(
            icon: Icons.play_arrow_rounded,
            onTap: _startDetection,
            isActive: !_detecting,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isActive = true,
  }) {
    return GestureDetector(
      onTap: isActive ? onTap : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.white.withValues(alpha:0.08)
                  : Colors.white.withValues(alpha:0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.goldWarm
                    .withValues(alpha:isActive ? 0.25 : 0.08),
                width: 0.5,
              ),
            ),
            child: Icon(icon,
                size: 22,
                color: AppColors.goldWarm
                    .withValues(alpha:isActive ? 1.0 : 0.3)),
          ),
        ),
      ),
    );
  }

  // ── Bottom Tiles ──
  Widget _buildBottomTiles() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: 185,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha:0.92),
                  Colors.black.withValues(alpha:0.7),
                  Colors.black.withValues(alpha:0.0),
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
                    color: Colors.white.withValues(alpha:0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Label
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 20,
                        height: 0.5,
                        color: AppColors.goldWarm.withValues(alpha:0.3),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'SWIPE TO SELECT STONE',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: AppColors.goldWarm.withValues(alpha:0.6),
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 20,
                        height: 0.5,
                        color: AppColors.goldWarm.withValues(alpha:0.3),
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
                        _detectionConfidence = 0.0;
                        _detecting = false;
                      });
                      _startDetection();
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
                                    : AppColors.goldWarm.withValues(alpha:0.15),
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppColors.goldWarm
                                            .withValues(alpha:0.3),
                                        blurRadius: 14,
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
                                  Image.network(
                                    stone.imageUrl ?? '',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Container(
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
                                            Colors.black.withValues(alpha:0.85),
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
                                            style: const TextStyle(
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
                                  if (isSelected)
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: Container(
                                        width: 18,
                                        height: 18,
                                        decoration: BoxDecoration(
                                          color: AppColors.goldWarm,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.goldWarm
                                                  .withValues(alpha:0.6),
                                              blurRadius: 8,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(Icons.check,
                                            size: 11, color: Colors.black),
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

// ── Corner Bracket Painter ──
class _BracketPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double cornerSize;

  _BracketPainter({
    required this.color,
    this.strokeWidth = 2.0,
    this.cornerSize = 20,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final double s = cornerSize;

    // Top-left
    canvas.drawLine(const Offset(0, 0), Offset(s, 0), paint);
    canvas.drawLine(const Offset(0, 0), Offset(0, s), paint);

    // Top-right
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - s, 0), paint);
    canvas.drawLine(
        Offset(size.width, 0), Offset(size.width, s), paint);

    // Bottom-left
    canvas.drawLine(
        Offset(0, size.height), Offset(s, size.height), paint);
    canvas.drawLine(
        Offset(0, size.height), Offset(0, size.height - s), paint);

    // Bottom-right
    canvas.drawLine(Offset(size.width, size.height),
        Offset(size.width - s, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height),
        Offset(size.width, size.height - s), paint);
  }

  @override
  bool shouldRepaint(covariant _BracketPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}
