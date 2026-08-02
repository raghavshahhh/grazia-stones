import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:grazia_stones/core/constants/app_colors.dart';
import 'package:grazia_stones/core/constants/app_dimensions.dart';
import 'package:grazia_stones/core/theme/text_styles.dart';
import 'package:grazia_stones/features/auth/providers/auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.charcoal,
      body: SafeArea(
        child: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            final name = auth.userName ?? 'Guest';
            final phone = auth.userPhone ?? '';
            final initials = name.split(' ').map((w) => w[0]).take(2).join().toUpperCase();

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.spacingL),
              child: Column(
                children: [
                  const SizedBox(height: AppDimensions.spacingL),

                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.gold, width: 2),
                          ),
                          child: Center(
                            child: Text(
                              initials,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w600,
                                color: AppColors.gold,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              color: AppColors.gold,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt, size: 14, color: AppColors.charcoal),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(name, style: GraziaTextStyles.headlineSmall.copyWith(color: Colors.white)),
                  if (phone.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(phone, style: GraziaTextStyles.bodyMedium.copyWith(color: AppColors.silver)),
                  ],
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Architect · Pro Member', style: GraziaTextStyles.bodySmall.copyWith(color: AppColors.gold)),
                  ),
                  const SizedBox(height: AppDimensions.spacingXL),

                  _ProfileMenuItem(icon: Icons.shopping_bag_outlined, title: 'My Orders', onTap: () => context.go('/orders')),
                  _ProfileMenuItem(icon: Icons.favorite_outline, title: 'Wishlist', onTap: () {}),
                  _ProfileMenuItem(icon: Icons.format_quote_outlined, title: 'My Quotes', onTap: () => context.go('/quotes')),
                  _ProfileMenuItem(icon: Icons.inventory_2_outlined, title: 'Sample Requests', onTap: () {}),
                  _ProfileMenuItem(icon: Icons.notifications_outlined, title: 'Notifications', onTap: () {}),

                  const SizedBox(height: AppDimensions.spacingL),
                  Container(height: 1, color: AppColors.slate),
                  const SizedBox(height: AppDimensions.spacingL),

                  _ProfileMenuItem(icon: Icons.location_on_outlined, title: 'Saved Addresses', onTap: () {}),
                  _ProfileMenuItem(icon: Icons.credit_card_outlined, title: 'Payment Methods', onTap: () {}),
                  _ProfileMenuItem(icon: Icons.settings_outlined, title: 'Settings', onTap: () {}),
                  _ProfileMenuItem(icon: Icons.help_outline, title: 'Help & Support', onTap: () {}),

                  const SizedBox(height: AppDimensions.spacingL),
                  Container(height: 1, color: AppColors.slate),
                  const SizedBox(height: AppDimensions.spacingL),

                  _ProfileMenuItem(
                    icon: Icons.logout,
                    title: 'Log Out',
                    color: AppColors.goldWarm,
                    onTap: () {
                      auth.logout();
                      context.go('/login');
                    },
                  ),
                  const SizedBox(height: AppDimensions.spacingL),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? color;
  final VoidCallback onTap;

  const _ProfileMenuItem({required this.icon, required this.title, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final itemColor = color ?? AppColors.silver;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(icon, color: itemColor, size: 22),
      title: Text(title, style: GraziaTextStyles.bodyLarge.copyWith(color: itemColor)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.slate, size: 20),
      onTap: onTap,
    );
  }
}
