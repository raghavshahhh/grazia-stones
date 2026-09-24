import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';

/// Screen 6: Wall Measurement (Wall Detected)
/// Matches Client Reference Sheet Screen 6:
/// - "Wall Detected"
/// - "We have measured your wall"
/// - Viewfinder preview with dimension overlays: "12.0 ft (W)", "9.0 ft (H)"
/// - Bottom Cream/White Card:
///     Wall Area: 108 sq.ft.
///     Estimated Panels: 4 Panels (8' x 4' each)
/// - Gold Button: "Proceed to Design" -> leads to /choose-design (Screen 7)
class WallMeasurementScreen extends ConsumerStatefulWidget {
  const WallMeasurementScreen({super.key});

  @override
  ConsumerState<WallMeasurementScreen> createState() => _WallMeasurementScreenState();
}

class _WallMeasurementScreenState extends ConsumerState<WallMeasurementScreen> {
  final double _widthFt = 12.0;
  final double _heightFt = 9.0;

  double get _areaSqFt => _widthFt * _heightFt;
  int get _panelsNeeded => (_areaSqFt / 32.0).ceil(); // 8'x4' = 32 sq.ft

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);
    final isDark = ref.watch(themePaletteProvider.notifier).isDarkMode;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: palette.textPrimary, size: 18),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: Column(
          children: [
            Text(
              'Wall Detected',
              style: GoogleFonts.playfairDisplay(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
            Text(
              'We have measured your wall',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: palette.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),

            // Dimensioned Viewfinder Box
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: palette.border, width: 0.8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(19),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Room image
                        Image.asset(
                          'assets/images/onboarding_1.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(color: const Color(0xFF1E1E1E)),
                        ),

                        // Measured Wall Reticle with Dimension Overlays
                        Center(
                          child: Container(
                            width: MediaQuery.of(context).size.width * 0.72,
                            height: 230,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFF00E676),
                                width: 2,
                                style: BorderStyle.solid,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              color: const Color(0xFF00E676).withValues(alpha: 0.08),
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // Top dimension label: 12.0 ft (W)
                                Positioned(
                                  top: -14,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.85),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFF00E676), width: 1),
                                      ),
                                      child: Text(
                                        '${_widthFt.toStringAsFixed(1)} ft (W)',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF00E676),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Right dimension label: 9.0 ft (H)
                                Positioned(
                                  right: -20,
                                  top: 0,
                                  bottom: 0,
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.85),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFF00E676), width: 1),
                                      ),
                                      child: Text(
                                        '${_heightFt.toStringAsFixed(1)} ft (H)',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF00E676),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Center badge
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.75),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      'Surface Area: ${_areaSqFt.toStringAsFixed(0)} sq.ft.',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
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
            ),

            const SizedBox(height: 16),

            // Bottom Measurement & Panel Calculation Card (Cream / White Luxury)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBF9F5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFE5DDD0),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Wall Area
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Wall Area',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF6B655B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_areaSqFt.toInt()} sq.ft.',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF141210),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Container(
                      height: 42,
                      width: 1,
                      color: const Color(0xFFE5DDD0),
                    ),
                    const SizedBox(width: 18),

                    // Estimated Panels
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Estimated Panels',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF6B655B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$_panelsNeeded Panels',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF141210),
                            ),
                          ),
                          Text(
                            '(8\' x 4\' each)',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF8C857B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Proceed to Design Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    context.push('/choose-design');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: const Color(0xFF121212),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Proceed to Design',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: const Color(0xFF121212),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 18, color: Color(0xFF121212)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }
}
