import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/typography.dart';
import 'package:grazia_stones/shared/theme/spacing.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/models/order.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(orderRiverpodProvider.notifier).loadOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = GLuxuryPalettes.gold;
    final orderState = ref.watch(orderRiverpodProvider);

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
      ),
      body: orderState.isLoading
          ? Center(child: CircularProgressIndicator(color: palette.primary))
          : orderState.orders.isEmpty
              ? _buildEmptyState(palette)
              : RefreshIndicator(
                  color: palette.primary,
                  backgroundColor: palette.surface,
                  onRefresh: () async {
                    await ref.read(orderRiverpodProvider.notifier).loadOrders();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: orderState.orders.length,
                    itemBuilder: (context, i) =>
                        _buildOrderCard(orderState.orders[i], palette),
                  ),
                ),
    );
  }

  Widget _buildEmptyState(LuxuryPalette palette) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 80, color: palette.textTertiary.withValues(alpha: 0.3)),
          GLuxurySpacing.gapBase,
          Text('No orders yet', style: GLuxuryTypography.h2.copyWith(color: palette.textPrimary)),
          GLuxurySpacing.gapSm,
          Text('Your order history will appear here', style: GLuxuryTypography.bodyMedium.copyWith(color: palette.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Order order, LuxuryPalette palette) {
    final statusColor = order.status == 'Delivered'
        ? Colors.green
        : order.status == 'In Transit'
            ? Colors.orange
            : order.status == 'Cancelled'
                ? Colors.red
                : palette.primary;

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order #${order.id}',
                style: GLuxuryTypography.h3.copyWith(color: palette.textPrimary),
              ),
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
              if (order.status != 'Cancelled' && order.status != 'Delivered')
                TextButton(
                  onPressed: () {
                    ref.read(orderRiverpodProvider.notifier).cancelOrder(order.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Order ${order.id} cancelled'),
                        backgroundColor: palette.surface,
                      ),
                    );
                  },
                  child: Text('Cancel', style: GLuxuryTypography.labelMedium.copyWith(color: Colors.red)),
                )
              else
                TextButton(
                  onPressed: () {},
                  child: Text('View Details', style: GLuxuryTypography.labelMedium.copyWith(color: palette.primary)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
