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
import 'package:grazia_stones/shared/widgets/luxury_toast.dart';
import 'package:intl/intl.dart';

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

      // These 6 queries are independent — they were previously awaited one
      // at a time (6 sequential round trips), which is exactly the kind of
      // thing that makes an admin dashboard feel slow to open. Firing them
      // together cuts load time to roughly the slowest single query instead
      // of the sum of all six.
      final results = await Future.wait([
        client.from('stones').select('id'),
        client.from('collections').select('id'),
        client.from('dealers').select('id'),
        client.from('orders').select('id, status, total'),
        client.from('quote_requests').select('id'),
        client.from('profiles').select('id'),
      ]);

      _totalProducts = (results[0] as List).length;
      _totalCollections = (results[1] as List).length;
      _totalDealers = (results[2] as List).length;

      final ordersList = results[3] as List;
      _totalOrders = ordersList.length;
      _pendingOrders = ordersList.where((o) => (o['status'] ?? '').toString().toLowerCase() == 'pending').length;
      _totalRevenue = ordersList.fold(0.0, (sum, o) => sum + ((o['total'] ?? 0) as num).toDouble());

      _totalQuotes = (results[4] as List).length;
      _totalUsers = (results[5] as List).length;

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

  void _showRegisteredClientsSheet(BuildContext context, LuxuryPalette palette) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: palette.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => _RegisteredClientsModalSheet(
        palette: palette,
        onRoleChanged: () => _loadMetrics(),
      ),
    );
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
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
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
                                  onTap: () => context.push('/admin/orders'),
                                ),
                                _MetricCard(
                                  title: 'Total Orders',
                                  value: '$_totalOrders',
                                  icon: Icons.inventory_2_outlined,
                                  palette: palette,
                                  onTap: () => context.push('/admin/orders'),
                                ),
                                _MetricCard(
                                  title: 'Pending Orders',
                                  value: '$_pendingOrders',
                                  icon: Icons.pending_actions_rounded,
                                  palette: palette,
                                  onTap: () => context.push('/admin/orders?status=pending'),
                                ),
                                _MetricCard(
                                  title: 'Catalog Stones',
                                  value: '$_totalProducts',
                                  icon: Icons.diamond_outlined,
                                  palette: palette,
                                  onTap: () => context.push('/admin/products'),
                                ),
                                _MetricCard(
                                  title: 'Collections',
                                  value: '$_totalCollections',
                                  icon: Icons.grid_view_rounded,
                                  palette: palette,
                                  onTap: () => context.push('/admin/collections'),
                                ),
                                _MetricCard(
                                  title: 'Quote Inquiries',
                                  value: '$_totalQuotes',
                                  icon: Icons.request_quote_outlined,
                                  palette: palette,
                                  onTap: () => context.push('/admin/quotes'),
                                ),
                                _MetricCard(
                                  title: 'Showrooms / Dealers',
                                  value: '$_totalDealers',
                                  icon: Icons.storefront_outlined,
                                  palette: palette,
                                  onTap: () => context.push('/admin/dealers'),
                                ),
                                _MetricCard(
                                  title: 'Registered Clients',
                                  value: '$_totalUsers',
                                  icon: Icons.people_outline_rounded,
                                  palette: palette,
                                  onTap: () => _showRegisteredClientsSheet(context, palette),
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
  final VoidCallback? onTap;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.palette,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap != null
            ? () {
                HapticFeedback.lightImpact();
                onTap!();
              }
            : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
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
              if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: palette.textTertiary,
                ),
            ],
          ),
        ),
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

class _RegisteredClientsModalSheet extends StatefulWidget {
  final LuxuryPalette palette;
  final VoidCallback onRoleChanged;

  const _RegisteredClientsModalSheet({
    required this.palette,
    required this.onRoleChanged,
  });

  @override
  State<_RegisteredClientsModalSheet> createState() => _RegisteredClientsModalSheetState();
}

