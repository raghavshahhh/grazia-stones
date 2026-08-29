import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service for sharing documents via various platforms
/// 
/// Provides methods to share PDFs via:
/// - Native share sheet (email, WhatsApp, etc.)
/// - Direct WhatsApp sharing
/// - Direct email with attachments
/// - Save to device
class ShareService {
  static ShareService? _instance;
  static ShareService get instance => _instance ??= ShareService._();

  ShareService._();

  // ═══════════════════════════════════════════════════════════════════════════
  // PDF SHARING
  // ═══════════════════════════════════════════════════════════════════════════

  /// Share PDF via native share sheet
  /// 
  /// Opens system share sheet with options for:
  /// - Email apps
  /// - WhatsApp
  /// - Telegram
  /// - Other messaging apps
  /// - Cloud storage (Drive, Dropbox, etc.)
  Future<void> sharePDF({
    required Uint8List pdfData,
    required String fileName,
    String? subject,
    String? body,
  }) async {
    try {
      await Printing.sharePdf(
        bytes: pdfData,
        filename: fileName,
        subject: subject,
        body: body,
      );
    } catch (e) {
      debugPrint('❌ Error sharing PDF: $e');
      rethrow;
    }
  }

  /// Share PDF directly via WhatsApp
  /// 
  /// Saves PDF temporarily and opens WhatsApp with the file
  Future<void> sharePDFViaWhatsApp({
    required Uint8List pdfData,
    required String fileName,
    String? phoneNumber,
    String? message,
  }) async {
    try {
      // Save PDF to temporary directory
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pdfData);

      // Build WhatsApp URL
      String whatsappUrl;
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        // Remove any non-digit characters
        final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
        whatsappUrl = 'whatsapp://send?phone=$cleanNumber';
      } else {
        whatsappUrl = 'whatsapp://send';
      }

      if (message != null && message.isNotEmpty) {
        whatsappUrl += '&text=${Uri.encodeComponent(message)}';
      }

      // Try to open WhatsApp
      final uri = Uri.parse(whatsappUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        
        // After WhatsApp opens, share the file using native share
        // (WhatsApp will be in the list)
        await Future.delayed(const Duration(milliseconds: 500));
        await Share.shareXFiles(
          [XFile(file.path)],
          text: message,
        );
      } else {
        // Fallback to regular share if WhatsApp is not installed
        await Share.shareXFiles(
          [XFile(file.path)],
          text: message ?? 'Sharing PDF document',
        );
      }
    } catch (e) {
      debugPrint('❌ Error sharing via WhatsApp: $e');
      rethrow;
    }
  }

  /// Share PDF via email with attachment
  /// 
  /// Opens email client with PDF attached
  Future<void> sharePDFViaEmail({
    required Uint8List pdfData,
    required String fileName,
    String? toEmail,
    String? subject,
    String? body,
  }) async {
    try {
      // Save PDF to temporary directory
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pdfData);

      // Build mailto URL
      String mailto = 'mailto:';
      
      if (toEmail != null && toEmail.isNotEmpty) {
        mailto += toEmail;
      }

      final params = <String, String>{};
      if (subject != null && subject.isNotEmpty) {
        params['subject'] = subject;
      }
      if (body != null && body.isNotEmpty) {
        params['body'] = body;
      }

      if (params.isNotEmpty) {
        mailto += '?';
        mailto += params.entries
            .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
            .join('&');
      }

      // Try to open email client
      final uri = Uri.parse(mailto);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        
        // After email client opens, share the file
        await Future.delayed(const Duration(milliseconds: 500));
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: subject,
          text: body,
        );
      } else {
        // Fallback to regular share if email client is not available
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: subject,
          text: body ?? 'Sharing PDF document',
        );
      }
    } catch (e) {
      debugPrint('❌ Error sharing via email: $e');
      rethrow;
    }
  }

  /// Save PDF to device
  /// 
  /// Saves PDF to Downloads folder (Android) or Documents folder (iOS)
  Future<String> savePDFToDevice({
    required Uint8List pdfData,
    required String fileName,
  }) async {
    try {
      Directory? directory;
      
      if (Platform.isAndroid) {
        // Android: Save to Downloads
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          // Fallback to external storage
          directory = await getExternalStorageDirectory();
        }
      } else if (Platform.isIOS) {
        // iOS: Save to Documents directory
        directory = await getApplicationDocumentsDirectory();
      } else {
        // Other platforms: use temporary directory
        directory = await getTemporaryDirectory();
      }

      if (directory == null) {
        throw Exception('Could not access storage directory');
      }

      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(pdfData);
      
      debugPrint('✅ PDF saved to: ${file.path}');
      return file.path;
    } catch (e) {
      debugPrint('❌ Error saving PDF: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SHARE OPTIONS DIALOG
  // ═══════════════════════════════════════════════════════════════════════════

  /// Show share options dialog
  /// 
  /// Displays a bottom sheet with share options:
  /// - Share via apps (native sheet)
  /// - WhatsApp
  /// - Email
  /// - Save to device
  Future<void> showShareOptions({
    required BuildContext context,
    required Uint8List pdfData,
    required String fileName,
    String? phoneNumber,
    String? email,
    String? subject,
    String? body,
    Color? primaryColor,
  }) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ShareOptionsSheet(
        pdfData: pdfData,
        fileName: fileName,
        phoneNumber: phoneNumber,
        email: email,
        subject: subject,
        body: body,
        primaryColor: primaryColor,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SHARE OPTIONS SHEET
// ═══════════════════════════════════════════════════════════════════════════

class ShareOptionsSheet extends StatelessWidget {
  final Uint8List pdfData;
  final String fileName;
  final String? phoneNumber;
  final String? email;
  final String? subject;
  final String? body;
  final Color? primaryColor;

  const ShareOptionsSheet({
    super.key,
    required this.pdfData,
    required this.fileName,
    this.phoneNumber,
    this.email,
    this.subject,
    this.body,
    this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = primaryColor ?? Theme.of(context).colorScheme.primary;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            'Share Document',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // Share options
          _ShareOption(
            icon: Icons.share_rounded,
            label: 'Share via...',
            subtitle: 'Choose from available apps',
            color: color,
            onTap: () async {
              Navigator.pop(context);
              await ShareService.instance.sharePDF(
                pdfData: pdfData,
                fileName: fileName,
                subject: subject,
                body: body,
              );
            },
          ),

          _ShareOption(
            icon: Icons.chat_rounded,
            label: 'WhatsApp',
            subtitle: 'Share via WhatsApp',
            color: const Color(0xFF25D366),
            onTap: () async {
              Navigator.pop(context);
              await ShareService.instance.sharePDFViaWhatsApp(
                pdfData: pdfData,
                fileName: fileName,
                phoneNumber: phoneNumber,
                message: body,
              );
            },
          ),

          _ShareOption(
            icon: Icons.email_rounded,
            label: 'Email',
            subtitle: 'Send via email',
            color: Colors.blue,
            onTap: () async {
              Navigator.pop(context);
              await ShareService.instance.sharePDFViaEmail(
                pdfData: pdfData,
                fileName: fileName,
                toEmail: email,
                subject: subject,
                body: body,
              );
            },
          ),

          _ShareOption(
            icon: Icons.download_rounded,
            label: 'Save to Device',
            subtitle: 'Save PDF to Downloads',
            color: Colors.green,
            onTap: () async {
              try {
                final path = await ShareService.instance.savePDFToDevice(
                  pdfData: pdfData,
                  fileName: fileName,
                );
                
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('PDF saved to device'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to save PDF: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ShareOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
