import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/features/cart/presentation/cart_screen.dart';
import 'package:grazia_stones/features/profile/presentation/edit_profile_screen.dart';
import 'package:grazia_stones/shared/widgets/grazia_logo.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/features/wishlist/providers/wishlist_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(themePaletteProvider);
    final isDark = ref.watch(themePaletteProvider.notifier).isDarkMode;
    final cartCount = ref.watch(cartProvider).length;

    return Scaffold(
      backgroundColor: palette.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Container(
              color: palette.surface,
              child: Column(
                children: [
                  SizedBox(height: MediaQuery.of(context).padding.top + 16),

                  // Top row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Architect Account',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: palette.textPrimary,
                          ),
                        ),
                        // Theme toggle
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            ref.read(themePaletteProvider.notifier).toggleTheme();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: palette.surfaceDark,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: palette.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                                  size: 15,
                                  color: palette.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isDark ? 'Light' : 'Dark',
                                  style: GoogleFonts.inter(
                                    color: palette.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Profile Card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Builder(
                      builder: (context) {
                        final auth = ref.watch(authRiverpodProvider);
                        final name = auth.userName?.isNotEmpty == true
                            ? auth.userName!
                            : (auth.isLoggedIn ? 'Architect User' : 'Guest Architect');
                        final email = auth.userEmail?.isNotEmpty == true
                            ? auth.userEmail!
                            : (auth.isLoggedIn ? 'Registered Client' : 'Browse Mode');
                        final phone = auth.userPhone?.isNotEmpty == true
                            ? auth.userPhone!
                            : (auth.isLoggedIn ? 'Verified Account' : '+91 Connect via Login');
                        final parts = name.trim().split(' ').where((s) => s.isNotEmpty).toList();
                        final initials = parts.isEmpty
                            ? 'GS'
                            : (parts.length == 1
                                ? parts[0].substring(0, parts[0].length.clamp(1, 2)).toUpperCase()
                                : '${parts[0][0]}${parts[1][0]}'.toUpperCase());

                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: palette.background,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: palette.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: palette.primary.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: palette.primary.withValues(alpha: 0.3), width: 1.5),
                                ),
                                child: Center(
                                  child: Text(
                                    initials,
                                    style: GoogleFonts.playfairDisplay(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: palette.primary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: GoogleFonts.playfairDisplay(
                                        color: palette.textPrimary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      email,
                                      style: GoogleFonts.inter(
                                        color: palette.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      phone,
                                      style: GoogleFonts.inter(
                                        color: palette.textTertiary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const EditProfileScreen(),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: palette.surface,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: palette.border),
                                  ),
                                   child: Icon(Icons.edit_outlined, color: palette.primary, size: 16),
                                 ),
                               ),
                             ],
                           ),
                         );
                       },
                     ),
                   ),

                   const SizedBox(height: 18),

                  // Stats Bar - Real data from Supabase
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Builder(
                      builder: (context) {
                        final orderState = ref.watch(orderRiverpodProvider);
                        final wishlistItems = ref.watch(wishlistProvider);
                        return Row(
                          children: [
                            _StatTile(
                              palette: palette,
                              label: 'Orders',
                              value: '${orderState.count}',
                              icon: Icons.inventory_2_outlined,
                              onTap: () => context.push('/orders'),
                            ),
                            const SizedBox(width: 10),
                            _StatTile(
                              palette: palette,
                              label: 'Wishlist',
                              value: '${wishlistItems.count}',
                              icon: Icons.favorite_border_rounded,
                              onTap: () => context.push('/wishlist'),
                            ),
                            const SizedBox(width: 10),
                            _StatTile(
                              palette: palette,
                              label: 'In Project',
                              value: '$cartCount',
                              icon: Icons.shopping_bag_outlined,
                              onTap: () => context.push('/cart'),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Menu Sections
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Admin card — visible only to real admins (backend
                  // profiles role), never auto-elevated.
                  if (ref.watch(authRiverpodProvider.select((s) => s.isAdmin))) ...[
                  Builder(
                    builder: (context) {
                      return GestureDetector(
                        onTap: () {
                          context.push('/admin/dashboard');
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: palette.primaryGradient,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: palette.primary.withValues(alpha: 0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.admin_panel_settings_outlined, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Admin Operations Center',
                                    style: GoogleFonts.playfairDisplay(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    'Manage products, orders, quotes & dealers',
                                    style: GoogleFonts.inter(
                                      color: Colors.white.withValues(alpha: 0.85),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => context.push('/admin'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: palette.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                              ),
                              child: Text('Open', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12)),
                            ),
                          ],
                        ),
                       ),
                     );
                   },
                   ),
                  ],

                   // ARCHITECTURAL STUDIO SECTION
                  _SectionLabel(label: 'ARCHITECTURAL STUDIO', palette: palette),
                  const SizedBox(height: 8),
                  _MenuItem(
                    palette: palette,
                    icon: Icons.inventory_2_outlined,
                    title: 'Orders & Tracking',
                    subtitle: 'Real-time order history, tracking & invoices',
                    onTap: () => context.push('/orders'),
                  ),
                  _MenuItem(
                    palette: palette,
                    icon: Icons.favorite_border_rounded,
                    title: 'Architectural Wishlist',
                    subtitle: 'Curated stones saved for project inspiration',
                    onTap: () => context.push('/wishlist'),
                  ),
                  _MenuItem(
                    palette: palette,
                    icon: Icons.auto_awesome_outlined,
                    title: 'Saved AI Studio Visualizations',
                    subtitle: 'Your rendered room visualizer concepts',
                    onTap: () => context.push('/saved-designs'),
                  ),
                  _MenuItem(
                    palette: palette,
                    icon: Icons.location_on_outlined,
                    title: 'Saved Delivery & Site Addresses',
                    subtitle: 'Manage client site addresses & defaults',
                    onTap: () => context.push('/addresses'),
                  ),

                  const SizedBox(height: 20),

                  // CONCIERGE & SAMPLES SECTION
                  _SectionLabel(label: 'CONCIERGE & SAMPLES', palette: palette),
                  const SizedBox(height: 8),
                  _MenuItem(
                    palette: palette,
                    icon: Icons.request_quote_outlined,
                    title: 'Request Quotation',
                    subtitle: 'Get certified estimates for bulk square footage',
                    onTap: () => context.push('/quotes'),
                  ),
                  _MenuItem(
                    palette: palette,
                    icon: Icons.layers_outlined,
                    title: 'Order Material Sample Box',
                    subtitle: 'Receive physical sample swatches at your studio',
                    onTap: () => context.push('/sample-order'),
                  ),
                  _MenuItem(
                    palette: palette,
                    icon: Icons.pending_actions_outlined,
                    title: 'My Sample Requests',
                    subtitle: 'Track swatch dispatch & delivery status',
                    onTap: () => context.push('/samples'),
                  ),
                  _MenuItem(
                    palette: palette,
                    icon: Icons.storefront_outlined,
                    title: 'Experience Centers & Showrooms',
                    subtitle: 'Find authorized Grazia partner dealers near you',
                    onTap: () => context.push('/dealers'),
                  ),

                  const SizedBox(height: 20),

                  // ACCOUNT & PREFERENCES SECTION
                  _SectionLabel(label: 'PREFERENCES & SUPPORT', palette: palette),
                  const SizedBox(height: 8),
                  _MenuItem(
                    palette: palette,
                    icon: Icons.settings_outlined,
                    title: 'Settings & Units',
                    subtitle: 'Measurement units, notifications & theme',
                    onTap: () => context.push('/settings'),
                  ),
                  _MenuItem(
                    palette: palette,
                    icon: Icons.headset_mic_outlined,
                    title: 'Concierge Helpline & Support',
                    subtitle: 'Direct contact with Grazia technical team',
                    onTap: () => context.push('/help'),
                  ),
                  _MenuItem(
                    palette: palette,
                    icon: Icons.info_outline_rounded,
                    title: 'About Grazia Stones',
                    subtitle: 'Heritage, quality standards & head office info',
                    onTap: () => context.push('/about'),
                  ),

                  _MenuItem(
                    palette: palette,
                    icon: Icons.logout_rounded,
                    title: 'Sign Out',
                    subtitle: 'Safely end active architectural session',
                    isDestructive: true,
                    onTap: () => _confirmLogout(context),
                  ),

                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      'Grazia Stones v1.0.0+1 (RC-2026.08)',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: palette.textTertiary,
                      ),
                    ),
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  void _showHelp(BuildContext context, LuxuryPalette palette) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Architect & Client Concierge',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Direct assistance from Grazia Stones Head Office.',
              style: GoogleFonts.inter(fontSize: 12, color: palette.textSecondary),
            ),
            const SizedBox(height: 20),
            _helpItem(palette, Icons.phone_outlined, 'Direct Helpline', '+91 9839846105 / 7518102550'),
            const SizedBox(height: 10),
            _helpItem(palette, Icons.email_outlined, 'Official Mailbox', 'hello@graziastones.com'),
            const SizedBox(height: 10),
            _helpItem(palette, Icons.location_on_outlined, 'Head Office', '123/477, Kalpi Road, Fazalganj, Kanpur'),
            const SizedBox(height: 10),
            _helpItem(palette, Icons.language_outlined, 'Official Website', 'www.graziastones.com'),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _helpItem(LuxuryPalette palette, IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: palette.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
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
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context, LuxuryPalette palette) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GraziaLogo(
              variant: GraziaLogoVariant.full,
              height: 72,
              enableGlow: true,
            ),
            const SizedBox(height: 14),
            Text(
              'STONES THAT INSPIRE',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.5,
                color: palette.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Grazia Stones delivers curated cultured stone, ledge stone, and designer wall cladding with real-time AR spatial projection and AI room visualization.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12, color: palette.textSecondary, height: 1.45),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: palette.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '123/477, Kalpi Road, Fazalganj, Kanpur',
                          style: GoogleFonts.inter(fontSize: 11, color: palette.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.email_outlined, size: 14, color: palette.primary),
                      const SizedBox(width: 6),
                      Text(
                        'hello@graziastones.com',
                        style: GoogleFonts.inter(fontSize: 11, color: palette.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.phone_outlined, size: 14, color: palette.primary),
                      const SizedBox(width: 6),
                      Text(
                        '+91 9839846105 / 7518102550',
                        style: GoogleFonts.inter(fontSize: 11, color: palette.textPrimary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                elevation: 0,
              ),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Sign Out', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          content: Text('Are you sure you want to sign out of your account?', style: GoogleFonts.inter(fontSize: 13)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white, elevation: 0),
              onPressed: () {
                Navigator.pop(ctx);
                context.go('/login');
              },
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  final LuxuryPalette palette;
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _StatTile({
    required this.palette,
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: palette.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            children: [
              Icon(icon, color: palette.primary, size: 20),
              const SizedBox(height: 6),
              Text(
                value,
                style: GoogleFonts.inter(
                  color: palette.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 11, color: palette.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final LuxuryPalette palette;
  const _SectionLabel({required this.label, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 11,
        color: palette.textTertiary,
        letterSpacing: 1.6,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final LuxuryPalette palette;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const _MenuItem({
    required this.palette,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.red.shade600 : palette.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDestructive
                  ? Colors.red.withValues(alpha: 0.04)
                  : palette.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDestructive
                    ? Colors.red.withValues(alpha: 0.2)
                    : palette.border,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          color: isDestructive ? Colors.red.shade600 : palette.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 12, color: palette.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}