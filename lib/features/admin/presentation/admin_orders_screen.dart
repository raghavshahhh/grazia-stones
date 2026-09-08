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

class AdminOrdersScreen extends ConsumerStatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  ConsumerState<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends ConsumerState<AdminOrdersScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _orders = [];
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final client = SupabaseService.instance.client;
      final data = await client
          .from('orders')
          .select('*, order_items(*)')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _orders = List<Map<String, dynamic>>.from(data);
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

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      final client = SupabaseService.instance.client;
      await client.from('orders').update({
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', orderId);

      if (mounted) {
        LuxuryToast.show(context, message: 'Order status updated to ${newStatus.toUpperCase()}');
        _loadOrders();
      }
    } catch (e) {
      if (mounted) LuxuryToast.show(context, message: e.toString(), isError: true);
    }
  }

  Widget _buildFilterChip(String label, String value, LuxuryPalette palette) {
    final isSelected = _statusFilter == value;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _statusFilter = value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? palette.primary : palette.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? palette.primary : palette.border,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : palette.textSecondary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);

    final filteredOrders = _orders.where((o) {
      if (_statusFilter == 'all') return true;
      return (o['status'] ?? '').toString().toLowerCase() == _statusFilter.toLowerCase();
    }).toList();

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
          'Customer Orders (${_orders.length})',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Orders',
            onPressed: () {
              HapticFeedback.lightImpact();
              _loadOrders();
            },
            icon: Icon(Icons.refresh_rounded, color: palette.primary),
          ),
          AdminQuickNavButton(
            currentRoute: '/admin/orders',
            palette: palette,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _error != null
          ? ErrorHandlerWidget(error: Exception(_error), onRetry: _loadOrders)
          : _isLoading
              ? Center(child: CircularProgressIndicator(color: palette.primary))
              : Column(
                  children: [
                    // Horizontal status filter chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      child: Row(
                        children: [
                          _buildFilterChip('All (${_orders.length})', 'all', palette),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'Pending (${_orders.where((o) => (o['status'] ?? '').toString().toLowerCase() == 'pending').length})',
                            'pending',
                            palette,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'Confirmed (${_orders.where((o) => (o['status'] ?? '').toString().toLowerCase() == 'confirmed').length})',
                            'confirmed',
                            palette,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'Processing (${_orders.where((o) => (o['status'] ?? '').toString().toLowerCase() == 'processing').length})',
                            'processing',
                            palette,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'Shipped (${_orders.where((o) => (o['status'] ?? '').toString().toLowerCase() == 'shipped').length})',
                            'shipped',
                            palette,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'Delivered (${_orders.where((o) => (o['status'] ?? '').toString().toLowerCase() == 'delivered').length})',
                            'delivered',
                            palette,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'Cancelled (${_orders.where((o) => (o['status'] ?? '').toString().toLowerCase() == 'cancelled').length})',
                            'cancelled',
                            palette,
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: filteredOrders.isEmpty
                          ? Center(
                              child: Text(
                                _statusFilter == 'all'
                                    ? 'No orders found in database'
                                    : 'No orders with status "$_statusFilter"',
                                style: GoogleFonts.inter(color: palette.textSecondary),
                              ),
                            )
                          : RefreshIndicator(
                              color: palette.primary,
                              backgroundColor: palette.surface,
                              onRefresh: _loadOrders,
                              child: ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                itemCount: filteredOrders.length,
                                itemBuilder: (context, i) {
                                  final o = filteredOrders[i];
                                  return _buildOrderCard(palette, o);
                                },
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildOrderCard(LuxuryPalette palette, Map<String, dynamic> o) {
    final id = o['id']?.toString() ?? '';
    final orderNumber = o['order_number']?.toString() ?? id.substring(0, 8).toUpperCase();
    final status = o['status']?.toString() ?? 'pending';
    final total = (o['total'] ?? 0) as num;
    final items = (o['order_items'] as List?) ?? [];
    final address = o['shipping_address'] as Map<String, dynamic>?;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          title: Row(
            children: [
              Text(
                '#$orderNumber',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: palette.textPrimary, fontSize: 14),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: GoogleFonts.inter(
                    color: _statusColor(status),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '₹${total.toInt()} • ${items.length} items',
              style: GoogleFonts.inter(color: palette.primary, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          children: [
            const Divider(),
            if (address != null) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Shipping Address: ${address['name'] ?? ''} | ${address['address_line1'] ?? ''}, ${address['city'] ?? ''}, ${address['pincode'] ?? ''} (Ph: ${address['phone'] ?? ''})',
                  style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 12),
                ),
              ),
              const SizedBox(height: 10),
            ],
            // Items
            ...items.map((it) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '• ${it['stone_name'] ?? 'Stone'} (Qty: ${it['quantity']})',
                          style: GoogleFonts.inter(color: palette.textPrimary, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '₹${((it['price_per_unit'] ?? 0) * (it['quantity'] ?? 1)).toInt()}',
                        style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 14),

            // Status Update Dropdown
            Row(
              children: [
                Text('Update Status: ', style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 12)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: palette.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: palette.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: ['pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled'].contains(status)
                          ? status
                          : 'pending',
                      dropdownColor: palette.surface,
                      items: ['pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled']
                          .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(s.toUpperCase(), style: TextStyle(color: palette.textPrimary, fontSize: 11)),
                              ))
                          .toList(),
                      onChanged: (newVal) {
                        if (newVal != null && newVal != status) {
                          _updateOrderStatus(id, newVal);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return Colors.green;
      case 'shipped':
      case 'processing':
        return Colors.blue;
      case 'confirmed':
        return Colors.amber.shade700;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }
}
