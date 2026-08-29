import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';

class TermsOfServiceScreen extends ConsumerWidget {
  const TermsOfServiceScreen({super.key});

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
          'Terms & Conditions',
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
                      Icon(Icons.description_outlined, color: palette.primary, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Terms of Service & Sale',
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
                    'Effective Date: August 2026 • Grazia Stones Private Limited',
                    style: GoogleFonts.inter(fontSize: 11, color: palette.textTertiary),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'These Terms govern your use of the Grazia Stones application, quotation services, material sample requests, and commercial purchase of natural and cultured architectural stone slabs.',
                    style: GoogleFonts.inter(fontSize: 12, color: palette.textSecondary, height: 1.5),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _buildSection(
              palette,
              '1. NATURAL STONE CHARACTERISTICS & VARIATIONS',
              '• Natural marble, granite, quartzite, and slate are geological products of the Earth. Natural variations in veining, shade, mineral deposits, texture, and fissures are inherent and celebrated hallmarks of natural stone, not manufacturing defects.\n'
              '• While our high-resolution imagery and AR/AI visualizers represent textures with high fidelity, physical sample inspection is recommended before bulk slab cutting.',
            ),

            const SizedBox(height: 18),

            _buildSection(
              palette,
              '2. QUOTATIONS, PRICING & GST',
              '• Quotations generated through the Grazia app or concierge are valid for 15 days from issuance unless specified otherwise.\n'
              '• All commercial slab sales in India attract applicable Goods and Services Tax (GST) at 18% as mandated by statutory guidelines.\n'
              '• Final invoice amounts include product cost, applicable tax, and freight/transit insurance according to the specified delivery pin code.',
            ),

            const SizedBox(height: 18),

            _buildSection(
              palette,
              '3. MATERIAL SAMPLE BOXES',
              '• Material sample boxes provide physical 4"x4" or 6"x6" stone swatches to assist architects and interior designers in finish selection.\n'
              '• Sample shipping fees (if charged) may be credited towards subsequent commercial slab project orders.',
            ),

            const SizedBox(height: 18),

            _buildSection(
              palette,
              '4. LOGISTICS, TRANSIT INSURANCE & OFFLOADING',
              '• All commercial shipments are securely packaged in reinforced wooden A-frames or crates with transit insurance.\n'
              '• The purchaser or site supervisor is responsible for arranging adequate crane or labor offloading facilities at the designated delivery site.',
            ),

            const SizedBox(height: 18),

            _buildSection(
              palette,
              '5. CANCELLATION & RETURN POLICY',
              '• Standard stocked materials may be cancelled prior to warehouse dispatch.\n'
              '• Custom cut-to-size slabs, calibrated book-match pairs, and specialized dry-lay orders cannot be cancelled or returned once precision CNC cutting has commenced.',
            ),

            const SizedBox(height: 18),

            _buildSection(
              palette,
              '6. GOVERNING LAW & JURISDICTION',
              'These Terms and commercial agreements are governed by the laws of India. Any disputes arising in connection with orders shall be subject to the exclusive jurisdiction of the competent courts in Kanpur, Uttar Pradesh.',
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
