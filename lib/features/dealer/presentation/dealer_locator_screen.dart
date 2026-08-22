import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/providers/stone_providers.dart';
import 'package:grazia_stones/core/models/dealer.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class DealerLocatorScreen extends ConsumerStatefulWidget {
  const DealerLocatorScreen({super.key});

  @override
  ConsumerState<DealerLocatorScreen> createState() => _DealerLocatorScreenState();
}

class _DealerLocatorScreenState extends ConsumerState<DealerLocatorScreen> {
  bool _isMapView = false;

  void _makePhoneCall(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _openMaps(String address) async {
    final query = Uri.encodeComponent(address);
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);
    final dealersAsync = ref.watch(allDealersProvider);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: palette.textPrimary, size: 18),
        ),
        title: Text(
          'Showrooms & Dealers',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              setState(() => _isMapView = !_isMapView);
              HapticFeedback.lightImpact();
            },
            icon: Icon(
              _isMapView ? Icons.view_list_rounded : Icons.map_outlined,
              color: palette.primary,
            ),
          ),
        ],
      ),
      body: dealersAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: palette.primary)),
        error: (e, _) => Center(
          child: Text('Failed to load showrooms', style: GoogleFonts.inter(color: palette.textSecondary)),
        ),
        data: (dealers) => _isMapView ? _buildMapView(palette, dealers) : _buildListView(palette, dealers),
      ),
    );
  }

  Widget _buildMapView(LuxuryPalette palette, List<Dealer> dealers) {
    return Stack(
      children: [
        Container(
          color: palette.surfaceDark,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map_outlined, size: 64, color: palette.textTertiary.withValues(alpha: 0.3)),
                const SizedBox(height: 16),
                Text(
                  'Map Coordinates',
                  style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.w700, color: palette.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  'Interactive architectural showroom map',
                  style: GoogleFonts.inter(fontSize: 13, color: palette.textSecondary),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 190,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: palette.background,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: dealers.length,
              itemBuilder: (context, i) {
                final dealer = dealers[i];
                return Container(
                  width: 290,
                  margin: EdgeInsets.only(right: i < dealers.length - 1 ? 12 : 0),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: palette.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              dealer.name,
                              style: GoogleFonts.playfairDisplay(
                                color: palette.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (dealer.isAuthorized)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: palette.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'AUTHORIZED',
                                style: GoogleFonts.inter(
                                  color: palette.primary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.star_rounded, color: palette.primary, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            dealer.rating.toString(),
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: palette.textPrimary),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.location_on_outlined, color: palette.textTertiary, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            dealer.distance,
                            style: GoogleFonts.inter(fontSize: 12, color: palette.textSecondary),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _makePhoneCall(dealer.phone),
                              icon: const Icon(Icons.phone_outlined, size: 14),
                              label: const Text('Call'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: palette.primary,
                                side: BorderSide(color: palette.border),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _openMaps(dealer.address),
                              icon: const Icon(Icons.directions_outlined, size: 14),
                              label: const Text('Directions'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: palette.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListView(LuxuryPalette palette, List<Dealer> dealers) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      itemCount: dealers.length,
      itemBuilder: (context, i) {
        final dealer = dealers[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      dealer.name,
                      style: GoogleFonts.playfairDisplay(
                        color: palette.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (dealer.isAuthorized)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: palette.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'AUTHORIZED',
                        style: GoogleFonts.inter(
                          color: palette.primary,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.star_rounded, color: palette.primary, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    dealer.rating.toString(),
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: palette.textPrimary),
                  ),
                  const SizedBox(width: 14),
                  Icon(Icons.near_me_outlined, color: palette.textTertiary, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    dealer.distance,
                    style: GoogleFonts.inter(fontSize: 12, color: palette.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(Icons.location_on_outlined, color: palette.textTertiary, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dealer.address,
                      style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 13, height: 1.35),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.phone_outlined, color: palette.textTertiary, size: 15),
                  const SizedBox(width: 8),
                  Text(
                    dealer.phone,
                    style: GoogleFonts.inter(color: palette.textTertiary, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _makePhoneCall(dealer.phone),
                      icon: const Icon(Icons.phone_outlined, size: 16),
                      label: const Text('Contact Desk'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.primary,
                        side: BorderSide(color: palette.border),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openMaps(dealer.address),
                      icon: const Icon(Icons.directions_outlined, size: 16),
                      label: const Text('Get Directions'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
