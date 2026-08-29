import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/features/settings/providers/settings_provider.dart';
import 'package:grazia_stones/core/services/cache_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _appVersion = '2.0.0';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  void _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _appVersion = packageInfo.version);
      }
    } catch (e) {
      debugPrint('Failed to load app version: $e');
    }
  }

  Future<void> _clearCache() async {
    try {
      HapticFeedback.mediumImpact();
      await CacheService.instance.clearAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cache cleared successfully', style: GoogleFonts.inter()),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear cache', style: GoogleFonts.inter()),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showMeasurementUnitPicker() {
    final palette = ref.read(themePaletteProvider);
    final currentUnit = ref.read(settingsProvider).measurementUnit;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
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
              'Measurement Unit',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Select your preferred unit for dimensions and area',
              style: GoogleFonts.inter(fontSize: 12, color: palette.textSecondary),
            ),
            const SizedBox(height: 20),
            ...MeasurementUnit.values.map((unit) {
              final isSelected = unit == currentUnit;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ref.read(settingsProvider.notifier).setMeasurementUnit(unit);
                      Navigator.pop(ctx);
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected ? palette.primary.withValues(alpha: 0.1) : palette.background,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? palette.primary : palette.border,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                            color: isSelected ? palette.primary : palette.textTertiary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  unit.displayName,
                                  style: GoogleFonts.inter(
                                    color: palette.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'Length: ${unit.lengthUnit} • Area: ${unit.areaUnit}',
                                  style: GoogleFonts.inter(
                                    color: palette.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);
    final isDark = ref.watch(themePaletteProvider.notifier).isDarkMode;
    final settings = ref.watch(settingsProvider);

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
            settings.notificationsEnabled,
            (v) {
              ref.read(settingsProvider.notifier).setNotificationsEnabled(v);
              HapticFeedback.lightImpact();
            },
          ),
          
          _buildSwitchTile(
            palette,
            'Email Quote Alerts',
            'Email updates for customized pricing quotes',
            settings.emailUpdatesEnabled,
            (v) {
              ref.read(settingsProvider.notifier).setEmailUpdatesEnabled(v);
              HapticFeedback.lightImpact();
            },
          ),
          
          _buildSwitchTile(
            palette,
            'SMS Delivery Notices',
            'Transit and site delivery text alerts',
            settings.smsUpdatesEnabled,
            (v) {
              ref.read(settingsProvider.notifier).setSmsUpdatesEnabled(v);
              HapticFeedback.lightImpact();
            },
          ),
          
          const SizedBox(height: 24),
          
          // Preferences
          _buildSectionHeader('APP PREFERENCES', palette),
          const SizedBox(height: 8),
          
          _buildTile(
            palette,
            Icons.straighten_outlined,
            'Measurement Unit',
            settings.measurementUnit.displayName,
            _showMeasurementUnitPicker,
          ),
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
          _buildTile(
            palette,
            Icons.currency_rupee,
            'Currency',
            '${settings.currency} (₹ / ${settings.measurementUnit.areaUnit})',
            () {},
          ),
          _buildTile(
            palette,
            Icons.language_outlined,
            'Language',
            'English (India)',
            () {},
          ),
          
          const SizedBox(height: 24),
          
          // Support
          _buildSectionHeader('LEGAL & POLICIES', palette),
          const SizedBox(height: 8),
          
          _buildTile(palette, Icons.privacy_tip_outlined, 'Privacy Policy', '', () {
            context.push('/privacy');
          }),
          _buildTile(palette, Icons.description_outlined, 'Terms of Service', '', () {
            context.push('/terms');
          }),
          _buildTile(palette, Icons.help_outline_rounded, 'Help & Support', '', () {
            context.push('/help');
          }),
          
          const SizedBox(height: 24),
          
          // App Info
          _buildSectionHeader('ABOUT GRAZIA', palette),
          const SizedBox(height: 8),
          
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.push('/about'),
              borderRadius: BorderRadius.circular(18),
              child: Container(
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Version $_appVersion • Tap to Explore Story',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: palette.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios_rounded, size: 10, color: palette.primary),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          
          const SizedBox(height: 24),
          
          // Clear cache button
          OutlinedButton.icon(
            onPressed: _clearCache,
            icon: const Icon(Icons.cleaning_services_outlined, size: 16),
            label: Text('Clear Image Cache', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
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
