import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/typography.dart';
import 'package:grazia_stones/shared/theme/spacing.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;
  bool _emailUpdates = false;
  bool _smsUpdates = true;
  String _appVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  void _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() => _appVersion = packageInfo.version);
    } catch (e) {
      // Use default version
    }
  }

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
          'Settings',
          style: GLuxuryTypography.h2.copyWith(color: palette.textPrimary),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Notifications Section
          Text('Notifications', style: GLuxuryTypography.h3.copyWith(color: palette.textPrimary)),
          GLuxurySpacing.gapSm,
          
          _buildSwitchTile(
            palette,
            'Push Notifications',
            'Receive notifications about orders and offers',
            _notifications,
            (v) {
              setState(() => _notifications = v);
              HapticFeedback.lightImpact();
            },
          ),
          
          _buildSwitchTile(
            palette,
            'Email Updates',
            'Get updates via email',
            _emailUpdates,
            (v) {
              setState(() => _emailUpdates = v);
              HapticFeedback.lightImpact();
            },
          ),
          
          _buildSwitchTile(
            palette,
            'SMS Updates',
            'Receive SMS for order updates',
            _smsUpdates,
            (v) {
              setState(() => _smsUpdates = v);
              HapticFeedback.lightImpact();
            },
          ),
          
          GLuxurySpacing.gapXl,
          
          // Preferences
          Text('Preferences', style: GLuxuryTypography.h3.copyWith(color: palette.textPrimary)),
          GLuxurySpacing.gapSm,
          
          _buildTile(palette, Icons.language, 'Language', 'English', () {}),
          _buildTile(palette, Icons.dark_mode_outlined, 'Theme', 'System Default', () {}),
          _buildTile(palette, Icons.currency_rupee, 'Currency', 'INR (₹)', () {}),
          
          GLuxurySpacing.gapXl,
          
          // Support
          Text('Support', style: GLuxuryTypography.h3.copyWith(color: palette.textPrimary)),
          GLuxurySpacing.gapSm,
          
          _buildTile(palette, Icons.privacy_tip_outlined, 'Privacy Policy', '', () {}),
          _buildTile(palette, Icons.description_outlined, 'Terms & Conditions', '', () {}),
          _buildTile(palette, Icons.help_outline, 'FAQs', '', () {}),
          _buildTile(palette, Icons.contact_support_outlined, 'Contact Us', '', () {}),
          
          GLuxurySpacing.gapXl,
          
          // App Info
          Text('About', style: GLuxuryTypography.h3.copyWith(color: palette.textPrimary)),
          GLuxurySpacing.gapSm,
          
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: palette.primaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  'GRAZIA STONES',
                  style: GLuxuryTypography.h2.copyWith(
                    color: palette.background,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Luxury Redefined',
                  style: GLuxuryTypography.bodySmall.copyWith(
                    color: palette.background.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Version $_appVersion',
                  style: GLuxuryTypography.bodySmall.copyWith(
                    color: palette.background.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          
          GLuxurySpacing.gapXl,
          
          // Clear cache button
          OutlinedButton.icon(
            onPressed: () {
              HapticFeedback.mediumImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache cleared'), backgroundColor: Colors.green),
              );
            },
            icon: const Icon(Icons.cleaning_services_outlined),
            label: const Text('Clear Cache'),
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.primary,
              side: BorderSide(color: palette.border),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(GoldPalette palette, String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GLuxuryTypography.bodyLarge.copyWith(color: palette.textPrimary)),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(subtitle, style: GLuxuryTypography.bodySmall.copyWith(color: palette.textSecondary)),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: palette.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildTile(GoldPalette palette, IconData icon, String title, String trailing, VoidCallback onTap) {
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
                Icon(icon, color: palette.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(title, style: GLuxuryTypography.bodyLarge.copyWith(color: palette.textPrimary)),
                ),
                if (trailing.isNotEmpty)
                  Text(trailing, style: GLuxuryTypography.bodySmall.copyWith(color: palette.textSecondary)),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_ios, size: 16, color: palette.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
