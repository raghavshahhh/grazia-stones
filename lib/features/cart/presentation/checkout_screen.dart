import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/services/payment_service.dart';
import 'package:grazia_stones/core/services/supabase_service.dart';
import 'package:grazia_stones/core/widgets/error_handler_widget.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';

import 'package:grazia_stones/features/cart/presentation/cart_screen.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  final List<CheckoutItem>? items;
  final double? subtotal;
  final double? gst;
  final double? shipping;
  final double? total;

  const CheckoutScreen({
    super.key,
    this.items,
    this.subtotal,
    this.gst,
    this.shipping,
    this.total,
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
  bool _isLoadingAddresses = true;
  double _discount = 0;
  List<Map<String, dynamic>> _addresses = [];

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    try {
      final userRepo = ref.read(userRepositoryProvider);
      final list = await userRepo.getAddresses();
      if (mounted) {
        setState(() {
          _addresses = list;
          _isLoadingAddresses = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingAddresses = false);
      }
    }
  }

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
      final cartItems = ref.read(cartProvider);
      final defaultSubtotal = cartItems.fold<double>(0.0, (s, i) => s + (i.stone.pricePerSqFt * i.quantity));
      final currentSubtotal = widget.subtotal ?? defaultSubtotal;
      double discount = 0;
      if (code == 'WELCOME10') {
        discount = currentSubtotal * 0.10;
      } else if (code == 'GRAB20') {
        discount = currentSubtotal * 0.20;
      } else if (code == 'FESTIVE15') {
        discount = currentSubtotal * 0.15;
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
    final authState = ref.read(authRiverpodProvider);
    if (!authState.isLoggedIn) {
      _showSignInRequiredDialog();
      return;
    }

    if (_addresses.isEmpty) {
      showErrorSnackbar(context, Exception('Please add a delivery address first'));
      return;
    }

    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    try {
      final orderRepo = ref.read(orderRepositoryProvider);
      final cartNotifier = ref.read(cartProvider.notifier);
      final cartItems = ref.read(cartProvider);

      final currentItems = widget.items ??
          cartItems
              .map((it) => CheckoutItem(
                    stoneId: it.stone.id,
                    name: it.stone.name,
                    quantity: it.quantity,
                    price: it.stone.pricePerSqFt,
                  ))
              .toList();

      if (currentItems.isEmpty) {
        throw Exception('Cart is empty');
      }

      final orderItems = currentItems
          .map((item) => {
                'stone_id': item.stoneId,
                'name': item.name,
                'product_code': '',
                'image_url': '',
                'unit_price': item.price,
                'quantity': item.quantity,
              })
          .toList();

      final addr = _addresses[_selectedAddressIndex.clamp(0, _addresses.length - 1)];

      // Compute the exact amounts the UI is showing (and Razorpay will
      // charge) once, from one source of truth, so the persisted order
      // can never diverge from the charged total.
      final calcSubtotal = currentItems.fold<double>(0.0, (s, i) => s + i.price * i.quantity);
      final calcGst = calcSubtotal * 0.18;
      final calcShipping = calcSubtotal > 10000 ? 0.0 : (calcSubtotal > 0 ? 500.0 : 0.0);
      final effectiveSubtotal = widget.subtotal ?? calcSubtotal;
      final effectiveGst = widget.gst ?? calcGst;
      final effectiveShipping = widget.shipping ?? calcShipping;
      final effectiveTotal = (widget.total ?? (effectiveSubtotal + effectiveGst + effectiveShipping)) - _discount;

      final order = await orderRepo.createOrder(
        items: orderItems,
        address: {
          'name': addr['name'] ?? '',
          'phone': addr['phone'] ?? '',
          'address_line1': addr['address_line1'] ?? '',
          'address_line2': addr['address_line2'] ?? '',
          'city': addr['city'] ?? '',
          'state': addr['state'] ?? '',
          'pincode': addr['pincode'] ?? '',
        },
        paymentMethod: _selectedPaymentMethod,
        notes: 'Checkout from mobile app',
        tax: effectiveGst,
        shippingCost: effectiveShipping,
        discount: _discount,
        total: effectiveTotal,
      );

      if (_selectedPaymentMethod == 'razorpay') {
        final paymentResult = await orderRepo.initiatePayment(
          orderId: order.id,
          paymentMethod: 'razorpay',
        );

        final paymentService = PaymentService.instance;

        await paymentService.openCheckout(
          amount: effectiveTotal,
          orderId: paymentResult['razorpay_order_id'] ?? order.id,
          name: addr['name']?.toString() ?? 'Client',
          description: 'Grazia Stones Order Payment',
          email: SupabaseService.instance.currentUser?.email ?? 'guest@graziastones.com',
          contact: addr['phone']?.toString() ?? '',
          onSuccess: (response) async {
            try {
              await orderRepo.verifyPayment(
                orderId: order.id,
                paymentId: response.paymentId ?? '',
                signature: response.signature ?? '',
              );

              if (mounted) {
                setState(() => _isProcessing = false);
                cartNotifier.clear();
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
        if (mounted) {
          setState(() => _isProcessing = false);
          cartNotifier.clear();
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

  void _showSignInRequiredDialog() {
    final palette = ref.read(themePaletteProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Sign In Required',
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700, color: palette.textPrimary),
        ),
        content: Text(
          'Please sign in or register an account to place your order.',
          style: GoogleFonts.inter(fontSize: 14, color: palette.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(color: palette.textTertiary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Sign In', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String orderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final palette = ref.read(themePaletteProvider);
        return AlertDialog(
          backgroundColor: palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: palette.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_outline,
                  color: palette.primary,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Order Placed Successfully',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Order #$orderId',
                style: GoogleFonts.inter(
                  color: palette.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your architectural order has been received. Our stone concierge will contact you within 24 hours.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: palette.textSecondary,
                  fontSize: 13,
                  height: 1.4,
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
                        foregroundColor: palette.primary,
                        side: BorderSide(color: palette.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'View Orders',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
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
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      child: Text(
                        'Continue',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
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
    final palette = ref.watch(themePaletteProvider);
    final cartItems = ref.watch(cartProvider);
    final calcSubtotal = cartItems.fold<double>(0.0, (s, i) => s + (i.stone.pricePerSqFt * i.quantity));
    final calcGst = calcSubtotal * 0.18;
    final calcShipping = calcSubtotal > 10000 ? 0.0 : (calcSubtotal > 0 ? 500.0 : 0.0);
    final effectiveSubtotal = widget.subtotal ?? calcSubtotal;
    final effectiveGst = widget.gst ?? calcGst;
    final effectiveShipping = widget.shipping ?? calcShipping;
    final effectiveTotal = (widget.total ?? (effectiveSubtotal + effectiveGst + effectiveShipping)) - _discount;
    final itemCount = widget.items?.length ?? cartItems.length;


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
          'Checkout & Delivery',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Delivery Address
            _buildSectionTitle('DELIVERY DESTINATION', palette),
            const SizedBox(height: 10),
            if (_isLoadingAddresses)
              Center(child: Padding(padding: const EdgeInsets.all(20), child: CircularProgressIndicator(color: palette.primary)))
            else if (_addresses.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('No delivery addresses found. Please add one below.', style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 13)),
              )
            else
              ..._addresses.asMap().entries.map((entry) {
                final index = entry.key;
                final address = entry.value;
                return _buildAddressCard(palette, address, index);
              }),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => context.push('/addresses').then((_) => _loadAddresses()),
              icon: const Icon(Icons.add_location_alt_outlined, size: 18),
              label: const Text('Manage Delivery Addresses'),
              style: OutlinedButton.styleFrom(
                foregroundColor: palette.primary,
                side: BorderSide(color: palette.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              ),
            ),

            const SizedBox(height: 24),

            // Coupon Code
            _buildSectionTitle('PROMOTIONAL CODE', palette),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _couponController,
                    decoration: InputDecoration(
                      hintText: 'Enter coupon code (e.g. WELCOME10)',
                      hintStyle: GoogleFonts.inter(fontSize: 12, color: palette.textTertiary),
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
                        borderSide: BorderSide(color: palette.primary, width: 1.5),
                      ),
                      filled: true,
                      fillColor: palette.surface,
                      prefixIcon: Icon(Icons.local_offer_outlined, color: palette.primary, size: 20),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    ),
                    style: GoogleFonts.inter(fontSize: 13, color: palette.textPrimary),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isApplyingCoupon ? null : _applyCoupon,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isApplyingCoupon
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text('Apply', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ],
            ),

            if (_discount > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Promotional voucher applied: ₹${_discount.toInt()} savings',
                      style: GoogleFonts.inter(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Payment Method
            _buildSectionTitle('PAYMENT SELECTION', palette),
            const SizedBox(height: 10),
            _buildPaymentMethod(palette, 'razorpay', 'Razorpay (UPI, NetBanking, Cards)', Icons.account_balance_wallet_outlined),
            _buildPaymentMethod(palette, 'cod', 'Cash on Delivery (Site Verification)', Icons.payments_outlined),

            const SizedBox(height: 24),

            // Order Summary
            _buildSectionTitle('ORDER BREAKDOWN', palette),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                children: [
                  _buildSummaryRow('Slabs / Samples ($itemCount items)', effectiveSubtotal, palette),
                  const SizedBox(height: 12),
                  _buildSummaryRow('GST (18%)', effectiveGst, palette),
                  const SizedBox(height: 12),
                  _buildSummaryRow('Delivery & Insurance', effectiveShipping, palette, highlight: effectiveShipping == 0),
                  if (_discount > 0) ...[
                    const SizedBox(height: 12),
                    _buildSummaryRow('Discount Applied', -_discount, palette, isDiscount: true),
                  ],
                  Divider(color: palette.border, height: 24),
                  _buildSummaryRow('Payable Amount', effectiveTotal, palette, isTotal: true),
                ],
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 14,
          bottom: MediaQuery.of(context).padding.bottom + 14,
        ),
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border(top: BorderSide(color: palette.border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isProcessing ? null : _proceedToPayment,
          style: ElevatedButton.styleFrom(
            backgroundColor: palette.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          child: _isProcessing
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text('Processing Payment...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ],
                )
              : Text(
                  'Authorize Payment • ₹${effectiveTotal.toInt()}',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, LuxuryPalette palette) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.8,
        color: palette.textTertiary,
      ),
    );
  }

  Widget _buildAddressCard(LuxuryPalette palette, Map<String, dynamic> address, int index) {
    final isSelected = _selectedAddressIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedAddressIndex = index);
        HapticFeedback.selectionClick();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? palette.primary : palette.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: isSelected ? palette.primary : palette.textTertiary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        address['name']?.toString() ?? 'Address',
                        style: GoogleFonts.inter(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      if (address['is_default'] == true || index == 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: palette.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'DEFAULT',
                            style: GoogleFonts.inter(
                              color: palette.primary,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${address['address_line1'] ?? ''}${address['address_line2'] != null && address['address_line2'] != '' ? ', ${address['address_line2']}' : ''}, ${address['city'] ?? ''}, ${address['state'] ?? ''} - ${address['pincode'] ?? ''}',
                    style: GoogleFonts.inter(
                      color: palette.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  if (address['phone'] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Phone: ${address['phone']}',
                      style: GoogleFonts.inter(color: palette.textTertiary, fontSize: 11),
                    ),
                  ],
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
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? palette.primary : palette.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? palette.primary : palette.textTertiary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Icon(icon, color: palette.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  color: palette.textPrimary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
            if (value == 'razorpay')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: palette.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Recommended',
                  style: GoogleFonts.inter(
                    color: palette.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
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
          style: GoogleFonts.inter(
            fontSize: isTotal ? 14 : 13,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            color: isTotal ? palette.textPrimary : palette.textSecondary,
          ),
        ),
        Text(
          highlight && amount == 0
              ? 'FREE ✓'
              : '${isDiscount ? '-' : ''}₹${amount.abs().toInt()}',
          style: GoogleFonts.inter(
            fontSize: isTotal ? 18 : 13,
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
            color: highlight && amount == 0
                ? palette.success
                : isDiscount
                    ? palette.success
                    : (isTotal ? palette.primary : palette.textPrimary),
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

