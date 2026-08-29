import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grazia_stones/core/services/pdf_service.dart';
import 'package:grazia_stones/core/widgets/pdf_preview_button.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

/// Screen showing order confirmation with PDF invoice download/share options
class OrderConfirmationScreen extends ConsumerWidget {
  final String orderId;
  final String customerName;
  final String customerEmail;
  final String customerPhone;
  final String deliveryAddress;
  final List<OrderLineItem> items;
  final double subtotal;
  final double gstAmount;
  final double shippingCharges;
  final double discount;
  final double grandTotal;
  final String paymentMethod;
  final String paymentStatus;
  final String orderStatus;
  final DateTime? orderDate;
  final DateTime? estimatedDelivery;

  const OrderConfirmationScreen({
    super.key,
    required this.orderId,
    required this.customerName,
    required this.customerEmail,
    required this.customerPhone,
    required this.deliveryAddress,
    required this.items,
    required this.subtotal,
    required this.gstAmount,
    required this.shippingCharges,
    required this.discount,
    required this.grandTotal,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.orderStatus,
    this.orderDate,
    this.estimatedDelivery,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(themePaletteProvider);
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final dateFormat = DateFormat('dd MMM yyyy');

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
          'Order Confirmation',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
        actions: [
          PDFDownloadButton(
            fileName: 'Invoice_$orderId',
            onGeneratePdf: () => _generatePDF(),
            palette: palette,
            onDownloadComplete: () {
              HapticFeedback.heavyImpact();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Success message
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF2E7D32),
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order Placed Successfully!',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: palette.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'You will receive order updates via email',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Order Info Cards
            Row(
              children: [
                Expanded(
                  child: _buildInfoCard(
                    palette,
                    'Order ID',
                    orderId,
                    Icons.receipt_long_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoCard(
                    palette,
                    'Status',
                    orderStatus,
                    Icons.local_shipping_rounded,
                    color: _getStatusColor(orderStatus),
                  ),
                ),
              ],
            ),

            if (estimatedDelivery != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: palette.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule_rounded, color: palette.primary, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Estimated Delivery: ${dateFormat.format(estimatedDelivery!)}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: palette.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Customer & Delivery Info
            _buildSectionHeader(palette, 'Customer Information'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(palette, 'Name', customerName),
                  _buildDetailRow(palette, 'Email', customerEmail),
                  _buildDetailRow(palette, 'Phone', customerPhone),
                  _buildDetailRow(palette, 'Delivery', deliveryAddress, isLast: true),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Items Ordered
            _buildSectionHeader(palette, 'Items Ordered'),
            const SizedBox(height: 12),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildItemCard(palette, item, currencyFormat),
            )),

            const SizedBox(height: 16),

            // Totals
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                children: [
                  _buildTotalRow(palette, 'Subtotal', currencyFormat.format(subtotal)),
                  if (discount > 0)
                    _buildTotalRow(palette, 'Discount', '-${currencyFormat.format(discount)}'),
                  _buildTotalRow(palette, 'GST (18%)', currencyFormat.format(gstAmount)),
                  _buildTotalRow(palette, 'Shipping', currencyFormat.format(shippingCharges)),
                  const Divider(height: 24),
                  _buildTotalRow(
                    palette,
                    'Grand Total',
                    currencyFormat.format(grandTotal),
                    isBold: true,
                    fontSize: 16,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Payment Info
            _buildSectionHeader(palette, 'Payment Information'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment Method',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: palette.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        paymentMethod,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: palette.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getPaymentStatusColor(paymentStatus).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _getPaymentStatusColor(paymentStatus).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      paymentStatus.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _getPaymentStatusColor(paymentStatus),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border(top: BorderSide(color: palette.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _shareInvoicePDF(context, palette),
                icon: const Icon(Icons.share_rounded, size: 18),
                label: const Text('Share Invoice'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.textPrimary,
                  side: BorderSide(color: palette.border),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: PDFPreviewButton(
                label: 'View Invoice',
                icon: Icons.picture_as_pdf_rounded,
                onGeneratePdf: () => _generatePDF(),
                palette: palette,
                isPrimary: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<Uint8List> _generatePDF() async {
    final pdfService = PDFService.instance;
    return pdfService.generateOrderPDF(
      orderId: orderId,
      customerName: customerName,
      customerEmail: customerEmail,
      customerPhone: customerPhone,
      deliveryAddress: deliveryAddress,
      items: items,
      subtotal: subtotal,
      gstAmount: gstAmount,
      shippingCharges: shippingCharges,
      discount: discount,
      grandTotal: grandTotal,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      orderStatus: orderStatus,
      orderDate: orderDate,
      estimatedDelivery: estimatedDelivery,
    );
  }

  Future<void> _shareInvoicePDF(BuildContext context, LuxuryPalette palette) async {
    try {
      final pdfData = await _generatePDF();
      await Printing.sharePdf(
        bytes: pdfData,
        filename: 'Invoice_${orderId}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      HapticFeedback.heavyImpact();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to share invoice: $e',
              style: GoogleFonts.inter(fontSize: 13),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildInfoCard(
    LuxuryPalette palette,
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color ?? palette.primary, size: 20),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: palette.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(LuxuryPalette palette, String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: palette.textPrimary,
      ),
    );
  }

  Widget _buildDetailRow(
    LuxuryPalette palette,
    String label,
    String value, {
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: palette.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: palette.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(
    LuxuryPalette palette,
    OrderLineItem item,
    NumberFormat currencyFormat,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
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
                  item.productName,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
              ),
              Text(
                currencyFormat.format(item.total),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: palette.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${item.finish} • ${item.color}',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${item.quantity} sq.ft × ${currencyFormat.format(item.pricePerSqFt)}/sq.ft',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: palette.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(
    LuxuryPalette palette,
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 13,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: palette.textPrimary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
              color: isBold ? palette.primary : palette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFF57C00);
      case 'confirmed':
        return const Color(0xFF1976D2);
      case 'processing':
        return const Color(0xFF5E35B1);
      case 'shipped':
        return const Color(0xFF7B1FA2);
      case 'delivered':
        return const Color(0xFF2E7D32);
      case 'cancelled':
        return const Color(0xFFD32F2F);
      default:
        return const Color(0xFF616161);
    }
  }

  Color _getPaymentStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return const Color(0xFF2E7D32);
      case 'pending':
        return const Color(0xFFF57C00);
      case 'failed':
        return const Color(0xFFD32F2F);
      default:
        return const Color(0xFF616161);
    }
  }
}
