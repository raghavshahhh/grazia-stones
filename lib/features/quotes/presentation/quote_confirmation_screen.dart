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

/// Screen showing quote confirmation with PDF download/share options
class QuoteConfirmationScreen extends ConsumerWidget {
  final String quoteId;
  final String customerName;
  final String customerEmail;
  final String customerPhone;
  final String? customerAddress;
  final List<QuoteLineItem> items;
  final String? notes;

  const QuoteConfirmationScreen({
    super.key,
    required this.quoteId,
    required this.customerName,
    required this.customerEmail,
    required this.customerPhone,
    this.customerAddress,
    required this.items,
    this.notes,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(themePaletteProvider);
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    // Calculate totals
    final subtotal = items.fold<double>(0, (sum, item) => sum + item.total);
    final gstAmount = subtotal * 0.18;
    final shippingCharges = subtotal < 10000 ? 500.0 : 0.0;
    final grandTotal = subtotal + gstAmount + shippingCharges;

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
          'Quote Confirmation',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
        actions: [
          PDFDownloadButton(
            fileName: 'Quote_$quoteId',
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
                          'Quote Request Submitted!',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: palette.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Our team will contact you within 24 hours',
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

            // Quote ID
            _buildInfoCard(
              palette,
              'Quote Number',
              quoteId,
              Icons.receipt_long_rounded,
            ),

            const SizedBox(height: 16),

            // Customer Info
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
                  if (customerAddress != null && customerAddress!.isNotEmpty)
                    _buildDetailRow(palette, 'Address', customerAddress!, isLast: true),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Items
            _buildSectionHeader(palette, 'Items Requested'),
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

            if (notes != null && notes!.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildSectionHeader(palette, 'Notes'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.border),
                ),
                child: Text(
                  notes!,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: palette.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
            ],

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
                onPressed: () => _shareQuotePDF(context, palette),
                icon: const Icon(Icons.share_rounded, size: 18),
                label: const Text('Share Quote'),
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
                label: 'Preview PDF',
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
    return pdfService.generateQuotePDF(
      quoteId: quoteId,
      customerName: customerName,
      customerEmail: customerEmail,
      customerPhone: customerPhone,
      customerAddress: customerAddress,
      items: items,
      notes: notes,
      validUntil: DateTime.now().add(const Duration(days: 30)),
    );
  }

  Future<void> _shareQuotePDF(BuildContext context, LuxuryPalette palette) async {
    try {
      final pdfData = await _generatePDF();
      await Printing.sharePdf(
        bytes: pdfData,
        filename: 'Quote_${quoteId}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      HapticFeedback.heavyImpact();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to share quote: $e',
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
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: palette.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: palette.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
            ],
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
    QuoteLineItem item,
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
          Row(
            children: [
              _buildSpec(palette, item.finish),
              const SizedBox(width: 8),
              _buildSpec(palette, item.color),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${item.quantity} sq.ft',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: palette.textSecondary,
                ),
              ),
              Text(
                ' × ',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: palette.textTertiary,
                ),
              ),
              Text(
                '${currencyFormat.format(item.pricePerSqFt)}/sq.ft',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpec(LuxuryPalette palette, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          color: palette.textSecondary,
        ),
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
}
