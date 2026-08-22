import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/features/cart/presentation/cart_screen.dart';
import 'package:grazia_stones/features/profile/presentation/edit_profile_screen.dart';
import 'package:grazia_stones/features/profile/presentation/addresses_screen.dart';

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
                    child: Container(
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
                                'RS',
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 22,
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
                                  'Raghav Shah',
                                  style: GoogleFonts.playfairDisplay(
                                    color: palette.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'raghav@grazia.com',
                                  style: GoogleFonts.inter(
                                    color: palette.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '+91 98765 43210',
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
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Stats Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      children: [
                        _StatTile(
                          palette: palette,
                          label: 'Orders',
                          value: '3',
                          icon: Icons.inventory_2_outlined,
                          onTap: () => context.push('/orders'),
                        ),
                        const SizedBox(width: 10),
                        _StatTile(
                          palette: palette,
                          label: 'Wishlist',
                          value: '5',
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
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Menu items
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel(label: 'PROJECT & PROCUREMENT', palette: palette),
                  const SizedBox(height: 8),
                  _MenuItem(
                    palette: palette,
                    icon: Icons.inventory_2_outlined,
                    title: 'My Orders',
                    subtitle: '3 orders in delivery / production',
                    onTap: () => context.push('/orders'),
                  ),
                  _MenuItem(
                    palette: palette,
                    icon: Icons.favorite_border_rounded,
                    title: 'Saved Specifications',
                    subtitle: '5 bookmarked stone slabs',
                    onTap: () => context.push('/wishlist'),
                  ),
                  _MenuItem(
                    palette: palette,
                    icon: Icons.request_quote_outlined,
                    title: 'Project Quotes',
                    subtitle: 'Architectural pricing requests',
                    onTap: () => context.push('/quotes'),
                  ),
                  _MenuItem(
                    palette: palette,
                    icon: Icons.texture_outlined,
                    title: 'Sample Orders',
                    subtitle: 'Track physical 4x4 swatches',
                    onTap: () => context.push('/sample-order'),
                  ),

                  const SizedBox(height: 20),
                  _SectionLabel(label: 'PREFERENCES & ADDRESSES', palette: palette),
                  const SizedBox(height: 8),

                  _MenuItem(
                    palette: palette,
                    icon: Icons.location_on_outlined,
                    title: 'Delivery Addresses',
                    subtitle: 'Site locations and billing destinations',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AddressesScreen(),
                        ),
                      );
                    },
                  ),
                  _MenuItem(
                    palette: palette,
                    icon: Icons.store_outlined,
                    title: 'Dealer & Experience Centers',
                    subtitle: 'Locate authorized Grazia showrooms',
                    onTap: () => context.push('/dealers'),
                  ),

                  const SizedBox(height: 20),
                  _SectionLabel(label: 'SUPPORT & BRAND', palette: palette),
                  const SizedBox(height: 8),

                  _MenuItem(
                    palette: palette,
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    subtitle: 'Notifications and app configurations',
                    onTap: () => context.push('/settings'),
                  ),
                  _MenuItem(
                    palette: palette,
                    icon: Icons.support_agent_outlined,
                    title: 'Architect Concierge',
                    subtitle: 'Direct WhatsApp and specialist helpline',
                    onTap: () => _showHelp(context, palette),
                  ),
                  _MenuItem(
                    palette: palette,
                    icon: Icons.info_outline_rounded,
                    title: 'About Grazia Stones',
                    subtitle: 'Architectural Stone Catalogue v2.0',
                    onTap: () => _showAbout(context, palette),
                  ),

                  const SizedBox(height: 16),
                  _MenuItem(
                    palette: palette,
                    icon: Icons.logout_rounded,
                    title: 'Sign Out',
                    subtitle: 'Sign out of this session',
                    isDestructive: true,
                    onTap: () => _confirmLogout(context),
                  ),

                  const SizedBox(height: 100),
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
              'Architect Concierge',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Connect with our stone specialist for project consultation.',
              style: GoogleFonts.inter(fontSize: 12, color: palette.textSecondary),
            ),
            const SizedBox(height: 20),
            _helpItem(palette, Icons.phone_outlined, 'Direct Helpline', '+91 98765 43210'),
            const SizedBox(height: 10),
            _helpItem(palette, Icons.email_outlined, 'Architect Desk', 'concierge@graziastones.com'),
            const SizedBox(height: 10),
            _helpItem(palette, Icons.chat_bubble_outline_rounded, 'WhatsApp Concierge', '24/7 Priority Support'),
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
          Column(
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
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: palette.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.diamond_outlined, color: palette.primary, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              'GRAZIA STONES',
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Architectural Natural Stone Studio',
              style: GoogleFonts.inter(fontSize: 11, color: palette.textTertiary),
            ),
            const SizedBox(height: 14),
            Text(
              'Grazia Stones delivers curated Italian, Turkish, and Brazilian natural stones with AI neural lighting and AR spatial preview.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12, color: palette.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
