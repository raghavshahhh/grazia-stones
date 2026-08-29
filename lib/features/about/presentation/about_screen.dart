import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/shared/widgets/grazia_logo.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

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
          'About Grazia Stones',
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
            // Hero Brand Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: palette.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const GraziaLogo(
                    variant: GraziaLogoVariant.full,
                    height: 84,
                    enableGlow: true,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: palette.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'EST. ARCHITECTURAL EXCELLENCE',
                      style: GoogleFonts.inter(
                        color: palette.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Crafting Earth\'s Finest Natural Stones For Modern Architecture',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'From Italian marble quarries to precision-manufactured cultured stone cladding, Grazia Stones bridges timeless geological beauty with AI spatial technology.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: palette.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Section 1: The Grazia Heritage & Vision
            _buildSectionHeader('OUR HERITAGE & PHILOSOPHY', palette),
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
                    'Pioneering Stone Innovation in India',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Headquartered in Kanpur, Uttar Pradesh, Grazia Stones is a leading architectural stone brand and manufacturer. We curate and craft rare natural marble, granite, quartzite, onyx, and specialized cultured stone cladding for luxury residences, hotels, commercial complexes, and modern estates across India.',
                    style: GoogleFonts.inter(fontSize: 13, color: palette.textSecondary, height: 1.55),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Every slab undergoes multi-stage diamond calibration, zero-crack resin reinforcement, and architectural quality inspection before reaching your job site.',
                    style: GoogleFonts.inter(fontSize: 13, color: palette.textSecondary, height: 1.55),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Section 2: Core Pillars
            _buildSectionHeader('THE FOUR PILLARS OF GRAZIA', palette),
            const SizedBox(height: 12),
            _buildPillarCard(
              palette,
              icon: Icons.diamond_outlined,
              title: 'Master Quarry Sourcing',
              description: 'Direct procurement from authentic quarries across Italy, Greece, Turkey, and Rajasthan.',
            ),
            const SizedBox(height: 10),
            _buildPillarCard(
              palette,
              icon: Icons.precision_manufacturing_outlined,
              title: 'High-Precision Fabrication',
              description: 'State-of-the-art CNC wire cutting, book-match calibration, and custom slab sizing.',
            ),
            const SizedBox(height: 10),
            _buildPillarCard(
              palette,
              icon: Icons.auto_awesome_outlined,
              title: 'AI Room Visualizer & AR Estimation',
              description: 'Real-time augmented reality spatial projection allowing architects to preview textures before ordering.',
            ),
            const SizedBox(height: 10),
            _buildPillarCard(
              palette,
              icon: Icons.local_shipping_outlined,
              title: 'Zero-Breakage Transit & Delivery',
              description: 'Reinforced wooden crate packaging, containerized freight, and on-site crane offloading assistance.',
            ),

            const SizedBox(height: 28),

            // Section 3: Headquarters & Experience Center
            _buildSectionHeader('HEADQUARTERS & EXPERIENCE CENTER', palette),
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: palette.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.business_rounded, color: palette.primary, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Grazia Stones Flagship Showroom',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: palette.textPrimary,
                              ),
                            ),
                            Text(
                              'Kanpur, Uttar Pradesh, India',
                              style: GoogleFonts.inter(fontSize: 12, color: palette.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildContactRow(
                    palette,
                    Icons.location_on_outlined,
                    'Address',
                    '123/477, Kalpi Road, Fazalganj, Kanpur, UP - 208012',
                    onTap: () => _launchUrl('https://maps.google.com/?q=Fazalganj+Kanpur+123/477+Kalpi+Road'),
                  ),
                  const Divider(height: 20),
                  _buildContactRow(
                    palette,
                    Icons.phone_outlined,
                    'Sales & Technical Helpline',
                    '+91 9839846105 / +91 7518102550',
                    onTap: () => _launchUrl('tel:+919839846105'),
                  ),
                  const Divider(height: 20),
                  _buildContactRow(
                    palette,
                    Icons.email_outlined,
                    'Official Correspondence',
                    'hello@graziastones.com / info@graziastones.com',
                    onTap: () => _launchUrl('mailto:hello@graziastones.com'),
                  ),
                  const Divider(height: 20),
                  _buildContactRow(
                    palette,
                    Icons.access_time_rounded,
                    'Studio Hours',
                    'Monday – Saturday: 9:30 AM – 7:30 PM (Sunday Closed)',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Quick CTAs
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _launchUrl('tel:+919839846105'),
                    icon: const Icon(Icons.call, size: 16),
                    label: const Text('Call Showroom'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/dealers'),
                    icon: const Icon(Icons.storefront_outlined, size: 16),
                    label: const Text('Find Dealers'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.primary,
                      side: BorderSide(color: palette.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
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

  Widget _buildPillarCard(
    LuxuryPalette palette, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: palette.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: palette.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: palette.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow(
    LuxuryPalette palette,
    IconData icon,
    String title,
    String value, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: palette.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: palette.textTertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: onTap != null ? palette.primary : palette.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.arrow_forward_ios_rounded, size: 12, color: palette.textTertiary),
          ],
        ),
      ),
    );
  }
}
