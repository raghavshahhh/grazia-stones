import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/typography.dart';
import 'package:grazia_stones/shared/theme/spacing.dart';
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
    final palette = GLuxuryPalettes.gold;
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
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_ios_new, color: palette.textPrimary),
        ),
        title: Text(
          'My Orders',
          style: GLuxuryTypography.h2.copyWith(color: palette.textPrimary),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: palette.primary,
          unselectedLabelColor: palette.textTertiary,
          indicatorColor: palette.primary,
          labelStyle: GLuxuryTypography.labelMedium.copyWith(fontWeight: FontWeight.w600),
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
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredOrders.length,
                        itemBuilder: (context, i) =>
                            _buildOrderCard(filteredOrders[i], palette),
                      ),
                    ),
    );
  }

  Widget _buildEmptyState(LuxuryPalette palette) {
    String message = 'No orders yet';
    String subtitle = 'Your order history will appear here';
    
    if (_selectedFilter == 'pending') {
      message = 'No pending orders';
      subtitle = 'Your active orders will appear here';
    } else if (_selectedFilter == 'delivered') {
      message = 'No delivered orders';
      subtitle = 'Your completed orders will appear here';
    } else if (_selectedFilter == 'cancelled') {
      message = 'No cancelled orders';
      subtitle = 'Your cancelled orders will appear here';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 80,
            color: palette.textTertiary.withValues(alpha: 0.3),
          ),
          GLuxurySpacing.gapBase,
          Text(
            message,
            style: GLuxuryTypography.h2.copyWith(color: palette.textPrimary),
          ),
          GLuxurySpacing.gapSm,
          Text(
            subtitle,
            style: GLuxuryTypography.bodyMedium.copyWith(color: palette.textSecondary),
          ),
          GLuxurySpacing.gapLg,
          ElevatedButton(
            onPressed: () => context.go('/'),
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Start Shopping',
              style: GLuxuryTypography.labelMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Order order, LuxuryPalette palette) {
    final statusColor = _getStatusColor(order.status);

    return InkWell(
      onTap: () => _showOrderDetail(context, order, palette),
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Order #${order.id}',
                    style: GLuxuryTypography.h3.copyWith(color: palette.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    order.status,
                    style: GLuxuryTypography.labelSmall.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 16, color: palette.textTertiary),
                const SizedBox(width: 8),
                Text(
                  '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}',
                  style: GLuxuryTypography.bodySmall.copyWith(color: palette.textSecondary),
                ),
                const SizedBox(width: 20),
                Icon(Icons.inventory_2_outlined, size: 16, color: palette.textTertiary),
                const SizedBox(width: 8),
                Text(
                  '${order.stoneNames.length} items',
                  style: GLuxuryTypography.bodySmall.copyWith(color: palette.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total: ₹${order.totalAmount.toStringAsFixed(0)}',
                  style: GLuxuryTypography.h3.copyWith(color: palette.primary),
                ),
                Row(
                  children: [
                    if (order.status != 'Cancelled' && order.status != 'Delivered')
                      TextButton.icon(
                        onPressed: () => _showCancelDialog(context, order, palette),
                        icon: const Icon(Icons.cancel_outlined, size: 16),
                        label: Text('Cancel'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      )
                    else
                      TextButton.icon(
                        onPressed: () => _showOrderDetail(context, order, palette),
                        icon: const Icon(Icons.info_outlined, size: 16),
                        label: Text('Details'),
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
    );
  }

  Color _getStatusColor(String status) {
    final statusLower = status.toLowerCase();
    if (statusLower == 'delivered') return Colors.green;
    if (statusLower == 'in transit' || statusLower == 'processing') return Colors.orange;
    if (statusLower == 'cancelled') return Colors.red;
    if (statusLower == 'pending') return Colors.blue;
    return GLuxuryPalettes.gold.primary;
  }

  void _showCancelDialog(BuildContext context, Order order, LuxuryPalette palette) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: palette.surface,
        title: Text(
          'Cancel Order?',
          style: GLuxuryTypography.h3.copyWith(color: palette.textPrimary),
        ),
        content: Text(
          'Are you sure you want to cancel order #${order.id}? This action cannot be undone.',
          style: GLuxuryTypography.bodyMedium.copyWith(color: palette.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('No', style: TextStyle(color: palette.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(orderRiverpodProvider.notifier).cancelOrder(order.id);
                if (mounted) {
                  showSuccessSnackbar(context, 'Order cancelled successfully');
                }
              } catch (e) {
                if (mounted) {
                  showErrorSnackbar(context, e);
                }
              }
            },
            child: Text('Yes, Cancel', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showOrderDetail(BuildContext context, Order order, LuxuryPalette palette) {
    showModalBottomSheet(
      context: context,
      backgroundColor: palette.background,
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
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.textTertiary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order Details',
                    style: GLuxuryTypography.h2.copyWith(color: palette.textPrimary),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order.status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getStatusColor(order.status).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      order.status,
                      style: GLuxuryTypography.labelSmall.copyWith(
                        color: _getStatusColor(order.status),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildDetailRow('Order ID', '#${order.id}', palette),
              _buildDetailRow(
                'Order Date',
                '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}',
                palette,
              ),
              _buildDetailRow('Items', '${order.stoneNames.length}', palette),
              const SizedBox(height: 16),
              Divider(color: palette.border),
              const SizedBox(height: 16),
              Text(
                'Items',
                style: GLuxuryTypography.h3.copyWith(color: palette.textPrimary),
              ),
              const SizedBox(height: 12),
              ...order.stoneNames.map((name) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(Icons.circle, size: 6, color: palette.textTertiary),
                        const SizedBox(width: 8),
                        Text(
                          name,
                          style: GLuxuryTypography.bodyMedium.copyWith(
                            color: palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 16),
              Divider(color: palette.border),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Amount',
                    style: GLuxuryTypography.h3.copyWith(color: palette.textPrimary),
                  ),
                  Text(
                    '₹${order.totalAmount.toStringAsFixed(0)}',
                    style: GLuxuryTypography.h2.copyWith(color: palette.primary),
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
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel Order',
                      style: GLuxuryTypography.labelLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GLuxuryTypography.bodyMedium.copyWith(color: palette.textTertiary),
          ),
          Text(
            value,
            style: GLuxuryTypography.bodyMedium.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
