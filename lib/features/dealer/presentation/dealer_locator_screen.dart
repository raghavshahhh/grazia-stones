import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:grazia_stones/core/constants/app_colors.dart';
import 'package:grazia_stones/core/constants/app_dimensions.dart';
import 'package:grazia_stones/core/models/dealer.dart';
import 'package:grazia_stones/core/services/mock_data_service.dart';
import 'package:grazia_stones/core/theme/text_styles.dart';

class DealerLocatorScreen extends StatefulWidget {
  const DealerLocatorScreen({super.key});

  @override
  State<DealerLocatorScreen> createState() => _DealerLocatorScreenState();
}

class _DealerLocatorScreenState extends State<DealerLocatorScreen> {
  final _searchController = TextEditingController();
  late List<Dealer> _allDealers;
  List<Dealer> _filteredDealers = [];

  @override
  void initState() {
    super.initState();
    _allDealers = MockDataService.dealers;
    _filteredDealers = _allDealers;
    _searchController.addListener(_filterDealers);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterDealers);
    _searchController.dispose();
    super.dispose();
  }

  void _filterDealers() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredDealers = _allDealers;
      } else {
        _filteredDealers = _allDealers.where((d) {
          return d.name.toLowerCase().contains(query) ||
              d.address.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.charcoal,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Find Dealers',
          style: GraziaTextStyles.titleMedium.copyWith(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ── Map placeholder ──
          Container(
            height: 200,
            width: double.infinity,
            color: AppColors.graphite,
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.map_outlined,
                        size: 48,
                        color: AppColors.gold.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Interactive Map',
                        style: GraziaTextStyles.bodyMedium.copyWith(
                          color: AppColors.silver,
                        ),
                      ),
                    ],
                  ),
                ),
                // Search bar overlay
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.charcoal.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.slate),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: AppColors.silver, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: GraziaTextStyles.bodyMedium.copyWith(
                              color: Colors.white,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search by city or pincode...',
                              hintStyle: GraziaTextStyles.bodyMedium.copyWith(
                                color: AppColors.slate,
                              ),
                              border: InputBorder.none,
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

          // ── Dealer List ──
          Expanded(
            child: _filteredDealers.isEmpty
                ? Center(
                    child: Text(
                      'No dealers found',
                      style: GraziaTextStyles.bodyMedium.copyWith(
                        color: AppColors.silver,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(AppDimensions.spacingL),
                    itemCount: _filteredDealers.length,
                    itemBuilder: (context, index) {
                      final dealer = _filteredDealers[index];
                      return _DealerCard(dealer: dealer);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _DealerCard extends StatelessWidget {
  final Dealer dealer;

  const _DealerCard({required this.dealer});

  Future<void> _openDirections() async {
    final query = Uri.encodeComponent(dealer.address);
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$query',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _callDealer() async {
    final url = Uri.parse('tel:${dealer.phone}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingM),
      padding: const EdgeInsets.all(AppDimensions.spacingL),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        border: Border.all(color: AppColors.slate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  dealer.name,
                  style: GraziaTextStyles.titleMedium.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
              if (dealer.isAuthorized)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Authorized',
                    style: GraziaTextStyles.bodySmall.copyWith(
                      color: AppColors.gold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 16, color: AppColors.silver),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  dealer.address,
                  style: GraziaTextStyles.bodySmall.copyWith(
                    color: AppColors.silver,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          Row(
            children: [
              const Icon(Icons.phone_outlined, size: 16, color: AppColors.silver),
              const SizedBox(width: 4),
              Text(
                dealer.phone,
                style: GraziaTextStyles.bodySmall.copyWith(
                  color: AppColors.silver,
                ),
              ),
              const Spacer(),
              const Icon(Icons.star, size: 16, color: AppColors.goldWarm),
              const SizedBox(width: 4),
              Text(
                '${dealer.rating}',
                style: GraziaTextStyles.bodySmall.copyWith(
                  color: AppColors.goldWarm,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Text(
                dealer.distance,
                style: GraziaTextStyles.bodySmall.copyWith(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 36,
                child: OutlinedButton(
                  onPressed: _openDirections,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.gold,
                    side: const BorderSide(color: AppColors.gold),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Directions',
                    style: GraziaTextStyles.bodySmall.copyWith(
                      color: AppColors.gold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 36,
                child: OutlinedButton(
                  onPressed: _callDealer,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.gold,
                    side: const BorderSide(color: AppColors.gold),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Call',
                    style: GraziaTextStyles.bodySmall.copyWith(
                      color: AppColors.gold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
