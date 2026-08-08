import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/services/payment_service.dart';
import 'package:grazia_stones/core/widgets/error_handler_widget.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/typography.dart';
import 'package:grazia_stones/shared/theme/spacing.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  final List<CheckoutItem> items;
  final double subtotal;
  final double gst;
  final double shipping;
  final double total;

  const CheckoutScreen({
    super.key,
    required this.items,
    required this.subtotal,
    required this.gst,
    required this.shipping,
    required this.total,
  });

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  int _selectedAddressIndex = 0;
  String _selectedPaymentMethod = 'razorpay';
  final _couponController = TextEditingController();
  bool _isApplyingCoupon = false;
  bool _isProcessing = false;
  double _discount = 0;

  // Mock addresses - In production, load from UserApi
  final List<Map<String, String>> _addresses = [
    {
      'id': '1',
      'name': 'Home',
      'address': '123 Main Street, Apartment 4B',
      'city': 'Mumbai',
      'state': 'Maharashtra',
      'pincode': '400001',
      'phone': '+91 9876543210',
    },
    {
      'id': '2',
      'name': 'Office',
      'address': '456 Business Park, Floor 5',
      'city': 'Mumbai',
      'state': 'Maharashtra',
      'pincode': '400002',
      'phone': '+91 9876543210',
    },
  ];

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _applyCoupon() async {
    if (_couponController.text.trim().isEmpty) {
      showErrorSnackbar(context, Exception('Please enter a coupon code'));
      return;
    }

    setState(() => _isApplyingCoupon = true);
    HapticFeedback.mediumImpact();

    try {
      final code = _couponController.text.trim().toUpperCase();
      // Simple coupon validation - can be extended with API check
      double discount = 0;
      if (code == 'WELCOME10') {
        discount = widget.subtotal * 0.10;
      } else if (code == 'GRAB20') {
        discount = widget.subtotal * 0.20;
      } else if (code == 'FESTIVE15') {
        discount = widget.subtotal * 0.15;
      } else {
        throw Exception('Invalid coupon code');
      }

      if (mounted) {
        setState(() {
          _isApplyingCoupon = false;
          _discount = discount;
        });
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isApplyingCoupon = false);
        showErrorSnackbar(context, e);
      }
    }
  }

  Future<void> _proceedToPayment() async {
    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    try {
      final orderRepo = ref.read(orderRepositoryProvider);
      final cartRepo = ref.read(cartRepositoryProvider);

      // 1. Validate cart
      final summary = await cartRepo.getCartSummary();
      if (summary['itemCount'] == 0) {
        throw Exception('Cart is empty');
      }

      // 2. Create order
      final orderItems = widget.items
          .map((item) => {
                'stone_id': item.stoneId,
                'name': item.name,
                'product_code': '',
                'image_url': '',
                'unit_price': item.price,
                'quantity': item.quantity,
              })
          .toList();

      final addr = _addresses[_selectedAddressIndex];
      final order = await orderRepo.createOrder(
        items: orderItems,
        address: {
          'name': addr['name'] ?? '',
          'phone': addr['phone'] ?? '',
          'address_line1': addr['address'] ?? '',
          'city': addr['city'] ?? '',
          'state': addr['state'] ?? '',
          'pincode': addr['pincode'] ?? '',
        },
        paymentMethod: _selectedPaymentMethod,
        notes: 'Checkout from app',
      );

      // 3. Initiate payment if Razorpay selected
      if (_selectedPaymentMethod == 'razorpay') {
        final paymentResult = await orderRepo.initiatePayment(
          orderId: order.id,
          paymentMethod: 'razorpay',
        );

        // 4. Open Razorpay checkout
        final paymentService = PaymentService.instance;
        final finalAmount = widget.total - _discount;

        await paymentService.openCheckout(
          amount: finalAmount,
          orderId: paymentResult['razorpay_order_id'] ?? order.id,
          name: _addresses[_selectedAddressIndex]['name']!,
          description: 'Grazia Stones Order Payment',
          email: 'user@example.com', // TODO: Get from user profile
          contact: _addresses[_selectedAddressIndex]['phone']!,
          onSuccess: (response) async {
            // Verify payment
            try {
              await orderRepo.verifyPayment(
                orderId: order.id,
                paymentId: response.paymentId ?? '',
                signature: response.signature ?? '',
              );

              if (mounted) {
                setState(() => _isProcessing = false);
                // Clear cart
                await cartRepo.clearCart();
                // Show success and navigate
                _showSuccessDialog(order.id);
              }
            } catch (e) {
              if (mounted) {
                setState(() => _isProcessing = false);
                showErrorSnackbar(context, Exception('Payment verification failed'));
              }
            }
          },
          onError: (response) async {
            // Mark payment as failed
            await orderRepo.paymentFailed(
              orderId: order.id,
              reason: response.message ?? 'Payment failed',
            );

            if (mounted) {
              setState(() => _isProcessing = false);
              showErrorSnackbar(
                context,
                Exception('Payment failed: ${response.message}'),
              );
            }
          },
        );
      } else {
        // COD or other payment methods
        if (mounted) {
          setState(() => _isProcessing = false);
          await cartRepo.clearCart();
          _showSuccessDialog(order.id);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        showErrorSnackbar(context, e);
      }
    }
  }

  void _showSuccessDialog(String orderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final palette = GLuxuryPalettes.gold;
        return AlertDialog(
          backgroundColor: palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: palette.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_outline,
                  color: palette.background,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Order Placed!',
                style: GLuxuryTypography.h2.copyWith(color: palette.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Order #$orderId',
                style: GLuxuryTypography.bodySmall.copyWith(
                  color: palette.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your order has been placed successfully. We will contact you within 24 hours.',
                textAlign: TextAlign.center,
                style: GLuxuryTypography.bodyMedium.copyWith(
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        context.go('/orders');
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: palette.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'View Orders',
                        style: GLuxuryTypography.labelMedium.copyWith(
                          color: palette.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        context.go('/');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.primary,
                        foregroundColor: palette.background,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'Continue',
                        style: GLuxuryTypography.labelMedium.copyWith(
                          color: palette.background,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = GLuxuryPalettes.gold;
    final finalTotal = widget.total - _discount;

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
          'Checkout',
          style: GLuxuryTypography.h2.copyWith(color: palette.textPrimary),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Delivery Address
            Text(
              'Delivery Address',
              style: GLuxuryTypography.h3.copyWith(color: palette.textPrimary),
            ),
            GLuxurySpacing.gapSm,
            ..._addresses.asMap().entries.map((entry) {
              final index = entry.key;
              final address = entry.value;
              return _buildAddressCard(palette, address, index);
            }),
            GLuxurySpacing.gapBase,
            OutlinedButton.icon(
              onPressed: () {
                // TODO: Navigate to add address screen
                showInfoSnackbar(context, 'Add address feature coming soon');
              },
              icon: const Icon(Icons.add),
              label: const Text('Add New Address'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: palette.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),

            GLuxurySpacing.gapXl,

            // Coupon Code
            Text(
              'Apply Coupon',
              style: GLuxuryTypography.h3.copyWith(color: palette.textPrimary),
            ),
            GLuxurySpacing.gapSm,
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _couponController,
                    decoration: InputDecoration(
                      hintText: 'Enter coupon code',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: palette.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: palette.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: palette.primary, width: 2),
                      ),
                      filled: true,
                      fillColor: palette.surface,
                      prefixIcon: Icon(Icons.local_offer_outlined, color: palette.textTertiary),
                    ),
                    style: GLuxuryTypography.bodyMedium.copyWith(color: palette.textPrimary),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isApplyingCoupon ? null : _applyCoupon,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: palette.background,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isApplyingCoupon
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Apply'),
                ),
              ],
            ),

            if (_discount > 0) ...[
              GLuxurySpacing.gapSm,
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Coupon applied! You saved ₹${_discount.toInt()}',
                      style: GLuxuryTypography.bodySmall.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            GLuxurySpacing.gapXl,

            // Payment Method
            Text(
              'Payment Method',
              style: GLuxuryTypography.h3.copyWith(color: palette.textPrimary),
            ),
            GLuxurySpacing.gapSm,
            _buildPaymentMethod(palette, 'razorpay', 'Razorpay (UPI, Cards, Wallets)', Icons.payment),
            _buildPaymentMethod(palette, 'cod', 'Cash on Delivery', Icons.money),

            GLuxurySpacing.gapXl,

            // Order Summary
            Text(
              'Order Summary',
              style: GLuxuryTypography.h3.copyWith(color: palette.textPrimary),
            ),
            GLuxurySpacing.gapSm,
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                children: [
                  _buildSummaryRow('Items (${widget.items.length})', widget.subtotal, palette),
                  const SizedBox(height: 12),
                  _buildSummaryRow('GST (18%)', widget.gst, palette),
                  const SizedBox(height: 12),
                  _buildSummaryRow('Shipping', widget.shipping, palette, 
                      highlight: widget.shipping == 0),
                  if (_discount > 0) ...[
                    const SizedBox(height: 12),
                    _buildSummaryRow('Discount', -_discount, palette, isDiscount: true),
                  ],
                  Divider(color: palette.border, height: 24),
                  _buildSummaryRow('Total', finalTotal, palette, isTotal: true),
                ],
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        decoration: BoxDecoration(
          color: palette.background,
          border: Border(top: BorderSide(color: palette.border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isProcessing ? null : _proceedToPayment,
          style: ElevatedButton.styleFrom(
            backgroundColor: palette.primary,
            foregroundColor: palette.background,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            disabledBackgroundColor: palette.surfaceDark,
          ),
          child: _isProcessing
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Processing...',
                      style: GLuxuryTypography.labelLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                )
              : Text(
                  'Pay ₹${finalTotal.toInt()}',
                  style: GLuxuryTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildAddressCard(LuxuryPalette palette, Map<String, String> address, int index) {
    final isSelected = _selectedAddressIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedAddressIndex = index);
        HapticFeedback.selectionClick();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? palette.primary : palette.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? palette.primary : palette.textTertiary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        address['name']!,
                        style: GLuxuryTypography.h3.copyWith(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (index == 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: palette.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Default',
                            style: GLuxuryTypography.labelSmall.copyWith(
                              color: palette.primary,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${address['address']}, ${address['city']}, ${address['state']} - ${address['pincode']}',
                    style: GLuxuryTypography.bodySmall.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Phone: ${address['phone']}',
                    style: GLuxuryTypography.labelSmall.copyWith(
                      color: palette.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethod(LuxuryPalette palette, String value, String label, IconData icon) {
    final isSelected = _selectedPaymentMethod == value;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedPaymentMethod = value);
        HapticFeedback.selectionClick();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? palette.primary : palette.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? palette.primary : palette.textTertiary,
            ),
            const SizedBox(width: 12),
            Icon(icon, color: palette.textPrimary, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GLuxuryTypography.bodyMedium.copyWith(
                  color: palette.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (value == 'razorpay')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Recommended',
                  style: GLuxuryTypography.labelSmall.copyWith(
                    color: Colors.green,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    double amount,
    LuxuryPalette palette, {
    bool isTotal = false,
    bool highlight = false,
    bool isDiscount = false,
  }) {
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
          highlight && amount == 0
              ? 'FREE ✓'
              : '${isDiscount ? '-' : ''}₹${amount.abs().toInt()}',
          style: (isTotal ? GLuxuryTypography.h3 : GLuxuryTypography.bodyMedium).copyWith(
            color: highlight && amount == 0
                ? Colors.green
                : isDiscount
                    ? Colors.green
                    : (isTotal ? palette.primary : palette.textPrimary),
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// Model for checkout items
class CheckoutItem {
  final String stoneId;
  final String name;
  final int quantity;
  final double price;

  CheckoutItem({
    required this.stoneId,
    required this.name,
    required this.quantity,
    required this.price,
  });
}
