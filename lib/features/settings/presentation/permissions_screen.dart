import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/services/permission_service.dart';

/// Permissions management screen
/// 
/// Shows all app permissions with:
/// - Current status (granted/denied/not set)
/// - Request buttons
/// - Settings link for permanently denied
class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Permissions'),
        elevation: 0,
      ),
      body: ListView(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.security_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'App Permissions',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Manage permissions for app features',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[600],
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Camera Permission
          _buildPermissionSection(
            context: context,
            permission: AppPermission.camera,
            label: 'Camera',
            description: 'For taking photos of your space and stones',
            icon: Icons.camera_alt_rounded,
            features: [
              'AI visualization photo capture',
              'Room analysis',
              'Quote photo uploads',
            ],
          ),

          const Divider(height: 1),

          // Photos Permission
          _buildPermissionSection(
            context: context,
            permission: AppPermission.photos,
            label: 'Photo Library',
            description: 'For selecting images from your gallery',
            icon: Icons.photo_library_rounded,
            features: [
              'Upload room photos',
              'Select images for visualization',
              'Share designs',
            ],
          ),

          const Divider(height: 1),

          // Storage Permission
          _buildPermissionSection(
            context: context,
            permission: AppPermission.storage,
            label: 'Storage',
            description: 'For saving files and caching data',
            icon: Icons.folder_rounded,
            features: [
              'Save catalogs and PDFs',
              'Store visualizations',
              'Offline image caching',
            ],
          ),

          const Divider(height: 1),

          // Location Permission
          _buildPermissionSection(
            context: context,
            permission: AppPermission.location,
            label: 'Location',
            description: 'For finding nearby dealers',
            icon: Icons.location_on_rounded,
            features: [
              'Find authorized dealers',
              'Show distance to locations',
              'Location-based recommendations',
            ],
          ),

          const Divider(height: 1),

          // Notifications Permission
          _buildPermissionSection(
            context: context,
            permission: AppPermission.notifications,
            label: 'Notifications',
            description: 'For keeping you updated',
            icon: Icons.notifications_rounded,
            features: [
              'Order status updates',
              'AI visualization completion',
              'Quote responses',
            ],
          ),

          const SizedBox(height: 24),

          // Help Section
          _buildHelpSection(context),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPermissionSection({
    required BuildContext context,
    required AppPermission permission,
    required String label,
    required String description,
    required IconData icon,
    required List<String> features,
  }) {
    return FutureBuilder<PermissionStatus>(
      future: _getPermissionStatus(permission),
      builder: (context, snapshot) {
        final status = snapshot.data;
        final isGranted = status?.isGranted ?? false;
        final isPermanentlyDenied = status?.isPermanentlyDenied ?? false;

        return ExpansionTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getStatusColor(status).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: _getStatusColor(status),
              size: 20,
            ),
          ),
          title: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              _buildStatusChip(status),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Features list
                  Text(
                    'Used for:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...features.map((feature) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                feature,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 16),

                  // Action buttons
                  if (!isGranted)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _requestPermission(
                          context,
                          permission,
                          isPermanentlyDenied,
                        ),
                        icon: Icon(
                          isPermanentlyDenied
                              ? Icons.settings_rounded
                              : Icons.check_circle_rounded,
                        ),
                        label: Text(
                          isPermanentlyDenied ? 'Open Settings' : 'Grant Permission',
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),

                  if (isGranted)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: Colors.green[700],
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Permission granted. You can revoke this in app settings.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.green[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusChip(PermissionStatus? status) {
    Color color;
    String label;
    IconData icon;

    if (status?.isGranted ?? false) {
      color = Colors.green;
      label = 'Granted';
      icon = Icons.check_circle_rounded;
    } else if (status?.isPermanentlyDenied ?? false) {
      color = Colors.red;
      label = 'Denied';
      icon = Icons.block_rounded;
    } else if (status?.isDenied ?? false) {
      color = Colors.orange;
      label = 'Not Set';
      icon = Icons.warning_amber_rounded;
    } else {
      color = Colors.grey;
      label = 'Unknown';
      icon = Icons.help_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpSection(BuildContext context) {
    return Padding(
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
                  'About Permissions',
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
              'Permissions help Grazia Stones provide the best experience. You can manage permissions in your device settings at any time.\n\n'
              'We only request permissions when needed for specific features and never access your data without your consent.',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => openAppSettings(),
              icon: const Icon(Icons.settings_rounded, size: 18),
              label: const Text('Open App Settings'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<PermissionStatus> _getPermissionStatus(AppPermission permission) async {
    switch (permission) {
      case AppPermission.camera:
        return await Permission.camera.status;
      case AppPermission.photos:
        return await Permission.photos.status;
      case AppPermission.storage:
        return await Permission.storage.status;
      case AppPermission.location:
        return await Permission.location.status;
      case AppPermission.notifications:
        return await Permission.notification.status;
    }
  }

  Color _getStatusColor(PermissionStatus? status) {
    if (status?.isGranted ?? false) {
      return Colors.green;
    } else if (status?.isPermanentlyDenied ?? false) {
      return Colors.red;
    } else if (status?.isDenied ?? false) {
      return Colors.orange;
    } else {
      return Colors.grey;
    }
  }

  Future<void> _requestPermission(
    BuildContext context,
    AppPermission permission,
    bool isPermanentlyDenied,
  ) async {
    if (isPermanentlyDenied) {
      await openAppSettings();
      // Refresh the screen when returning
      if (mounted) {
        setState(() {});
      }
    } else {
      final granted = await PermissionService.instance.requestWithRationale(
        context: context,
        permission: permission,
      );

      if (mounted) {
        setState(() {});
        
        if (granted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permission granted successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }
}
