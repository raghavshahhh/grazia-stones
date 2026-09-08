import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/services/supabase_service.dart';
import 'package:grazia_stones/core/widgets/error_handler_widget.dart';
import 'package:grazia_stones/features/admin/presentation/widgets/admin_module_switcher.dart';
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
            tooltip: 'Refresh Metrics',
            onPressed: () {
              HapticFeedback.lightImpact();
              _loadMetrics();
            },
            icon: Icon(Icons.refresh_rounded, color: palette.primary),
          ),
          AdminQuickNavButton(
            currentRoute: '/admin/dashboard',
            palette: palette,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _error != null
          ? ErrorHandlerWidget(error: Exception(_error), onRetry: _loadMetrics)
          : _isLoading
              ? Center(child: CircularProgressIndicator(color: palette.primary))
              : RefreshIndicator(
              color: palette.primary,
              backgroundColor: palette.surface,
              onRefresh: _loadMetrics,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Banner
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          decoration: BoxDecoration(
                            gradient: palette.primaryGradient,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: palette.primary.withValues(alpha: 0.2),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.admin_panel_settings_outlined, color: Colors.white, size: 24),
                              ),
                              const SizedBox(width: 14),
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
                                    const SizedBox(height: 2),
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

                        const SizedBox(height: 22),

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

                        LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth;
                            final int crossAxisCount;
                            final double mainAxisExtent;
                            if (width >= 860) {
                              crossAxisCount = 4;
                              mainAxisExtent = 76;
                            } else if (width >= 560) {
                              crossAxisCount = 4;
                              mainAxisExtent = 76;
                            } else if (width >= 360) {
                              crossAxisCount = 2;
                              mainAxisExtent = 72;
                            } else {
                              crossAxisCount = 1;
                              mainAxisExtent = 68;
                            }

                            return GridView.count(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisExtent: mainAxisExtent,
                              children: [
                                _MetricCard(
                                  title: 'Total Revenue',
                                  value: '₹${_totalRevenue.toInt()}',
                                  icon: Icons.currency_rupee_rounded,
                                  palette: palette,
                                ),
                                _MetricCard(
                                  title: 'Total Orders',
                                  value: '$_totalOrders',
                                  icon: Icons.inventory_2_outlined,
                                  palette: palette,
                                ),
                                _MetricCard(
                                  title: 'Pending Orders',
                                  value: '$_pendingOrders',
                                  icon: Icons.pending_actions_rounded,
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
                                _MetricCard(
                                  title: 'Registered Clients',
                                  value: '$_totalUsers',
                                  icon: Icons.people_outline_rounded,
                                  palette: palette,
                                ),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 26),

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

                        LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth;
                            final isWide = width >= 680;
                            final modules = [
                              _NavModuleData(
                                title: 'Product Catalog Management',
                                subtitle: 'Add, edit, price, stock & image upload for stones',
                                icon: Icons.diamond_outlined,
                                route: '/admin/products',
                              ),
                              _NavModuleData(
                                title: 'Curated Collections',
                                subtitle: 'Organize stone categories, slugs and banners',
                                icon: Icons.category_outlined,
                                route: '/admin/collections',
                              ),
                              _NavModuleData(
                                title: 'Orders & Fulfillment',
                                subtitle: 'Inspect orders, update status, view items & addresses',
                                icon: Icons.local_shipping_outlined,
                                route: '/admin/orders',
                              ),
                              _NavModuleData(
                                title: 'Architectural Quotes',
                                subtitle: 'Review incoming quote requests, square footage & notes',
                                icon: Icons.request_quote_outlined,
                                route: '/admin/quotes',
                              ),
                              _NavModuleData(
                                title: 'Sample Dispatch Requests',
                                subtitle: 'Manage sample order boxes & studio deliveries',
                                icon: Icons.layers_outlined,
                                route: '/admin/samples',
                              ),
                              _NavModuleData(
                                title: 'Authorized Dealers & Showrooms',
                                subtitle: 'Manage dealer list, locations, phones and ratings',
                                icon: Icons.location_city_outlined,
                                route: '/admin/dealers',
                              ),
                              _NavModuleData(
                                title: 'AI Studio & Render Jobs',
                                subtitle: 'Monitor photorealistic rendering queue and analytics',
                                icon: Icons.auto_awesome_rounded,
                                route: '/admin/ai-jobs',
                              ),
                            ];

                            if (isWide) {
                              return GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: modules.length,
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  mainAxisExtent: 72,
                                ),
                                itemBuilder: (context, index) {
                                  final m = modules[index];
                                  return _AdminNavTile(
                                    title: m.title,
                                    subtitle: m.subtitle,
                                    icon: m.icon,
                                    palette: palette,
                                    onTap: () => context.push(m.route),
                                  );
                                },
                              );
                            }

                            return Column(
                              children: modules.map((m) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _AdminNavTile(
                                  title: m.title,
                                  subtitle: m.subtitle,
                                  icon: m.icon,
                                  palette: palette,
                                  onTap: () => context.push(m.route),
                                ),
                              )).toList(),
                            );
                          },
                        ),

                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _NavModuleData {
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;

  const _NavModuleData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
  });
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: palette.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: palette.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: GoogleFonts.inter(
                    color: palette.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: palette.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.border.withValues(alpha: 0.7)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: palette.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: palette.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        color: palette.textSecondary,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 12, color: palette.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
