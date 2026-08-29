import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';

class HelpSupportScreen extends ConsumerStatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  ConsumerState<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends ConsumerState<HelpSupportScreen> {
  final _queryController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _submitQuery() async {
    final text = _queryController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please describe your inquiry or project requirement', style: GoogleFonts.inter()),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    await Future.delayed(const Duration(milliseconds: 700));

    if (mounted) {
      setState(() {
        _isSubmitting = false;
        _queryController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Inquiry submitted! Our technical concierge will contact you shortly.', style: GoogleFonts.inter()),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: palette.textPrimary, size: 18),
        ),
        title: Text(
          'Help & Concierge Support',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
      ),

      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick Connect Hub
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: palette.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: palette.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.headset_mic_rounded, color: palette.primary, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Architect Technical Desk',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: palette.textPrimary,
                              ),
                            ),
                            Text(
                              'Direct assistance with stone selection, dry-lay & logistics',
                              style: GoogleFonts.inter(fontSize: 11, color: palette.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionBtn(
                          palette,
                          icon: Icons.phone_in_talk_rounded,
                          label: 'Call Us',
                          onTap: () => _launchUrl('tel:+919839846105'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildActionBtn(
                          palette,
                          icon: Icons.chat_bubble_outline_rounded,
                          label: 'WhatsApp',
                          onTap: () => _launchUrl('https://wa.me/919839846105?text=Hello%20Grazia%20Stones%20Team%2C%20I%20need%20assistance%20with%20stone%20selection.'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildActionBtn(
                          palette,
                          icon: Icons.mail_outline_rounded,
                          label: 'Email',
                          onTap: () => _launchUrl('mailto:hello@graziastones.com'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Section 2: Frequently Asked Questions
            _buildSectionHeader('FREQUENTLY ASKED QUESTIONS', palette),
            const SizedBox(height: 12),
            _buildFaqItem(
              palette,
              question: 'How do I order physical stone sample swatches?',
              answer: 'You can tap "Order Material Sample Box" from any stone detail page or via the Profile menu. We deliver curated 4"x4" physical stone swatches directly to your architectural office within 3-5 business days across India.',
            ),
            const SizedBox(height: 10),
            _buildFaqItem(
              palette,
              question: 'How accurate is the AI Studio room visualizer?',
              answer: 'Our AI Studio uses high-resolution photographic texture maps with simulated architectural daylight, ambient evening, and spotlight illumination to reflect realistic stone surface behavior.',
            ),
            const SizedBox(height: 10),
            _buildFaqItem(
              palette,
              question: 'What are the payment options and GST benefits?',
              answer: 'We support 100% secure online transactions via Razorpay (UPI, NetBanking, Corporate Cards) and verified Cash on Delivery/Site Verification for standard orders. All commercial invoices are issued with 18% GST input credit.',
            ),
            const SizedBox(height: 10),
            _buildFaqItem(
              palette,
              question: 'How are stone slabs packaged for transport?',
              answer: 'All marble, granite, and cultured stone shipments are crated inside reinforced wooden A-frames with corner edge protectors and waterproof wrapping to ensure zero-breakage transit.',
            ),

            const SizedBox(height: 28),

            // Section 3: Send a Direct Query
            _buildSectionHeader('SEND AN INQUIRY TO GRAZIA CONCIERGE', palette),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Need custom sizing or project consultation?',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Provide your site location and stone requirements below.',
                    style: GoogleFonts.inter(fontSize: 12, color: palette.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _queryController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'e.g. Requirement for 2,500 sq.ft Statuario White marble for villa in Lucknow...',
                      hintStyle: GoogleFonts.inter(fontSize: 12, color: palette.textTertiary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: palette.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: palette.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: palette.primary, width: 1.5),
                      ),
                      filled: true,
                      fillColor: palette.background,
                      contentPadding: const EdgeInsets.all(14),
                    ),
                    style: GoogleFonts.inter(fontSize: 13, color: palette.textPrimary),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitQuery,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text('Send to Concierge', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, LuxuryPalette palette) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 11,
        color: palette.textTertiary,
        letterSpacing: 1.6,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildActionBtn(
    LuxuryPalette palette, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: palette.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            children: [
              Icon(icon, color: palette.primary, size: 20),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFaqItem(
    LuxuryPalette palette, {
    required String question,
    required String answer,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        iconColor: palette.primary,
        collapsedIconColor: palette.textTertiary,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          question,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: palette.textPrimary,
          ),
        ),
        children: [
          Text(
            answer,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: palette.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

