import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';

import 'package:grazia_stones/core/providers/stone_providers.dart';
import 'package:grazia_stones/core/services/mock_data_service.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/shared/widgets/smart_stone_image.dart';

/// Screen 13: VR Showroom
/// Matches Client Reference Sheet Screen 13:
/// - "VR Showroom"
/// - Filter chips: All, Living Room, Hotel Lobby, Commercial
/// - Featured luxury 3D Virtual Showroom card
/// - Gold Button: "Enter 3D Showroom" / "Start VR Experience"
/// - "Walk through our virtual space and experience Grazia designs in real scale."
/// - "AR-Enabled 3D Wall Collection" - real products with direct 3D placement
/// - "Explore Our Spaces" grid: Living Room, Hotel Lobby, Restaurant, Bedroom
class VrShowroomScreen extends ConsumerStatefulWidget {
  const VrShowroomScreen({super.key});

  @override
  ConsumerState<VrShowroomScreen> createState() => _VrShowroomScreenState();
}

class _VrShowroomScreenState extends ConsumerState<VrShowroomScreen> {
  int _selectedFilter = 0;
  final List<String> _filters = ['All', 'Living Room', 'Hotel Lobby', 'Commercial'];

  final List<Map<String, String>> _spaces = [
    {
      'title': 'Living Room',
      'image': 'assets/images/home_hero_living_room.jpg',
      'panels': 'Athena 3D & Desert Stone',
      'stoneId': 'ATHENA',
      'category': 'Living Room',
    },
    {
      'title': 'Hotel Lobby',
      'image': 'assets/images/hero_luxury_fireplace.jpg',
      'panels': 'Verona Marble Grand Wall',
      'stoneId': 'VERONA',
      'category': 'Hotel Lobby',
    },
    {
      'title': 'Restaurant',
      'image': 'assets/images/hero_luxury_dining_fluted.jpg',
      'panels': 'Rustic Mountain Ledge',
      'stoneId': 'TAK05',
      'category': 'Commercial',
    },
    {
      'title': 'Bedroom',
      'image': 'assets/images/hero_luxury_bedroom.jpg',
      'panels': 'Opus Ledge 15 Textured Wall',
      'stoneId': 'Opus03',
      'category': 'Living Room',
    },
    {
      'title': 'Office Boardroom',
      'image': 'assets/images/onboarding_hero_room.jpg',
      'panels': 'Vantage V12 Linear Panels',
      'stoneId': 'Vantage203',
      'category': 'Commercial',
    },
    {
      'title': 'Exterior Facade',
      'image': 'assets/images/auth_luxury_background.jpg',
      'panels': 'Grande Ledge ATY 10 Facade',
      'stoneId': 'ATY10',
      'category': 'Commercial',
    },
  ];

  List<Map<String, String>> get _filteredSpaces {
    if (_selectedFilter == 0) return _spaces;
    final filter = _filters[_selectedFilter];
    return _spaces.where((s) => s['category'] == filter || s['title'] == filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);
    final isDark = ref.watch(themePaletteProvider.notifier).isDarkMode;
    final displayedSpaces = _filteredSpaces;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: palette.textPrimary, size: 18),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        centerTitle: true,
        title: Text(
          'VR Showroom',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.view_in_ar_rounded, color: palette.primary, size: 22),
            onPressed: () => context.push('/vr-spaces'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter Pills
            SizedBox(
              height: 42,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
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
                              : (isDark ? const Color(0xFF1E1C19) : const Color(0xFFEFEBE4)),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? const Color(0xFFD4AF37) : palette.border,
                          ),
                        ),
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
                  );
                },
              ),
            ),
            const SizedBox(height: 18),

            // Featured 3D Virtual Showroom Card
            Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
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
                borderRadius: BorderRadius.circular(21),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/images/hero_luxury_fireplace.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(color: const Color(0xFF1E1E1E)),
                    ),

                    // Gradient overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.85),
                          ],
                        ),
                      ),
                    ),

                    // Content overlay inside card
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4AF37),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '360° IMMERSIVE AR/VR',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Step into Our Virtual Showroom',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                context.push('/live-ai');
                              },
                              icon: const Icon(Icons.view_in_ar_rounded, size: 18, color: Color(0xFF121212)),
                              label: Text(
                                'Enter 3D Showroom',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF121212),
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD4AF37),
                                foregroundColor: const Color(0xFF121212),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Descriptive walkthrough text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Walk through our virtual space and experience Grazia designs in real scale.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: palette.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 22),

            // 3D Wall Compatible Collection Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '3D Wall AR Products',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'All designs ready for real-time 3D wall placement',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/live-ai'),
                  child: Text(
                    'Launch AR >',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFD4AF37),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildArProductsCarousel(context, palette, isDark),
            const SizedBox(height: 26),

            // Explore Our Spaces Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Explore Our Spaces',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/vr-spaces'),
                  child: Text(
                    'View All >',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFD4AF37),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 2-column Grid of spaces
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.15,
              ),
              itemCount: displayedSpaces.length,
              itemBuilder: (context, i) {
                final space = displayedSpaces[i];
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    final stoneId = space['stoneId'] ?? 'ATHENA';
                    context.push('/live-ai?stoneId=$stoneId');
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: palette.border),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            space['image']!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(color: const Color(0xFF222222)),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.8),
                                ],
                              ),
                            ),
                          ),
                          // AR View Badge
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFD4AF37).withValues(alpha: 0.7),
                                  width: 0.7,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.view_in_ar_rounded, size: 10, color: Color(0xFFD4AF37)),
                                  const SizedBox(width: 3),
                                  Text(
                                    'AR LIVE',
                                    style: GoogleFonts.inter(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFD4AF37),
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 10,
                            left: 10,
                            right: 10,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  space['title']!,
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  space['panels']!,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: Colors.white70,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildArProductsCarousel(BuildContext context, dynamic palette, bool isDark) {
    final allStones = ref.watch(allStonesProvider).valueOrNull ?? MockDataService.getAllStones();
    return SizedBox(
      height: 255,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: allStones.length,
        itemBuilder: (context, i) {
          final stone = allStones[i];
          final imgUrl = stone.mainImageUrl ?? (stone.images.isNotEmpty ? stone.images.first : 'assets/images/placeholder_stone.png');
          return Container(
            width: 160,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.border, width: 0.8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image with AR badge
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        SmartStoneImage(
                          imageUrl: imgUrl,
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFFD4AF37),
                                width: 0.6,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.view_in_ar_rounded, size: 10, color: Color(0xFFD4AF37)),
                                const SizedBox(width: 3),
                                Text(
                                  '3D WALL',
                                  style: GoogleFonts.inter(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFD4AF37),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Details & CTA
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stone.name,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: palette.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          stone.collection,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: palette.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '₹${stone.pricePerSqFt.toStringAsFixed(0)}/sq.ft',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFD4AF37),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                context.push('/live-ai?stoneId=${stone.id}');
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD4AF37),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.layers_rounded, size: 11, color: Colors.black),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Place',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
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
    );
  }
}
