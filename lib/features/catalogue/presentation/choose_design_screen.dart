import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/core/providers/stone_providers.dart';

/// Screen 7: Choose a Design (Select Design)
/// Matches Client Reference Sheet Screen 7:
/// - "Choose a Design"
/// - Filter chips: All, 3D Panels, Fluted, CNC
/// - 2-column grid of stone cards: Ivory Waves, Desert Stone, Classic Beige, Grey Texture, Crystal White, Earth Brown
/// - Bottom Gold Button: "View in My Space" -> leads to /ai-visualization (Screen 8)
class ChooseDesignScreen extends ConsumerStatefulWidget {
  const ChooseDesignScreen({super.key});

  @override
  ConsumerState<ChooseDesignScreen> createState() => _ChooseDesignScreenState();
}

class _ChooseDesignScreenState extends ConsumerState<ChooseDesignScreen> {
  int _selectedFilter = 0;
  final List<String> _filters = ['All', '3D Panels', 'Fluted', 'CNC'];
  String _selectedDesign = 'Desert Stone';

  final List<Map<String, String>> _designs = [
    {
      'id': 'ivory_waves',
      'name': 'Ivory Waves',
      'category': '3D Panels',
      'image': 'assets/images/classic_ledge_07.png',
      'price': '₹480/sq.ft'
    },
    {
      'id': 'desert_stone',
      'name': 'Desert Stone',
      'category': '3D Panels',
      'image': 'assets/images/grande_ledge_ta02.png',
      'price': '₹580/sq.ft'
    },
    {
      'id': 'classic_beige',
      'name': 'Classic Beige',
      'category': 'Fluted',
      'image': 'assets/images/mountain_ledge_m08.png',
      'price': '₹450/sq.ft'
    },
    {
      'id': 'grey_texture',
      'name': 'Grey Texture',
      'category': 'Fluted',
      'image': 'assets/images/opus_ledge_15.png',
      'price': '₹520/sq.ft'
    },
    {
      'id': 'crystal_white',
      'name': 'Crystal White',
      'category': 'CNC',
      'image': 'assets/images/verona_3d.png',
      'price': '₹620/sq.ft'
    },
    {
      'id': 'earth_brown',
      'name': 'Earth Brown',
      'category': 'CNC',
      'image': 'assets/images/vantage_v12.png',
      'price': '₹550/sq.ft'
    },
  ];

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);
    final isDark = ref.watch(themePaletteProvider.notifier).isDarkMode;
    final stonesAsync = ref.watch(allStonesProvider);

    // Merge Supabase stones if available
    final dbStones = stonesAsync.valueOrNull ?? [];

    final activeFilterName = _filters[_selectedFilter];
    final filteredDesigns = activeFilterName == 'All'
        ? _designs
        : _designs.where((d) => d['category'] == activeFilterName).toList();

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
          'Choose a Design',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter Chips Row
          SizedBox(
            height: 46,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              itemBuilder: (context, i) {
                final isSelected = _selectedFilter == i;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _selectedFilter = i);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFD4AF37)
                            : (isDark ? const Color(0xFF1C1A17) : const Color(0xFFF0EBE1)),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFD4AF37)
                              : palette.border,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _filters[i],
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? Colors.black : palette.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // 2-Column Grid of Stone Cards
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              itemCount: filteredDesigns.length,
              itemBuilder: (context, i) {
                final design = filteredDesigns[i];
                final isSelected = _selectedDesign == design['name'];

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _selectedDesign = design['name']!);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFD4AF37)
                            : palette.border,
                        width: isSelected ? 2.0 : 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isSelected
                              ? const Color(0xFFD4AF37).withValues(alpha: 0.18)
                              : Colors.black.withValues(alpha: 0.04),
                          blurRadius: isSelected ? 12 : 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Stone Image Square
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.asset(
                                  design['image']!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(color: const Color(0xFF222222)),
                                ),
                                if (isSelected)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFD4AF37),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.check_rounded, size: 14, color: Colors.black),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        // Title & Category
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                design['name']!,
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: palette.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                design['price']!,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFFD4AF37),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom Gold CTA: View in My Space
          Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom > 0
                  ? MediaQuery.of(context).padding.bottom + 8
                  : 18,
            ),
            decoration: BoxDecoration(
              color: palette.surface,
              border: Border(top: BorderSide(color: palette.border)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  context.push('/ai-visualization?stoneName=${Uri.encodeComponent(_selectedDesign)}');
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
                      'View in My Space',
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
        ],
      ),
    );
  }
}
