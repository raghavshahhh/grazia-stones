import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/models/order.dart';
import 'package:grazia_stones/core/widgets/error_handler_widget.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'all'; // all, pending, delivered, cancelled

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedFilter = ['all', 'pending', 'delivered', 'cancelled'][_tabController.index];
        });
      }
    });
    Future.microtask(() {
      ref.read(orderRiverpodProvider.notifier).loadOrders();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);
    final orderState = ref.watch(orderRiverpodProvider);

    // Filter orders based on selected tab
    final filteredOrders = _selectedFilter == 'all'
        ? orderState.orders
        : orderState.orders.where((order) {
            final status = order.status.toLowerCase();
            if (_selectedFilter == 'pending') {
              return status == 'pending' || status == 'processing' || status == 'in transit';
            } else if (_selectedFilter == 'delivered') {
              return status == 'delivered';
            } else if (_selectedFilter == 'cancelled') {
              return status == 'cancelled';
            }
            return true;
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
          'Project Orders',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: palette.primary,
          unselectedLabelColor: palette.textTertiary,
          indicatorColor: palette.primary,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Pending'),
            Tab(text: 'Delivered'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: orderState.error != null
          ? ErrorHandlerWidget(
              error: Exception(orderState.error),
              onRetry: () => ref.read(orderRiverpodProvider.notifier).loadOrders(),
            )
          : orderState.isLoading && orderState.orders.isEmpty
              ? Center(child: CircularProgressIndicator(color: palette.primary))
              : filteredOrders.isEmpty
                  ? _buildEmptyState(palette)
                  : RefreshIndicator(
                      color: palette.primary,
                      backgroundColor: palette.surface,
                      onRefresh: () async {
                        await ref.read(orderRiverpodProvider.notifier).loadOrders();
                      },
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        itemCount: filteredOrders.length,
                        itemBuilder: (context, i) =>
                            _buildOrderCard(filteredOrders[i], palette),
                      ),
                    ),
    );
  }

  Widget _buildEmptyState(LuxuryPalette palette) {
    String message = 'No Orders Found';
    String subtitle = 'Your procurement orders will appear here.';
    
    if (_selectedFilter == 'pending') {
      message = 'No Pending Orders';
      subtitle = 'Active dispatches and production orders appear here.';
    } else if (_selectedFilter == 'delivered') {
      message = 'No Delivered Orders';
      subtitle = 'Fulfilled site deliveries will appear here.';
    } else if (_selectedFilter == 'cancelled') {
      message = 'No Cancelled Orders';
      subtitle = 'Cancelled procurement orders appear here.';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: palette.surfaceDark,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 40,
              color: palette.textTertiary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 13, color: palette.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/'),
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: Text(
              'Explore Stone Gallery',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Order order, LuxuryPalette palette) {
    final statusColor = _getStatusColor(order.status, palette);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: InkWell(
        onTap: () => _showOrderDetail(context, order, palette),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Order #${order.id}',
                      style: GoogleFonts.inter(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      order.status.toUpperCase(),
                      style: GoogleFonts.inter(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 14, color: palette.textTertiary),
                  const SizedBox(width: 6),
                  Text(
                    '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}',
                    style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.texture_outlined, size: 14, color: palette.textTertiary),
                  const SizedBox(width: 6),
                  Text(
                    '${order.stoneNames.length} stone items',
                    style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '₹${order.totalAmount.toStringAsFixed(0)}',
                    style: GoogleFonts.playfairDisplay(
                      color: palette.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Row(
                    children: [
                      if (order.status != 'Cancelled' && order.status != 'Delivered')
                        TextButton.icon(
                          onPressed: () => _showCancelDialog(context, order, palette),
                          icon: const Icon(Icons.cancel_outlined, size: 14),
                          label: const Text('Cancel'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red.shade600,
                          ),
                        )
                      else
                        TextButton.icon(
                          onPressed: () => _showOrderDetail(context, order, palette),
                          icon: const Icon(Icons.receipt_long_outlined, size: 14),
                          label: const Text('View Invoice'),
                          style: TextButton.styleFrom(
                            foregroundColor: palette.primary,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status, LuxuryPalette palette) {
    final statusLower = status.toLowerCase();
    if (statusLower == 'delivered') return palette.success;
    if (statusLower == 'in transit' || statusLower == 'processing') return Colors.amber.shade800;
    if (statusLower == 'cancelled') return Colors.red.shade600;
    if (statusLower == 'pending') return palette.primary;
    return palette.primary;
  }

  void _showCancelDialog(BuildContext context, Order order, LuxuryPalette palette) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: palette.surface,
        title: Text(
          'Cancel Order?',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: palette.textPrimary),
        ),
        content: Text(
          'Are you sure you want to cancel order #${order.id}? This action cannot be undone.',
          style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Keep Order', style: TextStyle(color: palette.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await ref.read(orderRiverpodProvider.notifier).cancelOrder(order.id);
                if (mounted) {
                  showSuccessSnackbar(this.context, 'Order cancelled successfully');
                }
              } catch (e) {
                if (mounted) {
                  showErrorSnackbar(this.context, e);
                }
              }
            },
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showOrderDetail(BuildContext context, Order order, LuxuryPalette palette) {
    showModalBottomSheet(
      context: context,
      backgroundColor: palette.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order Invoice',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order.status, palette).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      order.status.toUpperCase(),
                      style: GoogleFonts.inter(
                        color: _getStatusColor(order.status, palette),
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildDetailRow('Order Identifier', '#${order.id}', palette),
              _buildDetailRow(
                'Order Date',
                '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}',
                palette,
              ),
              _buildDetailRow('Total Slabs / Items', '${order.stoneNames.length}', palette),
              const SizedBox(height: 12),
              Divider(color: palette.border),
              const SizedBox(height: 12),
              Text(
                'SPECIFIED STONE ITEMS',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.6, color: palette.textTertiary),
              ),
              const SizedBox(height: 10),
              ...order.stoneNames.map((name) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(Icons.diamond_outlined, size: 14, color: palette.primary),
                        const SizedBox(width: 10),
                        Text(
                          name,
                          style: GoogleFonts.inter(
                            color: palette.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 12),
              Divider(color: palette.border),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Payable',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: palette.textSecondary),
                  ),
                  Text(
                    '₹${order.totalAmount.toStringAsFixed(0)}',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: palette.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (order.status != 'Cancelled' && order.status != 'Delivered')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showCancelDialog(context, order, palette);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Cancel Procurement Order',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, LuxuryPalette palette) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 13),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              color: palette.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
