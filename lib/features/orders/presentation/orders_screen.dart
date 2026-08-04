import 'package:flutter/material.dart';
import 'package:grazia_stones/core/constants/app_colors.dart';
import 'package:grazia_stones/core/constants/app_dimensions.dart';
import 'package:grazia_stones/core/theme/text_styles.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

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
          'My Orders',
          style: GraziaTextStyles.titleMedium.copyWith(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.spacingL),
        children: [
          _OrderCard(
            orderId: 'GS-2026-0042',
            stone: 'Charcoal Black',
            quantity: '200 sq ft',
            status: 'Delivered',
            statusColor: Colors.green,
            date: 'Jul 10, 2026',
          ),
          const SizedBox(height: 12),
          _OrderCard(
            orderId: 'GS-2026-0038',
            stone: 'Walnut Brown',
            quantity: '1200 sq ft',
            status: 'In Transit',
            statusColor: AppColors.gold,
            date: 'Jul 18, 2026',
          ),
          const SizedBox(height: 12),
          _OrderCard(
            orderId: 'GS-2026-0035',
            stone: 'Matte White',
            quantity: '80 sq ft',
            status: 'Processing',
            statusColor: Colors.blue,
            date: 'Jul 20, 2026',
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final String orderId;
  final String stone;
  final String quantity;
  final String status;
  final Color statusColor;
  final String date;

  const _OrderCard({
    required this.orderId,
    required this.stone,
    required this.quantity,
    required this.status,
    required this.statusColor,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingL),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                orderId,
                style: GraziaTextStyles.bodySmall.copyWith(
                  color: AppColors.silver,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: GraziaTextStyles.bodySmall.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            stone,
            style: GraziaTextStyles.bodyLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                quantity,
                style: GraziaTextStyles.bodyMedium.copyWith(
                  color: AppColors.gold,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                date,
                style: GraziaTextStyles.bodySmall.copyWith(
                  color: AppColors.silver,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: status == 'Delivered'
                  ? 1.0
                  : status == 'In Transit'
                      ? 0.7
                      : 0.3,
              backgroundColor: AppColors.slate,
              valueColor: AlwaysStoppedAnimation(statusColor),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}
