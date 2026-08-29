import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/crash_reporting_service.dart';
import '../../../core/config/image_cache_config.dart';
import '../../../core/providers/analytics_provider.dart';

/// Monitoring and diagnostics screen
/// 
/// Shows:
/// - Analytics status
/// - Crash reporting status
/// - Cache size and management
/// - App diagnostics
class MonitoringScreen extends ConsumerStatefulWidget {
  const MonitoringScreen({super.key});

  @override
  ConsumerState<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends ConsumerState<MonitoringScreen> {
  double _cacheSizeMB = 0.0;
  bool _isLoadingCacheSize = true;
  bool _isClearingCache = false;

  @override
  void initState() {
    super.initState();
    _loadCacheSize();
  }

  Future<void> _loadCacheSize() async {
    setState(() => _isLoadingCacheSize = true);
    try {
      final size = await ImageCacheConfig.getCacheSizeMB();
      if (mounted) {
        setState(() {
          _cacheSizeMB = size;
          _isLoadingCacheSize = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCacheSize = false);
      }
    }
  }

  Future<void> _clearCache() async {
    setState(() => _isClearingCache = true);
    try {
      await ImageCacheConfig.clearCache();
      await _loadCacheSize();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cache cleared successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear cache: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isClearingCache = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final analyticsEnabled = ref.watch(analyticsEnabledProvider);
    final crashReportingEnabled = ref.watch(crashReportingEnabledProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoring'),
        elevation: 0,
      ),
      body: ListView(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.analytics_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'App Monitoring',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Analytics, crash reporting, and diagnostics',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Analytics Section
          _buildSectionHeader('Analytics'),
          SwitchListTile(
            secondary: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: analyticsEnabled
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.analytics_outlined,
                color: analyticsEnabled ? Colors.green : Colors.grey,
                size: 20,
              ),
            ),
            title: const Text('Analytics Tracking'),
            subtitle: Text(
              analyticsEnabled
                  ? 'Tracking user behavior and app usage'
                  : 'Analytics disabled',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
            value: analyticsEnabled,
            onChanged: (value) {
              ref.read(analyticsEnabledProvider.notifier).state = value;
              AnalyticsService.instance.setEnabled(value);
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    value
                        ? 'Analytics enabled'
                        : 'Analytics disabled',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),

          const Divider(height: 1),

          // Crash Reporting Section
          _buildSectionHeader('Crash Reporting'),
          SwitchListTile(
            secondary: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: crashReportingEnabled
                    ? Colors.blue.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bug_report_outlined,
                color: crashReportingEnabled ? Colors.blue : Colors.grey,
                size: 20,
              ),
            ),
            title: const Text('Crash Reporting'),
            subtitle: Text(
              crashReportingEnabled
                  ? 'Automatically report crashes and errors'
                  : 'Crash reporting disabled',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
            value: crashReportingEnabled,
            onChanged: (value) {
              ref.read(crashReportingEnabledProvider.notifier).state = value;
              CrashReportingService.instance.setEnabled(value);
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    value
                        ? 'Crash reporting enabled'
                        : 'Crash reporting disabled',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),

          const Divider(height: 1),

          // Cache Management Section
          _buildSectionHeader('Cache Management'),
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.storage_rounded,
                color: Colors.purple,
                size: 20,
              ),
            ),
            title: const Text('Image Cache'),
            subtitle: _isLoadingCacheSize
                ? const Text('Calculating...')
                : Text(
                    '${_cacheSizeMB.toStringAsFixed(2)} MB',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
            trailing: _isClearingCache
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton(
                    onPressed: _cacheSizeMB > 0 ? _clearCache : null,
                    child: const Text('Clear'),
                  ),
          ),

          const Divider(height: 1),

          // Diagnostics Section
          _buildSectionHeader('Diagnostics'),
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.info_outline_rounded,
                color: Colors.orange,
                size: 20,
              ),
            ),
            title: const Text('App Information'),
            subtitle: const Text(
              'Version, build number, device info',
              style: TextStyle(fontSize: 13),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              // Navigate to app info screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('App info screen not implemented yet'),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // Info Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.blue.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: Colors.blue[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'About Monitoring',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Analytics helps us understand how you use the app and improve your experience. '
                    'Crash reporting automatically sends error reports to help us fix issues quickly.\n\n'
                    'All data is anonymized and used solely for improving the app. '
                    'You can disable these features at any time.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
