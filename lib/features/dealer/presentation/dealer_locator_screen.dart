import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/providers/stone_providers.dart';
import 'package:grazia_stones/core/models/dealer.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/typography.dart';
import 'package:grazia_stones/shared/theme/spacing.dart';
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
    final palette = GLuxuryPalettes.gold;
    final dealersAsync = ref.watch(allDealersProvider);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_ios_new, color: palette.textPrimary),
        ),
        title: Text(
          'Find Dealers',
          style: GLuxuryTypography.h2.copyWith(color: palette.textPrimary),
        ),
        actions: [
          IconButton(
            onPressed: () {
              setState(() => _isMapView = !_isMapView);
              HapticFeedback.lightImpact();
            },
            icon: Icon(
              _isMapView ? Icons.list : Icons.map_outlined,
              color: palette.primary,
            ),
          ),
        ],
      ),
      body: dealersAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: palette.primary)),
        error: (e, _) => Center(
          child: Text('Failed to load dealers', style: TextStyle(color: palette.textSecondary)),
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
                Icon(Icons.map_outlined, size: 80, color: palette.textTertiary.withValues(alpha: 0.3)),
                GLuxurySpacing.gapBase,
                Text(
                  'Map View',
                  style: GLuxuryTypography.h2.copyWith(color: palette.textPrimary),
                ),
                GLuxurySpacing.gapSm,
                Text(
                  'Interactive map would appear here',
                  style: GLuxuryTypography.bodyMedium.copyWith(color: palette.textSecondary),
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
            height: 180,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: palette.background,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: dealers.length,
              itemBuilder: (context, i) {
                final dealer = dealers[i];
                return Container(
                  width: 280,
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
                              style: GLuxuryTypography.h3.copyWith(color: palette.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (dealer.isAuthorized)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: palette.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Authorized',
                                style: GLuxuryTypography.labelSmall.copyWith(
                                  color: palette.primary,
                                  fontSize: 10,
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
                            style: GLuxuryTypography.bodySmall.copyWith(color: palette.textPrimary),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.location_on_outlined, color: palette.textTertiary, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            dealer.distance,
                            style: GLuxuryTypography.bodySmall.copyWith(color: palette.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _makePhoneCall(dealer.phone),
                              icon: const Icon(Icons.phone, size: 16),
                              label: const Text('Call'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: palette.primary,
                                side: BorderSide(color: palette.border),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _openMaps(dealer.address),
                              icon: const Icon(Icons.directions, size: 16),
                              label: const Text('Navigate'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: palette.primary,
                                foregroundColor: palette.background,
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
      padding: const EdgeInsets.all(16),
      itemCount: dealers.length,
      itemBuilder: (context, i) {
        final dealer = dealers[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(16),
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
                      style: GLuxuryTypography.h3.copyWith(color: palette.textPrimary),
                    ),
                  ),
                  if (dealer.isAuthorized)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: palette.primaryGradient,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Authorized',
                        style: GLuxuryTypography.labelSmall.copyWith(
                          color: palette.background,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.star_rounded, color: palette.primary, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    dealer.rating.toString(),
                    style: GLuxuryTypography.bodyMedium.copyWith(color: palette.textPrimary),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.location_on_outlined, color: palette.textTertiary, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    dealer.distance,
                    style: GLuxuryTypography.bodyMedium.copyWith(color: palette.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.location_on_outlined, color: palette.textTertiary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dealer.address,
                      style: GLuxuryTypography.bodyMedium.copyWith(color: palette.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.phone_outlined, color: palette.textTertiary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    dealer.phone,
                    style: GLuxuryTypography.bodyMedium.copyWith(color: palette.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _makePhoneCall(dealer.phone),
                      icon: const Icon(Icons.phone_outlined, size: 18),
                      label: const Text('Call Now'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.primary,
                        side: BorderSide(color: palette.border),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openMaps(dealer.address),
                      icon: const Icon(Icons.directions_outlined, size: 18),
                      label: const Text('Directions'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.primary,
                        foregroundColor: palette.background,
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
