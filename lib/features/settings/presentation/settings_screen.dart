import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notifications = true;
  bool _emailUpdates = false;
  bool _smsUpdates = true;
  String _appVersion = '2.0.0';

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
    final palette = ref.watch(themePaletteProvider);
    final isDark = ref.watch(themePaletteProvider.notifier).isDarkMode;

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
          'Settings',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        children: [
          // Notifications Section
          _buildSectionHeader('NOTIFICATIONS & ALERTS', palette),
          const SizedBox(height: 8),
          
          _buildSwitchTile(
            palette,
            'Push Notifications',
            'Order tracking and status updates',
            _notifications,
            (v) {
              setState(() => _notifications = v);
              HapticFeedback.lightImpact();
            },
          ),
          
          _buildSwitchTile(
            palette,
            'Architectural Quotation Alerts',
            'Email updates for customized pricing quotes',
            _emailUpdates,
            (v) {
              setState(() => _emailUpdates = v);
              HapticFeedback.lightImpact();
            },
          ),
          
          _buildSwitchTile(
            palette,
            'SMS Dispatch Notices',
            'Transit and site delivery text alerts',
            _smsUpdates,
            (v) {
              setState(() => _smsUpdates = v);
              HapticFeedback.lightImpact();
            },
          ),
          
          const SizedBox(height: 24),
          
          // Preferences
          _buildSectionHeader('APP PREFERENCES', palette),
          const SizedBox(height: 8),
          
          _buildTile(palette, Icons.language_outlined, 'Language', 'English (IN)', () {}),
          _buildTile(
            palette,
            Icons.dark_mode_outlined,
            'Theme Mode',
            isDark ? 'Dark Studio' : 'Light Showroom',
            () {
              HapticFeedback.lightImpact();
              ref.read(themePaletteProvider.notifier).toggleTheme();
            },
          ),
          _buildTile(palette, Icons.currency_rupee, 'Currency & Pricing Unit', 'INR (₹ / sq ft)', () {}),
          
          const SizedBox(height: 24),
          
          // Support
          _buildSectionHeader('LEGAL & POLICIES', palette),
          const SizedBox(height: 8),
          
          _buildTile(palette, Icons.privacy_tip_outlined, 'Privacy Policy', '', () {}),
          _buildTile(palette, Icons.description_outlined, 'Terms of Service', '', () {}),
          _buildTile(palette, Icons.help_outline_rounded, 'Architect FAQ & Guides', '', () {}),
          
          const SizedBox(height: 24),
          
          // App Info
          _buildSectionHeader('ABOUT GRAZIA', palette),
          const SizedBox(height: 8),
          
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              children: [
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
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: palette.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Version $_appVersion',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: palette.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Clear cache button
          OutlinedButton.icon(
            onPressed: () {
              HapticFeedback.mediumImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Temporary cache cleared', style: GoogleFonts.inter()),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.cleaning_services_outlined, size: 16),
            label: Text('Clear Offline Image Cache', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.primary,
              side: BorderSide(color: palette.border),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),

          const SizedBox(height: 48),
        ],
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

  Widget _buildSwitchTile(LuxuryPalette palette, String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: palette.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildTile(LuxuryPalette palette, IconData icon, String title, String trailing, VoidCallback onTap) {
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
              color: palette.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: palette.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: palette.primary, size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (trailing.isNotEmpty)
                  Text(
                    trailing,
                    style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 12),
                  ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_ios_rounded, size: 12, color: palette.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
