import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';

class PrivacyPolicyScreen extends ConsumerWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(themePaletteProvider);

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
          'Privacy Policy',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.privacy_tip_outlined, color: palette.primary, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Privacy & Data Protection',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Last Updated: August 2026 • Grazia Stones Private Limited',
                    style: GoogleFonts.inter(fontSize: 11, color: palette.textTertiary),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Grazia Stones is committed to safeguarding your privacy and personal data. This policy describes how we collect, process, and protect your information across our mobile and web applications in compliance with the Information Technology Act, 2000 and the Digital Personal Data Protection Act, 2023.',
                    style: GoogleFonts.inter(fontSize: 12, color: palette.textSecondary, height: 1.5),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _buildSection(
              palette,
              '1. INFORMATION WE COLLECT',
              '• Account Information: Name, phone number, email address, company/firm name, and architect credentials.\n'
              '• Site & Delivery Data: Delivery address, site contact person details, and pin code for freight logistics.\n'
              '• Architectural Project Data: Room photographs uploaded to the AI Visualizer, selected stone materials, custom dimensions, and saved spatial concepts.\n'
              '• Device & Diagnostic Data: Device model, operating system, IP address, crash logs, and app performance metrics.',
            ),

            const SizedBox(height: 18),

            _buildSection(
              palette,
              '2. CAMERA & SPATIAL AR PERMISSIONS',
              '• Camera access is used exclusively for Live AR surface detection and uploading room photos into the AI Studio Visualizer.\n'
              '• Grazia Stones does NOT record private background video or transmit continuous camera feeds to external cloud servers.\n'
              '• AR surface tracking coordinates are computed in real time on your local device.',
            ),

            const SizedBox(height: 18),

            _buildSection(
              palette,
              '3. HOW WE USE YOUR DATA',
              '• Order & Sample Fulfillment: Dispatching physical material sample boxes and scheduling freight trucks to construction sites.\n'
              '• Certified Quotations: Generating itemized PDF quotations including GST and transit insurance.\n'
              '• AI Visualization: Rendering stone textures on uploaded room photographs.\n'
              '• Customer Concierge: Providing technical consultation, slab availability updates, and warranty support.',
            ),

            const SizedBox(height: 18),

            _buildSection(
              palette,
              '4. PAYMENT SECURITY & ENCRYPTION',
              '• Online transactions are securely processed through PCI-DSS Level 1 compliant payment gateways (Razorpay).\n'
              '• Grazia Stones does not store or process complete credit/debit card numbers, CVVs, or NetBanking credentials on internal servers.\n'
              '• All communication between your device and our database is protected using 256-bit TLS/SSL encryption.',
            ),

            const SizedBox(height: 18),

            _buildSection(
              palette,
              '5. DATA STORAGE & RETENTION',
              '• Your profile and saved designs are securely stored in Supabase PostgreSQL databases with Row-Level Security (RLS) policies.\n'
              '• You may request permanent deletion of your account and saved designs at any time via Settings or by contacting hello@graziastones.com.',
            ),

            const SizedBox(height: 18),

            _buildSection(
              palette,
              '6. GRIEVANCE OFFICER & CONTACT',
              'For privacy inquiries or data access requests, contact our designated Grievance Officer:\n\n'
              'Grazia Stones Grievance Desk\n'
              '123/477, Kalpi Road, Fazalganj, Kanpur, UP - 208012\n'
              'Email: privacy@graziastones.com / hello@graziastones.com\n'
              'Helpline: +91 9839846105',
            ),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(LuxuryPalette palette, String title, String content) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: palette.primary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: palette.textSecondary,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
