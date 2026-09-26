import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';

/// Screen 14: VR Room Selection (Select a Space)
/// Matches Client Reference Sheet Screen 14:
/// - "Select a Space"
/// - Vertical list of spaces with thumbnails:
///     • Living Room >
///     • Hotel Lobby >
///     • Restaurant >
///     • Bedroom >
///     • Office >
///     • Exterior >
class VrRoomSelectionScreen extends ConsumerWidget {
  const VrRoomSelectionScreen({super.key});

  static const List<Map<String, String>> _rooms = [
    {
      'title': 'Living Room',
      'subtitle': 'Grande Ledge & Athena 3D Cladding',
      'image': 'assets/images/home_hero_living_room.jpg',
      'tour': '360° AR Surface Mapping',
      'stoneId': 'athena-3d',
    },
    {
      'title': 'Hotel Lobby',
      'subtitle': 'Verona 3D & Bookmatched Italian Marble',
      'image': 'assets/images/hero_luxury_fireplace.jpg',
      'tour': 'Double Height Grand Foyer AR',
      'stoneId': 'verona-3d',
    },
    {
      'title': 'Restaurant',
      'subtitle': 'Rustic Mountain Ledge & Ambient Lighting',
      'image': 'assets/images/hero_luxury_dining_fluted.jpg',
      'tour': 'Hospitality Showcase AR',
      'stoneId': 'mountain-m08',
    },
    {
      'title': 'Bedroom',
      'subtitle': 'Opus Ledge 15 Textured Feature Wall',
      'image': 'assets/images/hero_luxury_bedroom.jpg',
      'tour': 'Luxury Master Suite AR',
      'stoneId': 'opus-15',
    },
    {
      'title': 'Office Boardroom',
      'subtitle': 'Vantage V12 Minimalist Linear Panels',
      'image': 'assets/images/onboarding_hero_room.jpg',
      'tour': 'Corporate Acoustic Cladding',
      'stoneId': 'vantage-v12',
    },
    {
      'title': 'Exterior Facade',
      'subtitle': 'Weatherproof High-Density Natural Panels',
      'image': 'assets/images/auth_luxury_background.jpg',
      'tour': 'Outdoor Weathering Test AR',
      'stoneId': 'grande-aty-10',
    },
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(themePaletteProvider);

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
          'Select a Space',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
      ),
      body: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        itemCount: _rooms.length,
        itemBuilder: (context, i) {
          final room = _rooms[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            height: 120,
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.border, width: 0.8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    final stoneId = room['stoneId'] ?? 'athena-3d';
                    context.push('/live-ai?stoneId=$stoneId');
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Room background image
                      Image.asset(
                        room['image']!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(color: const Color(0xFF222222)),
                      ),

                      // Gradient darken
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.black.withValues(alpha: 0.85),
                              Colors.black.withValues(alpha: 0.4),
                              Colors.black.withValues(alpha: 0.7),
                            ],
                            stops: const [0.0, 0.6, 1.0],
                          ),
                        ),
                      ),

                      // Content inside
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        room['title']!,
                                        style: GoogleFonts.playfairDisplay(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFD4AF37), size: 14),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    room['subtitle']!,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white70,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                                        width: 0.6,
                                      ),
                                    ),
                                    child: Text(
                                      room['tour']!,
                                      style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFFD4AF37),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.view_in_ar_rounded, color: Colors.white, size: 18),
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
        },
      ),
    );
  }
}
