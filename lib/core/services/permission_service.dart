import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../error/app_exception.dart';

/// Permission types used in the app
enum AppPermission {
  camera,
  photos,
  storage,
  location,
  notifications,
}

/// Permission service with contextual UI
/// 
/// Features:
/// - Request permissions with rationale dialogs
/// - Handle denied and permanently denied states
/// - Open app settings when needed
/// - Track permission status
class PermissionService {
  static PermissionService? _instance;
  static PermissionService get instance => _instance ??= PermissionService._();

  PermissionService._();

  // ═══════════════════════════════════════════════════════════════════════════
  // PERMISSION CHECKING
  // ═══════════════════════════════════════════════════════════════════════════

  /// Check if a permission is granted
  Future<bool> isGranted(AppPermission permission) async {
    final status = await _getPermissionStatus(permission);
    return status.isGranted;
  }

  /// Check if a permission is denied
  Future<bool> isDenied(AppPermission permission) async {
    final status = await _getPermissionStatus(permission);
    return status.isDenied;
  }

  /// Check if a permission is permanently denied
  Future<bool> isPermanentlyDenied(AppPermission permission) async {
    final status = await _getPermissionStatus(permission);
    return status.isPermanentlyDenied;
  }

  /// Get current permission status
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

  // ═══════════════════════════════════════════════════════════════════════════
  // PERMISSION REQUESTING
  // ═══════════════════════════════════════════════════════════════════════════

  /// Request a permission (without showing rationale)
  Future<bool> request(AppPermission permission) async {
    final status = await _requestPermission(permission);
    return status.isGranted;
  }

  /// Request a permission with contextual rationale dialog
  /// 
  /// Shows a dialog explaining WHY the permission is needed before requesting it.
  /// If denied, shows appropriate error.
  /// If permanently denied, offers to open app settings.
  Future<bool> requestWithRationale({
    required BuildContext context,
    required AppPermission permission,
    String? title,
    String? description,
    String? icon,
  }) async {
    // Check if already granted
    if (await isGranted(permission)) {
      return true;
    }

    // Check if permanently denied
    if (await isPermanentlyDenied(permission)) {
      return await _showPermanentlyDeniedDialog(
        context: context,
        permission: permission,
        title: title,
        description: description,
      );
    }

    // Show rationale dialog
    final shouldRequest = await _showRationaleDialog(
      context: context,
      permission: permission,
      title: title,
      description: description,
      icon: icon,
    );

    if (!shouldRequest) {
      return false;
    }

    // Request permission
    final status = await _requestPermission(permission);

    if (status.isGranted) {
      return true;
    } else if (status.isPermanentlyDenied) {
      if (context.mounted) {
        return await _showPermanentlyDeniedDialog(
          context: context,
          permission: permission,
          title: title,
          description: description,
        );
      }
      return false;
    } else {
      return false;
    }
  }

