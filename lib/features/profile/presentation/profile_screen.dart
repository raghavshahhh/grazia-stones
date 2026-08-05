import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/typography.dart';
import 'package:grazia_stones/shared/theme/spacing.dart';
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
              decoration: BoxDecoration(gradient: palette.heroGradient),
              child: Column(
                children: [
                  SizedBox(height: MediaQuery.of(context).padding.top + 12),

                  // Top row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Profile',
                          style: GLuxuryTypography.h2.copyWith(color: palette.textPrimary),
                        ),
                        // Theme toggle
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            ref.read(themePaletteProvider.notifier).toggleTheme();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: palette.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: palette.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isDark ? Icons.wb_sunny_outlined : Icons.nightlight_round_outlined,
                                  size: 16,
                                  color: palette.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isDark ? 'Light Mode' : 'Dark Mode',
                                  style: GLuxuryTypography.labelSmall.copyWith(
                                    color: palette.textPrimary,
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

                  const SizedBox(height: 24),

                  // Profile card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: palette.primaryGradient,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: palette.primary.withValues(alpha: 0.3),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: palette.background.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(color: palette.background.withValues(alpha: 0.4), width: 2),
                            ),
                            child: Icon(Icons.person, size: 38, color: palette.background),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Raghav Shah',
                                  style: GLuxuryTypography.h2.copyWith(
                                    color: palette.background,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'raghav@grazia.com',
                                  style: GLuxuryTypography.bodySmall.copyWith(
                                    color: palette.background.withValues(alpha: 0.85),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '+91 98765 43210',
                                  style: GLuxuryTypography.bodySmall.copyWith(
                                    color: palette.background.withValues(alpha: 0.75),
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
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: palette.background.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.edit_outlined, color: palette.background, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Stats bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _StatTile(
                          palette: palette,
                          label: 'Orders',
                          value: '3',
                          icon: Icons.shopping_bag_outlined,
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
                          label: 'Cart',
                          value: '$cartCount',
                          icon: Icons.shopping_cart_outlined,
                          onTap: () {},
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel(label: 'My Activity', palette: palette),
                  GLuxurySpacing.gapSm,
                  _MenuItem(
                    palette: palette,
                    icon: Icons.shopping_bag_outlined,
                    title: 'My Orders',
                    subtitle: '3 recent orders',
                    onTap: () => context.push('/orders'),
                  ),
                  _MenuItem(
                    palette: palette,
                    icon: Icons.favorite_border_rounded,
                    title: 'Wishlist',
                    subtitle: '5 saved stones',
                    onTap: () => context.push('/wishlist'),
                  ),
                  _MenuItem(
                    palette: palette,
                    icon: Icons.request_quote_outlined,
                    title: 'My Quotes',
                    subtitle: 'View quote requests',
                    onTap: () => context.push('/quotes'),
                  ),
                  _MenuItem(
                    palette: palette,
                    icon: Icons.inventory_2_outlined,
                    title: 'Sample Orders',
                    subtitle: 'Track samples',
                    onTap: () => context.push('/sample-order'),
                  ),

                  GLuxurySpacing.gapBase,
                  _SectionLabel(label: 'Preferences', palette: palette),
                  GLuxurySpacing.gapSm,

                  _MenuItem(
                    palette: palette,
                    icon: isDark ? Icons.wb_sunny_outlined : Icons.nightlight_round_outlined,
                    title: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                    subtitle: isDark ? 'Pearl luxury theme' : 'Gold luxury theme',
                    trailing: Switch(
                      value: isDark,
                      onChanged: (_) {
                        HapticFeedback.lightImpact();
                        ref.read(themePaletteProvider.notifier).toggleTheme();
                      },
                      activeThumbColor: palette.primary,
                    ),
                    onTap: () => ref.read(themePaletteProvider.notifier).toggleTheme(),
                  ),
                  _MenuItem(
                    palette: palette,
                    icon: Icons.location_on_outlined,
                    title: 'Saved Addresses',
                    subtitle: 'Manage delivery addresses',
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
                    title: 'Find Dealers',
                    subtitle: 'Locate nearby showrooms',
                    onTap: () => context.push('/dealers'),
                  ),

                  GLuxurySpacing.gapBase,
                  _SectionLabel(label: 'Support', palette: palette),
                  GLuxurySpacing.gapSm,

                  _MenuItem(
                    palette: palette,
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    subtitle: 'App preferences',
                    onTap: () => context.push('/settings'),
                  ),
                  _MenuItem(
                    palette: palette,
                    icon: Icons.help_outline_rounded,
                    title: 'Help & Support',
                    subtitle: 'FAQs and contact',
                    onTap: () => _showHelp(context, palette),
                  ),
                  _MenuItem(
                    palette: palette,
                    icon: Icons.info_outline_rounded,
                    title: 'About Grazia',
                    subtitle: 'Version 2.0.0',
                    onTap: () => _showAbout(context, palette),
                  ),

                  GLuxurySpacing.gapBase,
                  _MenuItem(
                    palette: palette,
                    icon: Icons.logout_rounded,
                    title: 'Logout',
                    subtitle: 'Sign out of your account',
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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: palette.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('Help & Support', style: GLuxuryTypography.h2.copyWith(color: palette.textPrimary)),
            const SizedBox(height: 20),
            _helpItem(palette, Icons.phone_outlined, 'Call Us', '+91 98765 43210'),
            const SizedBox(height: 10),
            _helpItem(palette, Icons.email_outlined, 'Email Us', 'support@grazia.com'),
            const SizedBox(height: 10),
            _helpItem(palette, Icons.chat_bubble_outline, 'WhatsApp', 'Chat with us 24/7'),
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
        color: palette.surface,
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
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GLuxuryTypography.bodyMedium.copyWith(color: palette.textPrimary, fontWeight: FontWeight.w600)),
            Text(subtitle, style: GLuxuryTypography.bodySmall.copyWith(color: palette.textSecondary)),
          ]),
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
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: palette.primaryGradient,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(Icons.diamond_outlined, color: palette.background, size: 32),
            ),
            const SizedBox(height: 16),
            Text('GRAZIA', style: GLuxuryTypography.h1.copyWith(color: palette.textPrimary)),
            const SizedBox(height: 6),
            Text('Premium Stone Catalogue', style: GLuxuryTypography.bodySmall.copyWith(color: palette.textSecondary)),
            const SizedBox(height: 4),
            Text('Version 2.0.0', style: GLuxuryTypography.labelSmall.copyWith(color: palette.textTertiary)),
            const SizedBox(height: 16),
            Text(
              'Grazia brings India\'s finest natural stone collections to your fingertips. AI-powered visualization, AR preview, and seamless ordering.',
              textAlign: TextAlign.center,
              style: GLuxuryTypography.bodySmall.copyWith(color: palette.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.primary,
                foregroundColor: palette.background,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Got it'),
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
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(ctx);
                context.go('/login');
              },
              child: const Text('Logout'),
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
            color: palette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            children: [
              Icon(icon, color: palette.primary, size: 22),
              const SizedBox(height: 6),
              Text(value, style: GLuxuryTypography.h2.copyWith(color: palette.textPrimary, fontSize: 20)),
              Text(label, style: GLuxuryTypography.labelSmall.copyWith(color: palette.textSecondary)),
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
      label.toUpperCase(),
      style: GLuxuryTypography.labelSmall.copyWith(
        color: palette.textTertiary,
        letterSpacing: 1.4,
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
  final Widget? trailing;

  const _MenuItem({
    required this.palette,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.red : palette.primary;
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
                  ? Colors.red.withValues(alpha: 0.05)
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
                    color: color.withValues(alpha: 0.12),
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
                        style: GLuxuryTypography.bodyMedium.copyWith(
                          color: isDestructive ? Colors.red : palette.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: GLuxuryTypography.bodySmall.copyWith(color: palette.textSecondary),
                      ),
                    ],
                  ),
                ),
                trailing ?? Icon(Icons.arrow_forward_ios, size: 14, color: palette.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
