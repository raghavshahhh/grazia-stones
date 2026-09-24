import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';

/// Screen 5: Scan My Space (AI Camera Scan)
/// Matches Client Reference Sheet Screen 5:
/// - "Scan My Space"
/// - "Use your camera to scan the wall and get accurate measurements"
/// - Full-screen camera viewfinder with green bounding reticle
/// - Controls: Gallery, Flash, Shutter, Photo/Video mode
/// - Shutter click transitions to Screen 6: Wall Detected
class ScanSpaceScreen extends ConsumerStatefulWidget {
  const ScanSpaceScreen({super.key});

  @override
  ConsumerState<ScanSpaceScreen> createState() => _ScanSpaceScreenState();
}

class _ScanSpaceScreenState extends ConsumerState<ScanSpaceScreen> with SingleTickerProviderStateMixin {
  bool _isFlashOn = false;
  int _selectedMode = 0; // 0 = Photo, 1 = Video
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _onCapture() {
    HapticFeedback.heavyImpact();
    // Simulate capture and proceed to Wall Detected screen (Screen 6)
    context.push('/wall-measurement');
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themePaletteProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Simulated Realistic Camera Background (Room Wall)
          Image.asset(
            'assets/images/onboarding_1.png',
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(color: const Color(0xFF141414)),
          ),

          // Dark vignette overlay with solid header protection
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black,
                  Colors.black,
                  Colors.black.withValues(alpha: 0.5),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.8),
                  Colors.black,
                ],
                stops: const [0.0, 0.14, 0.18, 0.28, 0.70, 0.85, 1.0],
              ),
            ),
          ),

          // 2. Green AR Bounding Box with Corner Guides
          Center(
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: child,
                );
              },
              child: Container(
                width: MediaQuery.of(context).size.width * 0.78,
                height: MediaQuery.of(context).size.height * 0.42,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFF00E676),
                    width: 2.0,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  color: const Color(0xFF00E676).withValues(alpha: 0.08),
                ),
                child: Stack(
                  children: [
                    // Corner reticle accents
                    _buildCornerBracket(top: true, left: true),
                    _buildCornerBracket(top: true, left: false),
                    _buildCornerBracket(top: false, left: true),
                    _buildCornerBracket(top: false, left: false),

                    // Wall detection indicator label
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF00E676), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF00E676),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Align with your Wall',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
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

          // 3. Top Header Bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                      onPressed: () => context.pop(),
                    ),
                    Text(
                      'Scan My Space',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Use your camera to scan the wall and get accurate measurements',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 4. Bottom Camera Controls
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 20,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Photo / Video Mode Toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildModeButton(title: 'Photo', index: 0),
                    const SizedBox(width: 24),
                    _buildModeButton(title: 'Video', index: 1),
                  ],
                ),
                const SizedBox(height: 24),

                // Controls Row: Gallery | Shutter | Flash
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Gallery Icon Button
                      IconButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          // Pick from gallery simulation -> proceeds to wall measurement
                          context.push('/wall-measurement');
                        },
                        icon: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white30),
                          ),
                          child: const Icon(Icons.photo_library_outlined, color: Colors.white, size: 22),
                        ),
                      ),

                      // Large Shutter Button
                      GestureDetector(
                        onTap: _onCapture,
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          child: Center(
                            child: Container(
                              width: 62,
                              height: 62,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Flash Icon Button
                      IconButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          setState(() => _isFlashOn = !_isFlashOn);
                        },
                        icon: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: _isFlashOn ? const Color(0xFFD4AF37) : Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white30),
                          ),
                          child: Icon(
                            _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                            color: _isFlashOn ? Colors.black : Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCornerBracket({required bool top, required bool left}) {
    return Positioned(
      top: top ? -2 : null,
      bottom: !top ? -2 : null,
      left: left ? -2 : null,
      right: !left ? -2 : null,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          border: Border(
            top: top ? const BorderSide(color: Color(0xFF00E676), width: 4) : BorderSide.none,
            bottom: !top ? const BorderSide(color: Color(0xFF00E676), width: 4) : BorderSide.none,
            left: left ? const BorderSide(color: Color(0xFF00E676), width: 4) : BorderSide.none,
            right: !left ? const BorderSide(color: Color(0xFF00E676), width: 4) : BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildModeButton({required String title, required int index}) {
    final isSelected = _selectedMode == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _selectedMode = index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD4AF37) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.black : Colors.white70,
          ),
        ),
      ),
    );
  }
}