  Future<PermissionStatus> _requestPermission(AppPermission permission) async {
    switch (permission) {
      case AppPermission.camera:
        return await Permission.camera.request();
      case AppPermission.photos:
        return await Permission.photos.request();
      case AppPermission.storage:
        return await Permission.storage.request();
      case AppPermission.location:
        return await Permission.location.request();
      case AppPermission.notifications:
        return await Permission.notification.request();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PERMISSION DIALOGS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Show rationale dialog explaining why permission is needed
  Future<bool> _showRationaleDialog({
    required BuildContext context,
    required AppPermission permission,
    String? title,
    String? description,
    String? icon,
  }) async {
    final info = _getPermissionInfo(permission);
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => PermissionRationaleDialog(
        permission: permission,
        title: title ?? info.title,
        description: description ?? info.description,
        icon: icon ?? info.icon,
      ),
    );

    return result ?? false;
  }

  /// Show dialog for permanently denied permission
  Future<bool> _showPermanentlyDeniedDialog({
    required BuildContext context,
    required AppPermission permission,
    String? title,
    String? description,
  }) async {
    final info = _getPermissionInfo(permission);
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => PermissionPermanentlyDeniedDialog(
        permission: permission,
        title: title ?? info.title,
        description: description ?? info.settingsDescription,
      ),
    );

    if (result == true) {
      await openAppSettings();
      // Check again after returning from settings
      return await isGranted(permission);
    }

    return false;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PERMISSION INFO
  // ═══════════════════════════════════════════════════════════════════════════

  PermissionInfo _getPermissionInfo(AppPermission permission) {
    switch (permission) {
      case AppPermission.camera:
        return PermissionInfo(
          title: 'Camera Access',
          description:
              'Grazia Stones needs camera access to:\n'
              '• Take photos of your space for AI visualization\n'
              '• Capture room images for stone recommendations\n'
              '• Upload product photos for quotes',
          settingsDescription:
              'Camera access was permanently denied. Please enable it in app settings to use this feature.',
          icon: '📷',
        );

      case AppPermission.photos:
        return PermissionInfo(
          title: 'Photo Library Access',
          description:
              'Grazia Stones needs photo library access to:\n'
              '• Select images from your gallery\n'
              '• Upload room photos for AI visualization\n'
              '• Share stone designs and quotes',
          settingsDescription:
              'Photo library access was permanently denied. Please enable it in app settings to use this feature.',
          icon: '🖼️',
        );

      case AppPermission.storage:
        return PermissionInfo(
          title: 'Storage Access',
          description:
              'Grazia Stones needs storage access to:\n'
              '• Save downloaded catalogs and PDFs\n'
              '• Store AI-generated visualizations\n'
              '• Cache product images for offline viewing',
          settingsDescription:
              'Storage access was permanently denied. Please enable it in app settings to use this feature.',
          icon: '💾',
        );

      case AppPermission.location:
        return PermissionInfo(
          title: 'Location Access',
          description:
              'Grazia Stones needs location access to:\n'
              '• Find nearby authorized dealers\n'
              '• Show distance to dealer locations\n'
              '• Provide location-based recommendations',
          settingsDescription:
              'Location access was permanently denied. Please enable it in app settings to use this feature.',
          icon: '📍',
        );

      case AppPermission.notifications:
        return PermissionInfo(
          title: 'Notification Access',
          description:
              'Grazia Stones needs notification access to:\n'
              '• Send order status updates\n'
              '• Notify when AI visualizations are ready\n'
              '• Alert you about quote responses',
          settingsDescription:
              'Notification access was permanently denied. Please enable it in app settings to stay updated.',
          icon: '🔔',
        );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BATCH OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Request multiple permissions at once
  Future<Map<AppPermission, bool>> requestMultiple(
    List<AppPermission> permissions,
  ) async {
    final results = <AppPermission, bool>{};

    for (final permission in permissions) {
      results[permission] = await request(permission);
    }

    return results;
  }

  /// Check status of multiple permissions
  Future<Map<AppPermission, PermissionStatus>> checkMultiple(
    List<AppPermission> permissions,
  ) async {
    final results = <AppPermission, PermissionStatus>{};

    for (final permission in permissions) {
      results[permission] = await _getPermissionStatus(permission);
    }

    return results;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PERMISSION INFO
// ═══════════════════════════════════════════════════════════════════════════

class PermissionInfo {
  final String title;
  final String description;
  final String settingsDescription;
  final String icon;

  PermissionInfo({
    required this.title,
    required this.description,
    required this.settingsDescription,
    required this.icon,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// PERMISSION RATIONALE DIALOG
// ═══════════════════════════════════════════════════════════════════════════

class PermissionRationaleDialog extends StatelessWidget {
  final AppPermission permission;
  final String title;
  final String description;
  final String icon;

  const PermissionRationaleDialog({
    super.key,
    required this.permission,
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Text(
            icon,
            style: const TextStyle(fontSize: 32),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        description,
        style: TextStyle(
          fontSize: 15,
          height: 1.5,
          color: Colors.grey[700],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Not Now',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Allow'),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PERMISSION PERMANENTLY DENIED DIALOG
// ═══════════════════════════════════════════════════════════════════════════

class PermissionPermanentlyDeniedDialog extends StatelessWidget {
  final AppPermission permission;
  final String title;
  final String description;

  const PermissionPermanentlyDeniedDialog({
    super.key,
    required this.permission,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.settings_rounded,
              color: Colors.orange,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            description,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: Colors.blue[700],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You will be taken to app settings. Find Grazia Stones and enable the permission.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Cancel',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Open Settings'),
        ),
      ],
    );
  }
}
