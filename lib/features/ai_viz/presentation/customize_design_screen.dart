import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';

/// Screen 9: Customize Design
/// Matches Client Reference Sheet Screen 9:
/// - "Customize Design"
/// - Large stone panel preview with heart/favorite
/// - Tabs: Colour, Finish, Layout
/// - Color swatches: Beige, Grey, Brown, White
/// - Gold Button: "Apply to My Space" -> leads to /compare-designs (Screen 10)
class CustomizeDesignScreen extends ConsumerStatefulWidget {
  final String stoneName;

  const CustomizeDesignScreen({
    super.key,
    this.stoneName = 'Desert Stone',
  });

  @override
  ConsumerState<CustomizeDesignScreen> createState() => _CustomizeDesignScreenState();
}

class _CustomizeDesignScreenState extends ConsumerState<CustomizeDesignScreen> {
  int _selectedTab = 0; // 0 = Colour, 1 = Finish, 2 = Layout
  int _selectedColorIndex = 0;
  int _selectedFinishIndex = 0;
  bool _isFavorite = true;

  final List<String> _tabs = ['Colour', 'Finish', 'Layout'];

  final List<Map<String, dynamic>> _colors = [
    {'name': 'Beige', 'color': Color(0xFFD8C7B5), 'asset': 'assets/images/grande_ledge_ta02.png'},
    {'name': 'Grey', 'color': Color(0xFF8E9094), 'asset': 'assets/images/opus_ledge_15.png'},
    {'name': 'Brown', 'color': Color(0xFF6E5544), 'asset': 'assets/images/vantage_v12.png'},
    {'name': 'White', 'color': Color(0xFFECECEC), 'asset': 'assets/images/verona_3d.png'},
  ];

  final List<String> _finishes = ['Natural', 'Polished', 'Matt', 'Textured'];
  final List<String> _layouts = ['Horizontal Stagger', 'Grid Alignment', 'Vertical Flute', 'Randomized Bookmatch'];

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);
    final isDark = ref.watch(themePaletteProvider.notifier).isDarkMode;
    final currentAsset = _colors[_selectedColorIndex]['asset'] as String;

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
          'Customize Design',
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
            // 1. Large Stone Panel Render Box
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: palette.border, width: 0.8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(21),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Image.asset(
                            currentAsset,
                            key: ValueKey(currentAsset),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (_, _, _) => Container(color: const Color(0xFF222222)),
                          ),
                        ),

                        // Heart / Favorite Icon in top right
                        Positioned(
                          top: 14,
                          right: 14,
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _isFavorite = !_isFavorite);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                color: _isFavorite ? const Color(0xFFD4AF37) : Colors.white,
                                size: 20,
                              ),
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

            // Stone Title & Category
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.stoneName,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                    ),
                    Text(
                      '3D Luxury Stone Panel',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tab Selector: Colour | Finish | Layout
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1C19) : const Color(0xFFEFEBE4),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: List.generate(_tabs.length, (i) {
                    final isSelected = _selectedTab == i;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _selectedTab = i);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFD4AF37) : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: Text(
                              _tabs[i],
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? Colors.black : palette.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Tab Content
            if (_selectedTab == 0) ...[
              // Colour Swatches Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(_colors.length, (i) {
                    final colorData = _colors[i];
                    final isSelected = _selectedColorIndex == i;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _selectedColorIndex = i);
                      },
                      child: Column(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: colorData['color'] as Color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? const Color(0xFFD4AF37) : Colors.black26,
                                width: isSelected ? 3.0 : 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: isSelected
                                ? const Icon(Icons.check_rounded, color: Colors.black, size: 22)
                                : null,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            colorData['name'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? const Color(0xFFD4AF37) : palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ] else if (_selectedTab == 1) ...[
              // Finish Selector
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 10,
                  children: List.generate(_finishes.length, (i) {
                    final isSelected = _selectedFinishIndex == i;
                    return ChoiceChip(
                      label: Text(_finishes[i]),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _selectedFinishIndex = i),
                      selectedColor: const Color(0xFFD4AF37),
                      backgroundColor: palette.surface,
                      labelStyle: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.black : palette.textPrimary,
                      ),
                    );
                  }),
                ),
              ),
            ] else ...[
              // Layout Selector
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: _layouts.map((l) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.grid_view_rounded, color: palette.primary, size: 18),
                      title: Text(l, style: GoogleFonts.inter(fontSize: 13, color: palette.textPrimary)),
                      trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                      onTap: () {},
                    );
                  }).toList(),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Apply to My Space Gold Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    context.push('/compare-designs');
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
                        'Apply to My Space',
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
