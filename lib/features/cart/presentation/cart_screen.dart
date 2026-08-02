import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:grazia_stones/core/constants/app_colors.dart';
import 'package:grazia_stones/core/constants/app_dimensions.dart';
import 'package:grazia_stones/core/theme/text_styles.dart';
import 'package:grazia_stones/shared/widgets/grazia_button.dart';
import 'package:grazia_stones/features/cart/providers/cart_provider.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

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
          'Cart',
          style: GraziaTextStyles.titleMedium.copyWith(color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          Consumer<CartProvider>(
            builder: (context, cart, _) {
              if (cart.items.isEmpty) return const SizedBox.shrink();
              return TextButton(
                onPressed: () => cart.clear(),
                child: Text(
                  'Clear All',
                  style: GraziaTextStyles.bodySmall.copyWith(color: AppColors.goldWarm),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<CartProvider>(
        builder: (context, cart, _) {
          if (cart.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shopping_cart_outlined, size: 80, color: AppColors.slate),
                  const SizedBox(height: 16),
                  Text(
                    'Your cart is empty',
                    style: GraziaTextStyles.titleMedium.copyWith(color: AppColors.silver),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Browse our collection to find the perfect stone',
                    style: GraziaTextStyles.bodyMedium.copyWith(color: AppColors.slate),
                  ),
                  const SizedBox(height: 24),
                  GraziaButton(
                    label: 'Browse Stones',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            );
          }

          final total = cart.total;

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(AppDimensions.spacingL),
                  itemCount: cart.items.length,
                  itemBuilder: (context, index) {
                    final item = cart.items[index];
                    final color = Color(int.parse(item.colorHex.replaceFirst('#', '0xFF')));
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.slate),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: GraziaTextStyles.bodyLarge.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${item.finish} · ${item.quantity} sq ft",
                                  style: GraziaTextStyles.bodySmall.copyWith(color: AppColors.silver),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '\$${item.pricePerSqFt}/sqft',
                                  style: GraziaTextStyles.bodyMedium.copyWith(
                                    color: AppColors.gold,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              GestureDetector(
                                onTap: () => cart.updateQuantity(item.stoneId, item.quantity - 1),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AppColors.slate),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.remove, size: 16, color: AppColors.silver),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${item.quantity}',
                                style: GraziaTextStyles.bodyMedium.copyWith(color: Colors.white),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () => cart.updateQuantity(item.stoneId, item.quantity + 1),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AppColors.gold),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.add, size: 16, color: AppColors.gold),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(AppDimensions.spacingL),
                decoration: const BoxDecoration(
                  color: AppColors.graphite,
                  border: Border(top: BorderSide(color: AppColors.slate)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Subtotal (${cart.itemCount} items)',
                          style: GraziaTextStyles.bodyMedium.copyWith(color: AppColors.silver),
                        ),
                        Text(
                          '\$${total.toStringAsFixed(0)}',
                          style: GraziaTextStyles.bodyLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GraziaButton(
                      label: 'Request Final Quote',
                      icon: Icons.arrow_forward,
                      onPressed: () {
                        Navigator.of(context).pushNamed('/quotes');
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
