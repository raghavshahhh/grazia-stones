import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/services/mock_data_service.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/typography.dart';
import 'package:grazia_stones/shared/theme/spacing.dart';

class CartItem {
  final Stone stone;
  int quantity;

  CartItem({required this.stone, this.quantity = 1});

  double get total => stone.pricePerSqFt * quantity;
}

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<CartItem> _cartItems = [];

  @override
  void initState() {
    super.initState();
    // Mock cart with 3 items
    final stones = MockDataService.getAllStones().take(3).toList();
    _cartItems = [
      CartItem(stone: stones[0], quantity: 2),
      CartItem(stone: stones[1], quantity: 1),
      if (stones.length > 2) CartItem(stone: stones[2], quantity: 3),
    ];
  }

  double get _subtotal => _cartItems.fold(0, (sum, item) => sum + item.total);
  double get _gst => _subtotal * 0.18; // 18% GST
  double get _shipping => _subtotal > 10000 ? 0 : 500; // Free shipping above ₹10k
  double get _total => _subtotal + _gst + _shipping;

  void _updateQuantity(int index, int delta) {
    setState(() {
      _cartItems[index].quantity += delta;
      if (_cartItems[index].quantity <= 0) {
        _cartItems.removeAt(index);
      }
    });
    HapticFeedback.lightImpact();
  }

  void _removeItem(int index) {
    setState(() => _cartItems.removeAt(index));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Removed from cart'), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = GLuxuryPalettes.gold;

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
          'Cart (${_cartItems.length})',
          style: GLuxuryTypography.h2.copyWith(color: palette.textPrimary),
        ),
      ),
      body: _cartItems.isEmpty ? _buildEmptyCart(palette) : _buildCartContent(palette),
      bottomNavigationBar: _cartItems.isEmpty ? null : _buildCheckoutBar(palette),
    );
  }

  Widget _buildEmptyCart(GoldPalette palette) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 80, color: palette.textTertiary.withValues(alpha: 0.3)),
          GLuxurySpacing.gapBase,
          Text('Your cart is empty', style: GLuxuryTypography.h2.copyWith(color: palette.textPrimary)),
          GLuxurySpacing.gapSm,
          Text('Add stones to get started', style: GLuxuryTypography.bodyMedium.copyWith(color: palette.textSecondary)),
          GLuxurySpacing.gapXl,
          ElevatedButton(
            onPressed: () => context.go('/home'),
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.primary,
              foregroundColor: palette.background,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            child: Text('Browse Stones', style: GLuxuryTypography.labelLarge),
          ),
        ],
      ),
    );
  }

  Widget _buildCartContent(GoldPalette palette) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cart Items
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _cartItems.length,
            itemBuilder: (context, i) => _buildCartCard(_cartItems[i], i, palette),
          ),
          
          GLuxurySpacing.gapXl,
          
          // Price Breakdown
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Price Details', style: GLuxuryTypography.h3.copyWith(color: palette.textPrimary)),
                GLuxurySpacing.gapBase,
                _buildPriceRow('Subtotal', _subtotal, palette),
                const SizedBox(height: 12),
                _buildPriceRow('GST (18%)', _gst, palette),
                const SizedBox(height: 12),
                _buildPriceRow('Shipping', _shipping, palette, highlight: _shipping == 0),
                const Divider(height: 32),
                _buildPriceRow('Total', _total, palette, isTotal: true),
              ],
            ),
          ),
          
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _buildCartCard(CartItem item, int index, GoldPalette palette) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              item.stone.imageUrl ?? '',
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 80,
                height: 80,
                color: palette.surfaceDark,
                child: Icon(Icons.image, color: palette.textTertiary),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.stone.name,
                        style: GLuxuryTypography.h3.copyWith(color: palette.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _removeItem(index),
                      icon: Icon(Icons.close, color: palette.textTertiary, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                Text(
                  item.stone.collection,
                  style: GLuxuryTypography.bodySmall.copyWith(color: palette.textSecondary),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Quantity selector
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: palette.border),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => _updateQuantity(index, -1),
                            icon: const Icon(Icons.remove, size: 18),
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              '${item.quantity}',
                              style: GLuxuryTypography.bodyMedium.copyWith(
                                color: palette.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _updateQuantity(index, 1),
                            icon: const Icon(Icons.add, size: 18),
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    // Price
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${item.total.toInt()}',
                          style: GLuxuryTypography.h3.copyWith(color: palette.primary),
                        ),
                        Text(
                          '₹${item.stone.pricePerSqFt.toInt()}/sqft',
                          style: GLuxuryTypography.labelSmall.copyWith(color: palette.textTertiary),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, double amount, GoldPalette palette, {bool isTotal = false, bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: (isTotal ? GLuxuryTypography.h3 : GLuxuryTypography.bodyMedium).copyWith(
            color: isTotal ? palette.textPrimary : palette.textSecondary,
          ),
        ),
        Text(
          highlight && amount == 0 ? 'FREE' : '₹${amount.toInt()}',
          style: (isTotal ? GLuxuryTypography.h2 : GLuxuryTypography.bodyMedium).copyWith(
            color: highlight && amount == 0 ? Colors.green : (isTotal ? palette.primary : palette.textPrimary),
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildCheckoutBar(GoldPalette palette) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: palette.background,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total', style: GLuxuryTypography.bodySmall.copyWith(color: palette.textSecondary)),
              Text(
                '₹${_total.toInt()}',
                style: GLuxuryTypography.h2.copyWith(color: palette.primary, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Proceeding to checkout...'), backgroundColor: Colors.green),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.primary,
                foregroundColor: palette.background,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
              child: Text('Checkout', style: GLuxuryTypography.labelLarge.copyWith(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
