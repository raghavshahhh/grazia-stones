import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/providers/stone_providers.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/shared/widgets/smart_stone_image.dart';

/// Architectural Studio & AI Tools Hub Screen.
/// Provides a unified luxury dashboard for all interactive tools:
/// 1. Live AR Wall Visualizer
/// 2. AI Room Studio (Photo Generator)
/// 3. Room & Wall Measurement Tool
/// 4. 3D Wall & Tile Calculator
/// 5. Order Material Sample Swatches
/// 6. Request Architectural Quote
class AiToolsHubScreen extends ConsumerWidget {
  const AiToolsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(themePaletteProvider);
    final isDark = ref.watch(themePaletteProvider.notifier).isDarkMode;
    final stonesAsync = ref.watch(allStonesProvider);
    final stones = stonesAsync.valueOrNull ?? [];

    return Scaffold(
      backgroundColor: palette.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Luxury App Bar
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            backgroundColor: isDark
                ? const Color(0xFF121212).withValues(alpha: 0.92)
                : Colors.white.withValues(alpha: 0.92),
            elevation: 0,
            scrolledUnderElevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: palette.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: palette.primary.withValues(alpha: 0.35),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          'SPATIAL SUITE',
                          style: GoogleFonts.inter(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: palette.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'AI & Studio Tools',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Tools Content
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Hero Subtitle
                Text(
                  'Next-generation architectural visualization and precision calculation tools.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: palette.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),

                // FEATURE 1: Live AR Visualizer (Hero Card)
                _buildHeroToolCard(
                  context: context,
                  palette: palette,
                  isDark: isDark,
                  title: 'Live AR Wall Visualizer',
                  tag: 'REAL-TIME CAMERA',
                  description:
                      'Point your phone camera at any room wall to project actual stone textures in 1:1 scale.',
                  icon: Icons.camera_rounded,
                  badgeText: 'Live Spatial AR',
                  buttonText: 'Open AR Camera',
                  gradientColors: [
                    const Color(0xFF1E1B18),
                    const Color(0xFF2C241B),
                  ],
                  accentColor: palette.primary,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/live-ai');
                  },
                ),
                const SizedBox(height: 16),

                // FEATURE 2: AI Room Studio (Hero Card)
                _buildHeroToolCard(
                  context: context,
                  palette: palette,
                  isDark: isDark,
                  title: 'AI Room Studio',
                  tag: 'GENERATIVE RENDERING',
                  description:
                      'Upload a photo of your living room, bathroom, or facade to render photorealistic stone surfaces.',
                  icon: Icons.auto_awesome_rounded,
                  badgeText: 'Generative AI',
                  buttonText: 'Launch AI Studio',
                  gradientColors: [
                    const Color(0xFF171A21),
                    const Color(0xFF1E2638),
                  ],
                  accentColor: const Color(0xFF64B5F6),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/ai-viz');
                  },
                ),
                const SizedBox(height: 28),

                // SECTION: Precision Utility Tools
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 16,
                      decoration: BoxDecoration(
                        color: palette.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'PRECISION TOOLS',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: palette.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Grid of 4 Core Tools
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.05,
                  children: [
                    // Tool: Wall Measurement
                    _buildGridToolCard(
                      context: context,
                      palette: palette,
                      title: 'Room Measure',
                      subtitle: 'AR Wall Dimensioning',
                      icon: Icons.straighten_rounded,
                      color: const Color(0xFF10B981),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.push('/measure');
                      },
                    ),

                    // Tool: 3D Tile Calculator
                    _buildGridToolCard(
                      context: context,
                      palette: palette,
                      title: '3D Wall Calc',
                      subtitle: 'Tile & Box Quantity',
                      icon: Icons.view_in_ar_rounded,
                      color: const Color(0xFFF59E0B),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.push('/wall-calc');
                      },
                    ),

                    // Tool: Sample Box Request
                    _buildGridToolCard(
                      context: context,
                      palette: palette,
                      title: 'Sample Box',
                      subtitle: 'Physical Swatch Kit',
                      icon: Icons.inventory_2_outlined,
                      color: const Color(0xFF8B5CF6),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.push('/samples/request');
                      },
                    ),

                    // Tool: Custom Quote Request
                    _buildGridToolCard(
                      context: context,
                      palette: palette,
                      title: 'Get Quote',
                      subtitle: 'Direct Factory Pricing',
                      icon: Icons.request_quote_outlined,
                      color: const Color(0xFFEC4899),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.push('/quotes/new');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // SECTION: Quick Stone Launch Pad
                if (stones.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 3,
                            height: 16,
                            decoration: BoxDecoration(
                              color: palette.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'QUICK STONE LAUNCHPAD',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                              color: palette.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () => context.go('/collections'),
                        child: Text(
                          'View All',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: palette.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 180,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: stones.take(6).length,
                      separatorBuilder: (_, __) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final stone = stones[index];
                        return _buildStoneQuickLaunchCard(
                          context: context,
                          palette: palette,
                          stone: stone,
                        );
                      },
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroToolCard({
    required BuildContext context,
    required dynamic palette,
    required bool isDark,
    required String title,
    required String tag,
    required String description,
    required IconData icon,
    required String badgeText,
    required String buttonText,
    required List<Color> gradientColors,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.5),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 12, color: accentColor),
                          const SizedBox(width: 5),
                          Text(
                            tag,
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.1),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.78),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            buttonText,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 11,
                            color: Colors.black,
                          ),
                        ],
                      ),
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

  Widget _buildGridToolCard({
    required BuildContext context,
    required dynamic palette,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: palette.textSecondary,
                      ),
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

  Widget _buildStoneQuickLaunchCard({
    required BuildContext context,
    required dynamic palette,
    required Stone stone,
  }) {
    return Container(
      width: 135,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/stones/${stone.id}'),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                child: SizedBox(
                  height: 95,
                  width: double.infinity,
                  child: SmartStoneImage(
                    imageUrl: stone.imageUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stone.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹${stone.pricePerSqFt.toStringAsFixed(0)}/sqft',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: palette.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
