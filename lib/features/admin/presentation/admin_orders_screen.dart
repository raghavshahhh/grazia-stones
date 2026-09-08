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
import 'package:url_launcher/url_launcher.dart';

class AdminOrdersScreen extends ConsumerStatefulWidget {
  final String? initialStatus;
  const AdminOrdersScreen({super.key, this.initialStatus});

  @override
  ConsumerState<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends ConsumerState<AdminOrdersScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _orders = [];
  String _statusFilter = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _statusFilter = widget.initialStatus ?? 'all';
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

  void _showCarrierTrackingDialog(Map<String, dynamic> order, LuxuryPalette palette) {
    final orderId = order['id']?.toString() ?? '';
    final orderNum = order['order_number']?.toString() ?? orderId.substring(0, 8).toUpperCase();
    final carrierCtrl = TextEditingController(text: order['carrier']?.toString() ?? 'BlueDart');
    final trackingCtrl = TextEditingController(text: order['tracking_number']?.toString() ?? '');
    final notesCtrl = TextEditingController(text: order['notes']?.toString() ?? '');
    bool markShipped = (order['status'] ?? '').toString().toLowerCase() != 'shipped' &&
        (order['status'] ?? '').toString().toLowerCase() != 'delivered';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: palette.border),
          ),
          title: Text(
            'Fulfillment & Tracking: #$orderNum',
            style: GoogleFonts.playfairDisplay(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: palette.textPrimary,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Logistics Carrier:',
                  style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: carrierCtrl,
                  style: TextStyle(color: palette.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'e.g. BlueDart Express, Delhivery, VRL',
                    hintStyle: TextStyle(color: palette.textTertiary, fontSize: 12),
                    filled: true,
                    fillColor: palette.background,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: palette.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: palette.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: palette.primary, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Tracking Number / AWB:',
                  style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: trackingCtrl,
                  style: TextStyle(color: palette.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'e.g. 748392019482',
                    hintStyle: TextStyle(color: palette.textTertiary, fontSize: 12),
                    filled: true,
                    fillColor: palette.background,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: palette.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: palette.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: palette.primary, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Order Notes:',
                  style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  style: TextStyle(color: palette.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'e.g. Dispatched in wooden crate with waterproofing',
                    hintStyle: TextStyle(color: palette.textTertiary, fontSize: 12),
                    filled: true,
                    fillColor: palette.background,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: palette.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: palette.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: palette.primary, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: markShipped,
                  activeColor: palette.primary,
                  onChanged: (val) => setDlgState(() => markShipped = val ?? false),
                  title: Text(
                    'Mark order status as "SHIPPED"',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: palette.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: palette.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  final client = SupabaseService.instance.client;
                  final updateData = <String, dynamic>{
                    'carrier': carrierCtrl.text.trim(),
                    'tracking_number': trackingCtrl.text.trim(),
                    'notes': notesCtrl.text.trim(),
                    'updated_at': DateTime.now().toIso8601String(),
                  };
                  if (markShipped) {
                    updateData['status'] = 'shipped';
                  }
                  await client.from('orders').update(updateData).eq('id', orderId);

                  if (mounted) {
                    LuxuryToast.show(context, message: 'Logistics details updated');
                    _loadOrders();
                  }
                } catch (e) {
                  if (mounted) LuxuryToast.show(context, message: e.toString(), isError: true);
                }
              },
              child: const Text('Save Details'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchWhatsApp(String phone, String name, String orderNumber, String? carrier, String? trackingNumber) async {
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.length == 10) {
      cleanPhone = '91$cleanPhone';
    }
    final trackingMsg = (trackingNumber != null && trackingNumber.isNotEmpty)
        ? ' Your consignment with ${carrier ?? "courier"} is tracking at $trackingNumber.'
        : '';
    final message = 'Hello $name, this is Grazia Stones regarding your order #$orderNumber.$trackingMsg Please let us know if you need any assistance.';
    final url = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) LuxuryToast.show(context, message: 'Could not open WhatsApp for $phone', isError: true);
      }
    } catch (_) {
      if (mounted) LuxuryToast.show(context, message: 'Could not open WhatsApp', isError: true);
    }
  }

  Future<void> _launchCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final url = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        if (mounted) LuxuryToast.show(context, message: 'Could not place call to $phone', isError: true);
      }
    } catch (_) {
      if (mounted) LuxuryToast.show(context, message: 'Could not place call', isError: true);
    }
  }

  Future<void> _deleteOrder(String orderId) async {
    final palette = ref.read(themePaletteProvider);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: palette.border),
        ),
        title: Text(
          'Delete Order Record?',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: palette.textPrimary,
          ),
        ),
        content: Text(
          'This will permanently delete this order record and all associated items from the database. Are you sure?',
          style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: palette.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Order'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final client = SupabaseService.instance.client;
      await client.from('order_items').delete().eq('order_id', orderId);
      await client.from('orders').delete().eq('id', orderId);

      if (mounted) {
        LuxuryToast.show(context, message: 'Order deleted successfully');
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
    final query = _searchQuery.trim().toLowerCase();

    final filteredOrders = _orders.where((o) {
      if (_statusFilter != 'all') {
        if ((o['status'] ?? '').toString().toLowerCase() != _statusFilter.toLowerCase()) {
          return false;
        }
      }
      if (query.isEmpty) return true;

      final id = (o['id'] ?? '').toString().toLowerCase();
      final orderNum = (o['order_number'] ?? '').toString().toLowerCase();
      final name = (o['shipping_name'] ?? (o['shipping_address'] is Map ? o['shipping_address']['name'] : '') ?? '').toString().toLowerCase();
      final phone = (o['shipping_phone'] ?? (o['shipping_address'] is Map ? o['shipping_address']['phone'] : '') ?? '').toString().toLowerCase();
      final city = (o['shipping_city'] ?? (o['shipping_address'] is Map ? o['shipping_address']['city'] : '') ?? '').toString().toLowerCase();
      final tracking = (o['tracking_number'] ?? '').toString().toLowerCase();
      final carrier = (o['carrier'] ?? '').toString().toLowerCase();
      final notes = (o['notes'] ?? '').toString().toLowerCase();

      return id.contains(query) ||
          orderNum.contains(query) ||
          name.contains(query) ||
          phone.contains(query) ||
          city.contains(query) ||
          tracking.contains(query) ||
          carrier.contains(query) ||
          notes.contains(query);
    }).toList();

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
              context.go('/admin/dashboard');
            }
          },
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
              : Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: Column(
                      children: [
                        // Search Bar
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
                          child: TextField(
                            onChanged: (val) => setState(() => _searchQuery = val),
                            style: GoogleFonts.inter(color: palette.textPrimary, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Search by order #, customer, phone, city, AWB...',
                              hintStyle: GoogleFonts.inter(color: palette.textTertiary, fontSize: 13),
                              prefixIcon: Icon(Icons.search_rounded, color: palette.textSecondary, size: 20),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(Icons.clear_rounded, color: palette.textSecondary, size: 18),
                                      onPressed: () => setState(() => _searchQuery = ''),
                                    )
                                  : null,
                              filled: true,
                              fillColor: palette.surface,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: palette.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: palette.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: palette.primary, width: 1.5),
                              ),
                            ),
                          ),
                        ),

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
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.inventory_2_outlined, color: palette.textTertiary, size: 48),
                                      const SizedBox(height: 12),
                                      Text(
                                        _searchQuery.isNotEmpty
                                            ? 'No orders matching "$_searchQuery"'
                                            : _statusFilter == 'all'
                                                ? 'No orders found in database'
                                                : 'No orders with status "$_statusFilter"',
                                        style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 13),
                                      ),
                                    ],
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
                  ),
                ),
    );
  }

  Widget _buildOrderCard(LuxuryPalette palette, Map<String, dynamic> o) {
    final id = o['id']?.toString() ?? '';
    final orderNumber = o['order_number']?.toString() ?? (id.length >= 8 ? id.substring(0, 8).toUpperCase() : id);
    final status = o['status']?.toString() ?? 'pending';
    final total = (o['total'] ?? 0) as num;
    final items = (o['order_items'] as List?) ?? [];

    // Robust address extraction supporting flat columns and JSON map
    final addressMap = o['shipping_address'] is Map<String, dynamic> ? (o['shipping_address'] as Map<String, dynamic>) : null;
    final shippingName = (o['shipping_name'] ?? addressMap?['name'] ?? 'Client').toString();
    final shippingPhone = (o['shipping_phone'] ?? addressMap?['phone'] ?? '').toString();
    final shippingAddress = (o['shipping_address'] is String
            ? o['shipping_address']
            : (addressMap?['address_line1'] ?? addressMap?['address'] ?? ''))
        .toString();
    final shippingCity = (o['shipping_city'] ?? addressMap?['city'] ?? '').toString();
    final shippingState = (o['shipping_state'] ?? addressMap?['state'] ?? '').toString();
    final shippingPincode = (o['shipping_pincode'] ?? addressMap?['pincode'] ?? '').toString();

    final carrier = o['carrier']?.toString();
    final trackingNumber = o['tracking_number']?.toString();
    final paymentMethod = (o['payment_method'] ?? 'COD').toString().toUpperCase();
    final paymentStatus = (o['payment_status'] ?? 'pending').toString().toUpperCase();
    final orderNotes = o['notes']?.toString();

    // Date formatting
    String formattedDate = '';
    if (o['created_at'] != null) {
      try {
        final dt = DateTime.parse(o['created_at'].toString()).toLocal();
        formattedDate = '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

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
              const SizedBox(width: 8),
              if (shippingCity.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: palette.background,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: palette.border),
                  ),
                  child: Text(
                    shippingCity,
                    style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 10, fontWeight: FontWeight.w500),
                  ),
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
            child: Row(
              children: [
                Text(
                  '₹${total.toInt()} • ${items.length} items',
                  style: GoogleFonts.inter(color: palette.primary, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                if (shippingName.isNotEmpty && shippingName != 'Client') ...[
                  Text(' • ', style: TextStyle(color: palette.textTertiary)),
                  Expanded(
                    child: Text(
                      shippingName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
          children: [
            const Divider(),

            // Payment & Shipping badge row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: palette.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: palette.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.payment_rounded, size: 12, color: palette.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '$paymentMethod ($paymentStatus)',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: palette.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (formattedDate.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    formattedDate,
                    style: GoogleFonts.inter(color: palette.textTertiary, fontSize: 11),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),

            // Carrier / Tracking Chip with Copy & WhatsApp button
            if (trackingNumber != null && trackingNumber.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_shipping_outlined, color: Colors.blue, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${carrier ?? "Courier"}: $trackingNumber',
                        style: GoogleFonts.inter(
                          color: palette.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.blue),
                      tooltip: 'Copy Tracking AWB',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: trackingNumber));
                        LuxuryToast.show(context, message: 'AWB copied to clipboard');
                      },
                    ),
                  ],
                ),
              ),
            ],

            // Customer Contact & Delivery Address Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person_pin_circle_outlined, size: 16, color: palette.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$shippingName ${shippingPhone.isNotEmpty ? "($shippingPhone)" : ""}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: palette.textPrimary,
                          ),
                        ),
                      ),
                      if (shippingPhone.isNotEmpty) ...[
                        IconButton(
                          icon: const Icon(Icons.phone_rounded, size: 16, color: Colors.blue),
                          tooltip: 'Call Customer',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _launchCall(shippingPhone),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Colors.green),
                          tooltip: 'WhatsApp Customer',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _launchWhatsApp(shippingPhone, shippingName, orderNumber, carrier, trackingNumber),
                        ),
                      ],
                    ],
                  ),
                  if (shippingAddress.isNotEmpty || shippingCity.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (shippingAddress.isNotEmpty) shippingAddress,
                        if (shippingCity.isNotEmpty) shippingCity,
                        if (shippingState.isNotEmpty) shippingState,
                        if (shippingPincode.isNotEmpty) shippingPincode,
                      ].join(', '),
                      style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Items list
            ...items.map((it) {
              final itemName = it['name'] ?? it['stone_name'] ?? 'Natural Stone';
              final itemQty = it['quantity'] ?? 1;
              final itemUnit = (it['unit_price'] ?? it['price_per_unit'] ?? 0) as num;
              final itemTotal = (it['total_price'] ?? (itemUnit * itemQty)) as num;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '• $itemName (Qty: $itemQty)',
                        style: GoogleFonts.inter(color: palette.textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '₹${itemTotal.toInt()}',
                      style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            }),

            if (orderNotes != null && orderNotes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
                ),
                child: Text(
                  'Note: $orderNotes',
                  style: GoogleFonts.inter(color: palette.textPrimary, fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ),
            ],

            const SizedBox(height: 14),

            // Action Toolbar: Status dropdown, Tracking dialog button, Delete button
            Row(
              children: [
                Text('Status:', style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 12)),
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
                      value: ['pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled'].contains(status.toLowerCase())
                          ? status.toLowerCase()
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
                const Spacer(),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    side: BorderSide(color: palette.border),
                  ),
                  onPressed: () => _showCarrierTrackingDialog(o, palette),
                  icon: Icon(Icons.local_shipping_outlined, size: 14, color: palette.primary),
                  label: Text('Logistics', style: GoogleFonts.inter(fontSize: 11, color: palette.textPrimary)),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Delete Order Record',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400, size: 20),
                  onPressed: () => _deleteOrder(id),
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

