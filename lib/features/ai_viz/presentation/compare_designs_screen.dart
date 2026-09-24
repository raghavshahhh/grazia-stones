import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';

/// Screen 10: Compare Designs
/// Matches Client Reference Sheet Screen 10:
/// - "Compare Designs"
/// - 3-column vertical comparison or split view: Design 1, Design 2, Design 3
/// - Finish swatches: Natural, Polished, Matt, Textured
/// - Gold CTA Button: "View Details" -> leads to Product Details (Screen 11)
class CompareDesignsScreen extends ConsumerStatefulWidget {
  const CompareDesignsScreen({super.key});

  @override
  ConsumerState<CompareDesignsScreen> createState() => _CompareDesignsScreenState();
}

class _CompareDesignsScreenState extends ConsumerState<CompareDesignsScreen> {
  int _selectedDesignIndex = 0;
  int _selectedFinish = 2; // 0 = Natural, 1 = Polished, 2 = Matt, 3 = Textured

  final List<Map<String, String>> _designs = [
    {
      'id': 'grande_ledge_ta02',
      'label': 'Design 1',
      'name': 'Desert Stone',
      'asset': 'assets/images/grande_ledge_ta02.png',
      'panelType': '3D Stone Panel',
    },
    {
      'id': 'opus_ledge_15',
      'label': 'Design 2',
      'name': 'Grey Texture',
      'asset': 'assets/images/opus_ledge_15.png',
      'panelType': 'Fluted Panel',
    },
    {
      'id': 'verona_3d',
      'label': 'Design 3',
      'name': 'Crystal White',
      'asset': 'assets/images/verona_3d.png',
      'panelType': 'CNC Carved',
    },
  ];

  final List<String> _finishes = ['Natural', 'Polished', 'Matt', 'Textured'];

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);
    final isDark = ref.watch(themePaletteProvider.notifier).isDarkMode;
    final activeDesign = _designs[_selectedDesignIndex];

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
        title: Text(
          'Compare Designs',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),

            // 3 Vertical Comparative Columns
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: List.generate(_designs.length, (i) {
                    final d = _designs[i];
                    final isSelected = _selectedDesignIndex == i;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _selectedDesignIndex = i);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          margin: EdgeInsets.only(
                            left: i == 0 ? 0 : 4,
                            right: i == _designs.length - 1 ? 0 : 4,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? const Color(0xFFD4AF37) : palette.border,
                              width: isSelected ? 2.5 : 0.8,
                            ),
                            boxShadow: [
                              if (isSelected)
                                BoxShadow(
                                  color: const Color(0xFFD4AF37).withValues(alpha: 0.25),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.asset(
                                  d['asset']!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(color: const Color(0xFF222222)),
                                ),

                                // Gradient overlay
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.black.withValues(alpha: 0.4),
                                        Colors.transparent,
                                        Colors.black.withValues(alpha: 0.8),
                                      ],
                                    ),
                                  ),
                                ),

                                // Top Label: Design 1 / 2 / 3
                                Positioned(
                                  top: 12,
                                  left: 8,
                                  right: 8,
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFFD4AF37) : Colors.black.withValues(alpha: 0.6),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        d['label']!,
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected ? Colors.black : Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Bottom Name
                                Positioned(
                                  bottom: 12,
                                  left: 6,
                                  right: 6,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        d['name']!,
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.playfairDisplay(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        d['panelType']!,
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.inter(
                                          fontSize: 9,
                                          color: Colors.white70,
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
                  }),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Finish Selector Swatches (Natural, Polished, Matt, Textured)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FINISH OPTIONS',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: palette.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(_finishes.length, (i) {
                      final isSelected = _selectedFinish == i;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _selectedFinish = i);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFD4AF37)
                                : (isDark ? const Color(0xFF1E1C19) : const Color(0xFFEFEBE4)),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? const Color(0xFFD4AF37) : palette.border,
                            ),
                          ),
                          child: Text(
                            _finishes[i],
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? Colors.black : palette.textPrimary,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Bottom CTA: View Details
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    context.push('/stone/${activeDesign['id']}');
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
                        'View Details (${activeDesign['name']})',
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
