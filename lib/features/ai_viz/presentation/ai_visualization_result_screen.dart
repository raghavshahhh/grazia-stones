import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/shared/widgets/luxury_toast.dart';

/// Screen 8: AI Visualization Result
/// Matches Client Reference Sheet Screen 8:
/// - "AI Visualization"
/// - Photorealistic rendered living room with applied stone cladding
/// - Split comparison toggle: "Original | Grazia Design"
/// - "Your Space, Reimagined with GRAZIA STONES"
/// - Quick action icons: Save, Share, View in VR
/// - Gold CTA: "Change Design" / "Customize Design" -> leads to Screen 9 & 10
class AiVisualizationResultScreen extends ConsumerStatefulWidget {
  final String stoneName;

  const AiVisualizationResultScreen({
    super.key,
    this.stoneName = 'Desert Stone',
  });

  @override
  ConsumerState<AiVisualizationResultScreen> createState() => _AiVisualizationResultScreenState();
}

class _AiVisualizationResultScreenState extends ConsumerState<AiVisualizationResultScreen> {
  bool _showGraziaDesign = true; // Toggle between Original and Grazia Design
  bool _isSaved = false;

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);
    final isDark = ref.watch(themePaletteProvider.notifier).isDarkMode;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: Text(
          'AI Visualization',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Full Screen Rendered Space Image (Original vs Grazia Design)
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 350),
            crossFadeState: _showGraziaDesign ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Image.asset(
              'assets/images/hero_banner_2.png',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, _, _) => Container(color: const Color(0xFF1E1E1E)),
            ),
            secondChild: Image.asset(
              'assets/images/hero_banner_1.png',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, _, _) => Container(color: const Color(0xFF2E2E2E)),
            ),
          ),

          // Subtle gradient overlay for readability
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black,
                  Colors.black,
                  Colors.black.withValues(alpha: 0.6),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.9),
                ],
                stops: const [0.0, 0.12, 0.20, 0.32, 0.6, 1.0],
              ),
            ),
          ),

          // 2. Interactive Toggle: Original | Grazia Design
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white24, width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _showGraziaDesign = false);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                        decoration: BoxDecoration(
                          color: !_showGraziaDesign ? const Color(0xFFD4AF37) : Colors.transparent,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          'Original',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: !_showGraziaDesign ? FontWeight.w700 : FontWeight.w500,
                            color: !_showGraziaDesign ? Colors.black : Colors.white70,
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _showGraziaDesign = true);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                        decoration: BoxDecoration(
                          color: _showGraziaDesign ? const Color(0xFFD4AF37) : Colors.transparent,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_showGraziaDesign)
                              const Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Icon(Icons.auto_awesome_rounded, size: 13, color: Colors.black),
                              ),
                            Text(
                              'Grazia Design',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: _showGraziaDesign ? FontWeight.w700 : FontWeight.w500,
                                color: _showGraziaDesign ? Colors.black : Colors.white70,
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

          // 3. Bottom Reimagined Panel & Actions
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).padding.bottom > 0
                    ? MediaQuery.of(context).padding.bottom + 10
                    : 24,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141311).withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title: Your Space, Reimagined
                  Text(
                    'Your Space, Reimagined',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'with GRAZIA STONES (${widget.stoneName})',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFD4AF37),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Action Icons: Save | Share | View in VR
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionItem(
                        icon: _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                        label: 'Save',
                        isActive: _isSaved,
                        palette: palette,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _isSaved = !_isSaved);
                          LuxuryToast.show(
                            context,
                            message: _isSaved ? 'Design saved to Saved Designs' : 'Design removed',
                          );
                        },
                      ),
                      _buildActionItem(
                        icon: Icons.share_outlined,
                        label: 'Share',
                        palette: palette,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          LuxuryToast.show(context, message: 'Share link copied');
                        },
                      ),
                      _buildActionItem(
                        icon: Icons.view_in_ar_rounded,
                        label: 'View in VR',
                        palette: palette,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          context.push('/vr-showroom');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Bottom Two Buttons: Customize Design & Compare Designs
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            context.push('/customize-design?stoneName=${Uri.encodeComponent(widget.stoneName)}');
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: palette.border, width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            'Customize',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: palette.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            context.push('/compare-designs');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD4AF37),
                            foregroundColor: const Color(0xFF121212),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: Text(
                            'Compare Designs',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF121212),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String label,
    required LuxuryPalette palette,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFFD4AF37).withValues(alpha: 0.15) : palette.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? const Color(0xFFD4AF37) : palette.border,
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isActive ? const Color(0xFFD4AF37) : palette.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
