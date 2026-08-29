import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/services/supabase_service.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  bool _isLoading = true;
  String? _error;

  int _totalProducts = 0;
  int _totalCollections = 0;
  int _totalDealers = 0;
  int _totalOrders = 0;
  int _pendingOrders = 0;
  int _totalQuotes = 0;
  int _totalUsers = 0;
  double _totalRevenue = 0;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final client = SupabaseService.instance.client;

      // Products count
      final productsRes = await client.from('stones').select('id');
      _totalProducts = (productsRes as List).length;

      // Collections count
      final collectionsRes = await client.from('collections').select('id');
      _totalCollections = (collectionsRes as List).length;

      // Dealers count
      final dealersRes = await client.from('dealers').select('id');
      _totalDealers = (dealersRes as List).length;

      // Orders
      final ordersRes = await client.from('orders').select('id, status, total');
      final ordersList = ordersRes as List;
      _totalOrders = ordersList.length;
      _pendingOrders = ordersList.where((o) => (o['status'] ?? '').toString().toLowerCase() == 'pending').length;
      _totalRevenue = ordersList.fold(0.0, (sum, o) => sum + ((o['total'] ?? 0) as num).toDouble());

      // Quotes count
      final quotesRes = await client.from('quote_requests').select('id');
      _totalQuotes = (quotesRes as List).length;

      // Profiles count
      final profilesRes = await client.from('profiles').select('id');
      _totalUsers = (profilesRes as List).length;

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);

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
          'Admin Console',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              _loadMetrics();
            },
            icon: Icon(Icons.refresh_rounded, color: palette.primary),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: palette.primary))
          : RefreshIndicator(
              color: palette.primary,
              backgroundColor: palette.surface,
              onRefresh: _loadMetrics,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Banner
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: palette.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: palette.primary.withValues(alpha: 0.25),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.admin_panel_settings_outlined, color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Grazia Operations',
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Real-time Supabase database control & inventory',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Metrics Grid
                    Text(
                      'DATABASE OVERVIEW',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                        color: palette.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.5,
                      children: [
                        _MetricCard(
                          title: 'Total Revenue',
                          value: '₹${_totalRevenue.toInt()}',
                          icon: Icons.currency_rupee_rounded,
                          palette: palette,
                        ),
                        _MetricCard(
                          title: 'Total Orders',
                          value: '$_totalOrders (${_pendingOrders} pending)',
                          icon: Icons.inventory_2_outlined,
                          palette: palette,
                        ),
                        _MetricCard(
                          title: 'Catalog Stones',
                          value: '$_totalProducts',
                          icon: Icons.diamond_outlined,
                          palette: palette,
                        ),
                        _MetricCard(
                          title: 'Collections',
                          value: '$_totalCollections',
                          icon: Icons.grid_view_rounded,
                          palette: palette,
                        ),
                        _MetricCard(
                          title: 'Quote Inquiries',
                          value: '$_totalQuotes',
                          icon: Icons.request_quote_outlined,
                          palette: palette,
                        ),
                        _MetricCard(
                          title: 'Showrooms / Dealers',
                          value: '$_totalDealers',
                          icon: Icons.storefront_outlined,
                          palette: palette,
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // Management Sections
                    Text(
                      'MANAGEMENT MODULES',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                        color: palette.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _AdminNavTile(
                      title: 'Product Catalog Management',
                      subtitle: 'Add, edit, price, stock & image upload for stones',
                      icon: Icons.diamond_outlined,
                      palette: palette,
                      onTap: () => context.push('/admin/products'),
                    ),
                    _AdminNavTile(
                      title: 'Curated Collections',
                      subtitle: 'Organize stone categories, slugs and banners',
                      icon: Icons.category_outlined,
                      palette: palette,
                      onTap: () => context.push('/admin/collections'),
                    ),
                    _AdminNavTile(
                      title: 'Orders & Fulfillment',
                      subtitle: 'Inspect orders, update status, view items & addresses',
                      icon: Icons.local_shipping_outlined,
                      palette: palette,
                      onTap: () => context.push('/admin/orders'),
                    ),
                    _AdminNavTile(
                      title: 'Architectural Quotes',
                      subtitle: 'Review incoming quote requests, square footage & notes',
                      icon: Icons.request_quote_outlined,
                      palette: palette,
                      onTap: () => context.push('/admin/quotes'),
                    ),
                    _AdminNavTile(
                      title: 'Sample Dispatch Requests',
                      subtitle: 'Manage sample order boxes & studio deliveries',
                      icon: Icons.layers_outlined,
                      palette: palette,
                      onTap: () => context.push('/admin/samples'),
                    ),
                    _AdminNavTile(
                      title: 'Authorized Dealers & Showrooms',
                      subtitle: 'Manage dealer list, locations, phones and ratings',
                      icon: Icons.location_city_outlined,
                      palette: palette,
                      onTap: () => context.push('/admin/dealers'),
                    ),

                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final LuxuryPalette palette;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: palette.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    color: palette.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              color: palette.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _AdminNavTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final LuxuryPalette palette;
  final VoidCallback onTap;

  const _AdminNavTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: palette.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: palette.primary, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          color: palette.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 14, color: palette.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