class _RegisteredClientsModalSheetState extends State<_RegisteredClientsModalSheet> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _profiles = [];
  String _selectedRole = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final client = SupabaseService.instance.client;
      final data = await client
          .from('profiles')
          .select()
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _profiles = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
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

  Future<void> _changeUserRole(String userId, String currentRole, String userName) async {
    final availableRoles = ['user', 'architect', 'dealer', 'admin'];
    String chosenRole = currentRole;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            backgroundColor: widget.palette.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: widget.palette.border),
            ),
            title: Text(
              'Change Client Role',
              style: GoogleFonts.playfairDisplay(
                fontWeight: FontWeight.w700,
                color: widget.palette.textPrimary,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'User: $userName',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: widget.palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Select new access privilege:',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: widget.palette.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableRoles.map((r) {
                    final isSel = chosenRole == r;
                    return ChoiceChip(
                      label: Text(r.toUpperCase()),
                      selected: isSel,
                      selectedColor: widget.palette.primary,
                      backgroundColor: widget.palette.surface,
                      labelStyle: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isSel ? Colors.white : widget.palette.textPrimary,
                      ),
                      onSelected: (val) {
                        if (val) {
                          setDlgState(() => chosenRole = r);
                        }
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(color: widget.palette.textSecondary),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.palette.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(
                  'Update Role',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed == true && chosenRole != currentRole) {
      try {
        final client = SupabaseService.instance.client;
        await client
            .from('profiles')
            .update({'role': chosenRole, 'updated_at': DateTime.now().toIso8601String()})
            .eq('id', userId);

        if (mounted) {
          LuxuryToast.show(context, message: 'Role updated to ${chosenRole.toUpperCase()}');
          _loadProfiles();
          widget.onRoleChanged();
        }
      } catch (e) {
        if (mounted) {
          LuxuryToast.show(context, message: 'Failed: $e');
        }
      }
    }
  }

  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.purpleAccent;
      case 'architect':
        return Colors.blueAccent;
      case 'dealer':
        return Colors.amber.shade700;
      default:
        return widget.palette.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _profiles.where((p) {
      final role = (p['role'] ?? 'user').toString().toLowerCase();
      if (_selectedRole != 'all' && role != _selectedRole.toLowerCase()) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = (p['full_name'] ?? '').toString().toLowerCase();
        final email = (p['email'] ?? '').toString().toLowerCase();
        final phone = (p['phone'] ?? '').toString().toLowerCase();
        if (!name.contains(q) && !email.contains(q) && !phone.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: widget.palette.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Registered Clients',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: widget.palette.textPrimary,
                        ),
                      ),
                      Text(
                        '${_profiles.length} total users in Supabase profiles',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: widget.palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _loadProfiles,
                  tooltip: 'Refresh list',
                  icon: Icon(Icons.refresh_rounded, color: widget.palette.primary, size: 20),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: widget.palette.textPrimary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Search Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: GoogleFonts.inter(color: widget.palette.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search by client name, email or phone...',
                hintStyle: GoogleFonts.inter(color: widget.palette.textTertiary, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, size: 18, color: widget.palette.textTertiary),
                filled: true,
                fillColor: widget.palette.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: widget.palette.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: widget.palette.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: widget.palette.primary),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Role Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: ['all', 'admin', 'architect', 'dealer', 'user'].map((role) {
                final isSelected = _selectedRole == role;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedRole = role);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? widget.palette.primary : widget.palette.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? widget.palette.primary : widget.palette.border,
                        ),
                      ),
                      child: Text(
                        role.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.white : widget.palette.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: widget.palette.border),

          // Users List
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(widget.palette.primary),
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Text(
                          _error!,
                          style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 13),
                        ),
                      )
                    : filtered.isEmpty
                        ? Center(
                            child: Text(
                              'No clients match the current filter',
                              style: GoogleFonts.inter(
                                color: widget.palette.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final u = filtered[index];
                              final id = (u['id'] ?? '').toString();
                              final name = (u['full_name'] ?? 'Anonymous Client').toString();
                              final email = (u['email'] ?? 'No email').toString();
                              final phone = (u['phone'] ?? '').toString();
                              final role = (u['role'] ?? 'user').toString();
                              final createdAt = u['created_at'] != null
                                  ? DateFormat('dd MMM yyyy').format(DateTime.tryParse(u['created_at'].toString()) ?? DateTime.now())
                                  : 'Recently';

                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: widget.palette.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: widget.palette.border),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: widget.palette.primary.withValues(alpha: 0.12),
                                      child: Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w700,
                                          color: widget.palette.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  name,
                                                  style: GoogleFonts.inter(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 13,
                                                    color: widget.palette.textPrimary,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: _roleColor(role).withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: _roleColor(role).withValues(alpha: 0.4),
                                                  ),
                                                ),
                                                child: Text(
                                                  role.toUpperCase(),
                                                  style: GoogleFonts.inter(
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: _roleColor(role),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            email,
                                            style: GoogleFonts.inter(
                                              fontSize: 11.5,
                                              color: widget.palette.textSecondary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (phone.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              phone,
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                color: widget.palette.textTertiary,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 4),
                                          Text(
                                            'Joined: $createdAt',
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              color: widget.palette.textTertiary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Change Role',
                                      onPressed: () => _changeUserRole(id, role, name),
                                      icon: Icon(Icons.manage_accounts_outlined, color: widget.palette.primary, size: 20),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
