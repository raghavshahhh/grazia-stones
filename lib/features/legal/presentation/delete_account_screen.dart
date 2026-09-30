import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Public page (no sign-in needed) that explains how to delete a Grazia Stones
/// account. Google Play requires apps that create accounts to publish a web URL
/// for this: https://grazia-stones.vercel.app/delete-account
class DeleteAccountScreen extends ConsumerWidget {
  const DeleteAccountScreen({super.key});

  static const _email = 'hello@graziastones.com';
  static const _helplineDisplay = '+91 98398 46105';
  static const _helplineDigits = '919839846105';

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(themePaletteProvider);
    final subject = Uri.encodeComponent('Delete my Grazia Stones account');
    final body = Uri.encodeComponent(
      'Please delete my Grazia Stones account.\n\n'
      'Registered phone number / email: \n'
      'Also remove my quote / sample enquiries: Yes / No',
    );
    final whatsappText = Uri.encodeComponent(
      'Hello Grazia Stones, please delete my account. My registered phone number / email is: ',
    );

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          // This page is usually opened straight from a link, so there may be
          // nothing to pop back to.
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: palette.textPrimary, size: 18),
        ),
        title: Text(
          'Delete Account',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delete your Grazia Stones account',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Grazia Stones app · developer: Grazia Stones (Unit of BNK Stones), Kanpur, India. '
                  'You can delete your account and its data yourself, or ask us to do it.',
                  style: GoogleFonts.inter(fontSize: 13, color: palette.textSecondary, height: 1.55),
                ),
                const SizedBox(height: 18),
                _section(
                  palette,
                  'OPTION 1 — DELETE IN THE APP (INSTANT)',
                  '1. Open the Grazia Stones app and sign in.\n'
                  '2. Go to the Profile tab and scroll to the bottom.\n'
                  '3. Tap "Delete Account" and confirm.\n\n'
                  'Your account is deleted immediately and this cannot be undone.',
                ),
                const SizedBox(height: 14),
                _section(
                  palette,
                  'OPTION 2 — ASK US TO DELETE IT',
                  'Can\'t sign in or no longer have the app? Send us your request from the email '
                  'address or phone number registered on your account. We verify it is you, delete '
                  'the account and reply to confirm.',
                  actions: [
                    _actionButton(
                      palette,
                      icon: Icons.mail_outline_rounded,
                      label: 'Email $_email',
                      onTap: () => _open('mailto:$_email?subject=$subject&body=$body'),
                    ),
                    _actionButton(
                      palette,
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'WhatsApp $_helplineDisplay',
                      onTap: () => _open('https://wa.me/$_helplineDigits?text=$whatsappText'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _section(
                  palette,
                  'WHAT IS DELETED',
                  '• Your profile (name, phone, email, company)\n'
                  '• Your sign-in credentials\n'
                  '• Wishlist, cart, saved designs and saved addresses',
                ),
                const SizedBox(height: 14),
                _section(
                  palette,
                  'WHAT MAY BE KEPT',
                  '• Quote and sample enquiries you submitted. They are disconnected from your account '
                  'but still contain the contact details you typed in, so our team can follow up. '
                  'Ask us in your request and we will remove them too.\n'
                  '• AI Studio room photos and results may remain in storage until removed. '
                  'Ask us in your request to have them erased.\n'
                  '• Order records, if any exist, kept only as required for accounting and tax purposes.',
                ),
                const SizedBox(height: 14),
                _section(
                  palette,
                  'CONTACT',
                  'Grazia Stones Grievance Desk\n'
                  '123/477, Kalpi Road, Fazalganj, Kanpur, UP - 208012\n'
                  'Email: $_email\n'
                  'Helpline: +91 9839846105',
                  actions: [
                    TextButton(
                      onPressed: () => context.push('/privacy'),
                      child: Text(
                        'Read our Privacy Policy',
                        style: GoogleFonts.inter(color: palette.primary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionButton(
    LuxuryPalette palette, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: palette.primary),
        label: Text(label, style: GoogleFonts.inter(color: palette.textPrimary, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: palette.primary.withValues(alpha: 0.6)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _section(LuxuryPalette palette, String title, String content, {List<Widget> actions = const []}) {
    return Container(
      width: double.infinity,
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
            style: GoogleFonts.inter(fontSize: 13, color: palette.textSecondary, height: 1.55),
          ),
          for (final a in actions) ...[const SizedBox(height: 10), a],
        ],
      ),
    );
  }
}
