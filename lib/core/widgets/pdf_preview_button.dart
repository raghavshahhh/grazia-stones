import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import 'package:grazia_stones/shared/theme/colors.dart';

/// Widget for previewing and downloading PDF documents
class PDFPreviewButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Future<Uint8List> Function() onGeneratePdf;
  final LuxuryPalette palette;
  final bool isPrimary;

  const PDFPreviewButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onGeneratePdf,
    required this.palette,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isPrimary) {
      return ElevatedButton.icon(
        onPressed: () => _showPDFPreview(context),
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: () => _showPDFPreview(context),
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.primary,
        side: BorderSide(color: palette.primary),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Future<void> _showPDFPreview(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          body: PdfPreview(
            build: (format) => onGeneratePdf(),
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
            allowPrinting: true,
            allowSharing: true,
            pdfFileName: '${label.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf',
          ),
        ),
      ),
    );
  }
}

/// Compact PDF download button
class PDFDownloadButton extends StatefulWidget {
  final String fileName;
  final Future<Uint8List> Function() onGeneratePdf;
  final LuxuryPalette palette;
  final VoidCallback? onDownloadComplete;

  const PDFDownloadButton({
    super.key,
    required this.fileName,
    required this.onGeneratePdf,
    required this.palette,
    this.onDownloadComplete,
  });

  @override
  State<PDFDownloadButton> createState() => _PDFDownloadButtonState();
}

class _PDFDownloadButtonState extends State<PDFDownloadButton> {
  bool _isDownloading = false;

  Future<void> _downloadPDF() async {
    setState(() => _isDownloading = true);

    try {
      final pdfData = await widget.onGeneratePdf();
      await Printing.sharePdf(
        bytes: pdfData,
        filename: '${widget.fileName}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      
      if (mounted) {
        widget.onDownloadComplete?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'PDF downloaded successfully',
              style: GoogleFonts.inter(fontSize: 13),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to download PDF: $e',
              style: GoogleFonts.inter(fontSize: 13),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: _isDownloading ? null : _downloadPDF,
      icon: _isDownloading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.download_rounded),
      tooltip: 'Download PDF',
    );
  }
}
