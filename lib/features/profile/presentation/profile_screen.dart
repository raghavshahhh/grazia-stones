import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/typography.dart';
import 'package:grazia_stones/shared/theme/spacing.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = GLuxuryPalettes.gold;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_ios_new, color: palette.textPrimary),
        ),
        title: Text(
          'Profile',
          style: GLuxuryTypography.h2.copyWith(color: palette.textPrimary),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: palette.primaryGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: palette.background, width: 3),
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: palette.background,
                      child: Icon(Icons.person, size: 50, color: palette.primary),
                    ),
                  ),
                  GLuxurySpacing.gapBase,
                  Text(
                    'John Doe',
                    style: GLuxuryTypography.h1.copyWith(color: palette.background),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '+91 9876543210',
                    style: GLuxuryTypography.bodyMedium.copyWith(color: palette.background.withValues(alpha: 0.9)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'john.doe@example.com',
                    style: GLuxuryTypography.bodySmall.copyWith(color: palette.background.withValues(alpha: 0.8)),
                  ),
                  GLuxurySpacing.gapBase,
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit Profile'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.background,
                      side: BorderSide(color: palette.background),
                    ),
                  ),
                ],
              ),
            ),
            
            GLuxurySpacing.gapXl,
            
            // Menu Items
            _buildMenuItem(palette, Icons.shopping_bag_outlined, 'My Orders', () => context.push('/orders')),
            _buildMenuItem(palette, Icons.favorite_border, 'Wishlist', () => context.push('/wishlist')),
            _buildMenuItem(palette, Icons.location_on_outlined, 'Saved Addresses', () {}),
            _buildMenuItem(palette, Icons.description_outlined, 'My Quotes', () {}),
            _buildMenuItem(palette, Icons.inventory_2_outlined, 'Sample Requests', () {}),
            
            GLuxurySpacing.gapBase,
            
            _buildMenuItem(palette, Icons.settings_outlined, 'Settings', () => context.push('/settings')),
            _buildMenuItem(palette, Icons.help_outline, 'Help & Support', () {}),
            _buildMenuItem(palette, Icons.info_outline, 'About', () {}),
            
            GLuxurySpacing.gapBase,
            
            _buildMenuItem(palette, Icons.logout, 'Logout', () {
              HapticFeedback.mediumImpact();
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(onPressed: () => context.pop(), child: const Text('Cancel')),
                    ElevatedButton(
                      onPressed: () {
                        context.pop();
                        context.go('/login');
                      },
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
            }, isDestructive: true),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(GoldPalette palette, IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.border),
            ),
            child: Row(
              children: [
                Icon(icon, color: isDestructive ? Colors.red : palette.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: GLuxuryTypography.bodyLarge.copyWith(
                      color: isDestructive ? Colors.red : palette.textPrimary,
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 16, color: palette.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
