import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:grazia_stones/core/models/stone.dart';

/// Service for generating professional PDF documents for quotes and orders
/// 
/// Generates Bill of Quantities (BOQ) with:
/// - Company branding and logo
/// - Customer information
/// - Itemized product list with quantities and pricing
/// - GST calculations (18%)
/// - Shipping charges
/// - Terms & Conditions
/// - Payment information
class PDFService {
  static PDFService? _instance;
  static PDFService get instance => _instance ??= PDFService._();

  PDFService._();

  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  final _dateFormat = DateFormat('dd MMM yyyy');

  // ═══════════════════════════════════════════════════════════════════════════
  // QUOTE PDF GENERATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Generate quote PDF
  Future<Uint8List> generateQuotePDF({
    required String quoteId,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    required String? customerAddress,
    required List<QuoteLineItem> items,
    required String? notes,
    DateTime? validUntil,
  }) async {
    final pdf = pw.Document();

    // Calculate totals
    final subtotal = items.fold<double>(0, (sum, item) => sum + item.total);
    final gstAmount = subtotal * 0.18; // 18% GST
    final shippingCharges = subtotal < 10000 ? 500.0 : 0.0;
    final grandTotal = subtotal + gstAmount + shippingCharges;

    // Load logo
    final logoData = await rootBundle.load('assets/brand/grazia-logo-dark.png');
    final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          _buildQuoteHeader(logoImage, quoteId, DateTime.now(), validUntil),
          pw.SizedBox(height: 30),
          _buildCustomerInfo(customerName, customerEmail, customerPhone, customerAddress),
          pw.SizedBox(height: 30),
          _buildItemsTable(items),
          pw.SizedBox(height: 20),
          _buildTotalsSummary(subtotal, gstAmount, shippingCharges, grandTotal),
          pw.SizedBox(height: 30),
          if (notes != null && notes.isNotEmpty) ...[
            _buildNotes(notes),
            pw.SizedBox(height: 20),
          ],
          _buildTermsAndConditions(),
        ],
        footer: (context) => _buildFooter(context.pageNumber, context.pagesCount),
      ),
    );

    return pdf.save();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ORDER PDF GENERATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Generate order PDF
  Future<Uint8List> generateOrderPDF({
    required String orderId,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    required String deliveryAddress,
    required List<OrderLineItem> items,
    required double subtotal,
    required double gstAmount,
    required double shippingCharges,
    required double discount,
    required double grandTotal,
    required String paymentMethod,
    required String paymentStatus,
    required String orderStatus,
    DateTime? orderDate,
    DateTime? estimatedDelivery,
  }) async {
    final pdf = pw.Document();

    // Load logo
    final logoData = await rootBundle.load('assets/brand/grazia-logo-dark.png');
    final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          _buildOrderHeader(logoImage, orderId, orderDate ?? DateTime.now(), orderStatus),
          pw.SizedBox(height: 30),
          _buildOrderCustomerInfo(
            customerName,
            customerEmail,
            customerPhone,
            deliveryAddress,
            estimatedDelivery,
          ),
          pw.SizedBox(height: 30),
          _buildOrderItemsTable(items),
          pw.SizedBox(height: 20),
          _buildOrderTotalsSummary(
            subtotal,
            gstAmount,
            shippingCharges,
            discount,
            grandTotal,
          ),
          pw.SizedBox(height: 20),
          _buildPaymentInfo(paymentMethod, paymentStatus),
          pw.SizedBox(height: 30),
          _buildOrderTermsAndConditions(),
        ],
        footer: (context) => _buildFooter(context.pageNumber, context.pagesCount),
      ),
    );

    return pdf.save();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 3D WALL & TILE CALCULATION SPECIFICATION PDF
  // ═══════════════════════════════════════════════════════════════════════════

  /// Generates a complete Architectural Wall Specification & Tile Calculation PDF
  Future<Uint8List> generateWallSpecPDF({
    required Stone stone,
    required double wallWidthFt,
    required double wallHeightFt,
    required String unit,
    required double wastagePercent,
    required int boxesRequired,
    required int totalTiles,
    required double netAreaSqFt,
    required double grossAreaSqFt,
    required double estimatedCost,
    String? projectName,
    String? clientName,
  }) async {
    final pdf = pw.Document();

    pw.MemoryImage? logoImage;
    try {
      final logoData = await rootBundle.load('assets/brand/grazia-logo-dark.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {}

    final subtotal = grossAreaSqFt * stone.pricePerSqFt;
    final gst = subtotal * 0.18;
    final grandTotal = subtotal + gst;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (logoImage != null) pw.Image(logoImage, width: 110, height: 35),
                  pw.Text(
                    'GRAZIA STONES',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.brown800,
                    ),
                  ),
                  pw.Text(
                    'Architectural Surfaces & Cladding Studio',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text('Kanpur, Uttar Pradesh | info@graziastones.com', style: _textStyle(9)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.amber100,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Text(
                      'ESTIMATION SPEC SHEET',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.brown900,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text('Date: ${_dateFormat.format(DateTime.now())}', style: _textStyle(9)),
                  if (clientName != null && clientName.isNotEmpty)
                    pw.Text('Client: $clientName', style: _textStyle(9)),
                  if (projectName != null && projectName.isNotEmpty)
                    pw.Text('Project: $projectName', style: _textStyle(9)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 14),

          // Selected Material Summary Box
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        stone.name,
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey900,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Collection: ${stone.collection} | Code: ${stone.productCode}',
                        style: _textStyle(9.5),
                      ),
                      pw.Text(
                        'Finish: ${stone.finish} | Size: ${stone.size ?? "${stone.length} x ${stone.width}"}',
                        style: _textStyle(9.5),
                      ),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      _currencyFormat.format(stone.pricePerSqFt),
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.brown800,
                      ),
                    ),
                    pw.Text('per sq.ft', style: _textStyle(8.5)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Technical Wall Geometry & Calculations
          pw.Text(
            'WALL DIMENSIONS & MATERIAL ESTIMATE',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
          ),
          pw.SizedBox(height: 8),

          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Parameter', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Imperial (Feet)', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Metric', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Wall Width', style: _textStyle(9))),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${wallWidthFt.toStringAsFixed(2)} ft', style: _textStyle(9))),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${(wallWidthFt / 3.28084).toStringAsFixed(2)} m', style: _textStyle(9))),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Wall Height', style: _textStyle(9))),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${wallHeightFt.toStringAsFixed(2)} ft', style: _textStyle(9))),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${(wallHeightFt / 3.28084).toStringAsFixed(2)} m', style: _textStyle(9))),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Net Surface Area', style: _textStyle(9))),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${netAreaSqFt.toStringAsFixed(2)} sq.ft', style: _textStyle(9))),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${(netAreaSqFt / 10.764).toStringAsFixed(2)} sq.m', style: _textStyle(9))),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Wastage & Cut Factor', style: _textStyle(9))),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${wastagePercent.toInt()}%', style: _textStyle(9))),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${wastagePercent.toInt()}%', style: _textStyle(9))),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text('Gross Billable Area', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text('${grossAreaSqFt.toStringAsFixed(2)} sq.ft', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.brown800)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text('${(grossAreaSqFt / 10.764).toStringAsFixed(2)} sq.m', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text('Box Coverage / Packaging', style: _textStyle(9)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text('${stone.sqftPerBox.toStringAsFixed(2)} sq.ft/box (${stone.piecesPerBox} pcs)', style: _textStyle(9)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text('${(stone.sqftPerBox / 10.764).toStringAsFixed(2)} sq.m/box', style: _textStyle(9)),
                  ),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text('Total Boxes Required', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text('$boxesRequired Boxes', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text('~$totalTiles Individual Tiles', style: _textStyle(9)),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 20),

          // Financial Estimation Summary
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 250,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Column(
                children: [
                  _buildTotalRow('Material Subtotal:', _currencyFormat.format(subtotal)),
                  _buildTotalRow('GST (18%):', _currencyFormat.format(gst)),
                  pw.Divider(color: PdfColors.grey300),
                  _buildTotalRow('Est. Total (Excl. Freight):', _currencyFormat.format(grandTotal), isBold: true, fontSize: 11),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 20),

          // Architectural Notes & Installation Guidelines
          pw.Text(
            'INSTALLATION & GROUT SPECIFICATIONS',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
          ),
          pw.SizedBox(height: 6),
          _buildBulletPoint('Recommended Grout Line: 2mm to 4mm with epoxy or polymer-modified cementitious grout.'),
          _buildBulletPoint('Surface Preparation: Substrate must be clean, dry, level, and structurally sound.'),
          _buildBulletPoint('Natural Variation: Natural stones and artisanal finishes have authentic color and texture variance; blend tiles from multiple boxes during dry-laying.'),
          _buildBulletPoint('Sealant: Apply high-penetration hydrophobic impregnating sealer post-grouting for stain protection.'),
        ],
        footer: (context) => _buildFooter(context.pageNumber, context.pagesCount),
      ),
    );

    return pdf.save();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PDF COMPONENTS - QUOTE
  // ═══════════════════════════════════════════════════════════════════════════

  pw.Widget _buildQuoteHeader(
    pw.MemoryImage logo,
    String quoteId,
    DateTime quoteDate,
    DateTime? validUntil,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Company Logo & Info
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Image(logo, width: 120, height: 40),
            pw.SizedBox(height: 10),
            pw.Text(
              'GRAZIA STONES',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Premium Natural Stones & Marble',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 8),
            pw.Text('Email: info@graziastones.com', style: _textStyle(10)),
            pw.Text('Phone: +91 98765 43210', style: _textStyle(10)),
            pw.Text('GSTIN: 29AABCU9603R1ZV', style: _textStyle(10)),
          ],
        ),

        // Quote Info
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'QUOTATION',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue800,
              ),
            ),
            pw.SizedBox(height: 10),
            _buildInfoRow('Quote No:', quoteId),
            _buildInfoRow('Date:', _dateFormat.format(quoteDate)),
            if (validUntil != null)
              _buildInfoRow('Valid Until:', _dateFormat.format(validUntil)),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildCustomerInfo(
    String name,
    String email,
    String phone,
    String? address,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'BILL TO',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(name, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.Text(email, style: _textStyle(10)),
          pw.Text(phone, style: _textStyle(10)),
          if (address != null && address.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(address, style: _textStyle(10)),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildItemsTable(List<QuoteLineItem> items) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1.5),
        4: const pw.FlexColumnWidth(2),
      },
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue50),
          children: [
            _buildTableCell('Product', isHeader: true),
            _buildTableCell('Specifications', isHeader: true),
            _buildTableCell('Quantity', isHeader: true, align: pw.TextAlign.center),
            _buildTableCell('Rate/sq.ft', isHeader: true, align: pw.TextAlign.right),
            _buildTableCell('Amount', isHeader: true, align: pw.TextAlign.right),
          ],
        ),
        // Items
        ...items.map((item) => pw.TableRow(
          children: [
            _buildTableCell(item.productName),
            _buildTableCell('${item.finish}\n${item.color}'),
            _buildTableCell('${item.quantity} sq.ft', align: pw.TextAlign.center),
            _buildTableCell(_currencyFormat.format(item.pricePerSqFt), align: pw.TextAlign.right),
            _buildTableCell(_currencyFormat.format(item.total), align: pw.TextAlign.right),
          ],
        )),
      ],
    );
  }

  pw.Widget _buildTotalsSummary(
    double subtotal,
    double gst,
    double shipping,
    double grandTotal,
  ) {
    return pw.Container(
      width: 250,
      alignment: pw.Alignment.centerRight,
      child: pw.Column(
        children: [
          _buildTotalRow('Subtotal:', _currencyFormat.format(subtotal)),
          _buildTotalRow('GST (18%):', _currencyFormat.format(gst)),
          _buildTotalRow('Shipping:', _currencyFormat.format(shipping)),
          pw.Divider(thickness: 1.5),
          _buildTotalRow(
            'Grand Total:',
            _currencyFormat.format(grandTotal),
            isBold: true,
            fontSize: 14,
          ),
        ],
      ),
    );
  }

  pw.Widget _buildNotes(String notes) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.yellow50,
        border: pw.Border.all(color: PdfColors.yellow200),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'NOTES',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(notes, style: _textStyle(10)),
        ],
      ),
    );
  }

  pw.Widget _buildTermsAndConditions() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'TERMS & CONDITIONS',
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey800,
          ),
        ),
        pw.SizedBox(height: 8),
        _buildBulletPoint('Prices are subject to change without prior notice'),
        _buildBulletPoint('Delivery charges applicable as per actual'),
        _buildBulletPoint('GST as applicable will be charged extra'),
        _buildBulletPoint('Payment terms: 50% advance, balance before delivery'),
        _buildBulletPoint('Quotation valid for 30 days from date of issue'),
        _buildBulletPoint('Natural stone variations in color and pattern are inherent'),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PDF COMPONENTS - ORDER
  // ═══════════════════════════════════════════════════════════════════════════

  pw.Widget _buildOrderHeader(
    pw.MemoryImage logo,
    String orderId,
    DateTime orderDate,
    String orderStatus,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Company Logo & Info
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Image(logo, width: 120, height: 40),
            pw.SizedBox(height: 10),
            pw.Text(
              'GRAZIA STONES',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Premium Natural Stones & Marble',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          ],
        ),

        // Order Info
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'ORDER CONFIRMATION',
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green800,
              ),
            ),
            pw.SizedBox(height: 10),
            _buildInfoRow('Order No:', orderId),
            _buildInfoRow('Date:', _dateFormat.format(orderDate)),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: pw.BoxDecoration(
                color: _getOrderStatusColor(orderStatus),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Text(
                orderStatus.toUpperCase(),
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildOrderCustomerInfo(
    String name,
    String email,
    String phone,
    String address,
    DateTime? estimatedDelivery,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(15),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'CUSTOMER DETAILS',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey800,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(name, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.Text(email, style: _textStyle(10)),
                pw.Text(phone, style: _textStyle(10)),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 15),
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(15),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'DELIVERY ADDRESS',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey800,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(address, style: _textStyle(10)),
                if (estimatedDelivery != null) ...[
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Est. Delivery: ${_dateFormat.format(estimatedDelivery)}',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildOrderItemsTable(List<OrderLineItem> items) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1.5),
        4: const pw.FlexColumnWidth(2),
      },
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.green50),
          children: [
            _buildTableCell('Product', isHeader: true),
            _buildTableCell('Specifications', isHeader: true),
            _buildTableCell('Quantity', isHeader: true, align: pw.TextAlign.center),
            _buildTableCell('Rate/sq.ft', isHeader: true, align: pw.TextAlign.right),
            _buildTableCell('Amount', isHeader: true, align: pw.TextAlign.right),
          ],
        ),
        // Items
        ...items.map((item) => pw.TableRow(
          children: [
            _buildTableCell(item.productName),
            _buildTableCell('${item.finish}\n${item.color}'),
            _buildTableCell('${item.quantity} sq.ft', align: pw.TextAlign.center),
            _buildTableCell(_currencyFormat.format(item.pricePerSqFt), align: pw.TextAlign.right),
            _buildTableCell(_currencyFormat.format(item.total), align: pw.TextAlign.right),
          ],
        )),
      ],
    );
  }

  pw.Widget _buildOrderTotalsSummary(
    double subtotal,
    double gst,
    double shipping,
    double discount,
    double grandTotal,
  ) {
    return pw.Container(
      width: 250,
      alignment: pw.Alignment.centerRight,
      child: pw.Column(
        children: [
          _buildTotalRow('Subtotal:', _currencyFormat.format(subtotal)),
          if (discount > 0) _buildTotalRow('Discount:', '-${_currencyFormat.format(discount)}'),
          _buildTotalRow('GST (18%):', _currencyFormat.format(gst)),
          _buildTotalRow('Shipping:', _currencyFormat.format(shipping)),
          pw.Divider(thickness: 1.5),
          _buildTotalRow(
            'Grand Total:',
            _currencyFormat.format(grandTotal),
            isBold: true,
            fontSize: 14,
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPaymentInfo(String method, String status) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        border: pw.Border.all(color: PdfColors.blue200),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'PAYMENT INFORMATION',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              pw.Text('Method: $method', style: _textStyle(10)),
            ],
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: pw.BoxDecoration(
              color: _getPaymentStatusColor(status),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Text(
              status.toUpperCase(),
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildOrderTermsAndConditions() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'TERMS & CONDITIONS',
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey800,
          ),
        ),
        pw.SizedBox(height: 8),
        _buildBulletPoint('This is a computer-generated invoice'),
        _buildBulletPoint('All disputes subject to local jurisdiction'),
        _buildBulletPoint('Goods once sold cannot be returned or exchanged'),
        _buildBulletPoint('Installation charges extra if applicable'),
        _buildBulletPoint('Please inspect goods at the time of delivery'),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COMMON COMPONENTS
  // ═══════════════════════════════════════════════════════════════════════════

  pw.Widget _buildFooter(int pageNumber, int totalPages) {
    return pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.only(top: 20),
      child: pw.Column(
        children: [
          pw.Divider(),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Thank you for choosing Grazia Stones!',
                style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
              ),
              pw.Text(
                'Page $pageNumber of $totalPages',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(width: 8),
          pw.Text(value, style: _textStyle(10)),
        ],
      ),
    );
  }

  pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 11 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.grey800 : PdfColors.grey700,
        ),
        textAlign: align,
      ),
    );
  }

  pw.Widget _buildTotalRow(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 11,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildBulletPoint(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('• ', style: _textStyle(10)),
          pw.Expanded(child: pw.Text(text, style: _textStyle(10))),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UTILITIES
  // ═══════════════════════════════════════════════════════════════════════════

  pw.TextStyle _textStyle(double fontSize) {
    return pw.TextStyle(fontSize: fontSize, color: PdfColors.grey700);
  }

  PdfColor _getOrderStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return PdfColors.orange;
      case 'confirmed':
        return PdfColors.blue;
      case 'processing':
        return PdfColors.indigo;
      case 'shipped':
        return PdfColors.purple;
      case 'delivered':
        return PdfColors.green;
      case 'cancelled':
        return PdfColors.red;
      default:
        return PdfColors.grey;
    }
  }

  PdfColor _getPaymentStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return PdfColors.green;
      case 'pending':
        return PdfColors.orange;
      case 'failed':
        return PdfColors.red;
      default:
        return PdfColors.grey;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DATA MODELS
// ═══════════════════════════════════════════════════════════════════════════

/// Line item for quote PDF
class QuoteLineItem {
  final String productName;
  final String finish;
  final String color;
  final double quantity;
  final double pricePerSqFt;
  final double total;

  const QuoteLineItem({
    required this.productName,
    required this.finish,
    required this.color,
    required this.quantity,
    required this.pricePerSqFt,
    required this.total,
  });
}

/// Line item for order PDF
class OrderLineItem {
  final String productName;
  final String finish;
  final String color;
  final double quantity;
  final double pricePerSqFt;
  final double total;

  const OrderLineItem({
    required this.productName,
    required this.finish,
    required this.color,
    required this.quantity,
    required this.pricePerSqFt,
    required this.total,
  });
}
