import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/permission_service.dart';

/// Permission status indicator widget
/// 
/// Shows the current status of a permission with colored icon
class PermissionStatusIndicator extends StatelessWidget {
  final AppPermission permission;
  final String label;
  final VoidCallback? onTap;

  const PermissionStatusIndicator({
    super.key,
    required this.permission,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PermissionStatus>(
      future: _getStatus(),
      builder: (context, snapshot) {
        final status = snapshot.data;
        final isGranted = status?.isGranted ?? false;
        final isDenied = status?.isDenied ?? false;
        final isPermanentlyDenied = status?.isPermanentlyDenied ?? false;

        Color statusColor;
        IconData statusIcon;
        String statusText;

        if (isGranted) {
          statusColor = Colors.green;
          statusIcon = Icons.check_circle_rounded;
          statusText = 'Granted';
        } else if (isPermanentlyDenied) {
          statusColor = Colors.red;
          statusIcon = Icons.block_rounded;
          statusText = 'Denied';
        } else if (isDenied) {
          statusColor = Colors.orange;
          statusIcon = Icons.warning_amber_rounded;
          statusText = 'Not Set';
        } else {
          statusColor = Colors.grey;
          statusIcon = Icons.help_outline_rounded;
          statusText = 'Unknown';
        }

        return ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getPermissionIcon(),
              color: statusColor,
              size: 20,
            ),
          ),
          title: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            statusText,
            style: TextStyle(
              fontSize: 13,
              color: statusColor,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                statusIcon,
                color: statusColor,
                size: 20,
              ),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded),
              ],
            ],
          ),
          onTap: onTap,
        );
      },
    );
  }

  Future<PermissionStatus> _getStatus() async {
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

  IconData _getPermissionIcon() {
    switch (permission) {
      case AppPermission.camera:
        return Icons.camera_alt_rounded;
      case AppPermission.photos:
        return Icons.photo_library_rounded;
      case AppPermission.storage:
        return Icons.folder_rounded;
      case AppPermission.location:
        return Icons.location_on_rounded;
      case AppPermission.notifications:
        return Icons.notifications_rounded;
    }
  }
}

/// Permission request button
/// 
/// Shows appropriate UI based on permission status
class PermissionRequestButton extends StatefulWidget {
  final AppPermission permission;
  final String? title;
  final String? description;
  final Widget? child;
  final void Function(bool granted)? onResult;

  const PermissionRequestButton({
    super.key,
    required this.permission,
    this.title,
    this.description,
    this.child,
    this.onResult,
  });

  @override
  State<PermissionRequestButton> createState() =>
      _PermissionRequestButtonState();
}

class _PermissionRequestButtonState extends State<PermissionRequestButton> {
  bool _isRequesting = false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: PermissionService.instance.isGranted(widget.permission),
      builder: (context, snapshot) {
        final isGranted = snapshot.data ?? false;

        if (isGranted) {
          return widget.child ??
              ElevatedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Permission Granted'),
              );
        }

        return ElevatedButton.icon(
          onPressed: _isRequesting ? null : _requestPermission,
          icon: _isRequesting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : const Icon(Icons.security_rounded),
          label: Text(_isRequesting ? 'Requesting...' : 'Grant Permission'),
        );
      },
    );
  }

  Future<void> _requestPermission() async {
    setState(() => _isRequesting = true);

    try {
      final granted = await PermissionService.instance.requestWithRationale(
        context: context,
        permission: widget.permission,
        title: widget.title,
        description: widget.description,
      );

      widget.onResult?.call(granted);

      if (mounted) {
        setState(() => _isRequesting = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRequesting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to request permission: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Permission guard widget
/// 
/// Shows content only if permission is granted,
/// otherwise shows request UI
class PermissionGuard extends StatelessWidget {
  final AppPermission permission;
  final Widget child;
  final Widget? deniedWidget;
  final String? title;
  final String? description;

  const PermissionGuard({
    super.key,
    required this.permission,
    required this.child,
    this.deniedWidget,
    this.title,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: PermissionService.instance.isGranted(permission),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final isGranted = snapshot.data ?? false;

        if (isGranted) {
          return child;
        }

        return deniedWidget ?? _buildDeniedWidget(context);
      },
    );
  }

  Widget _buildDeniedWidget(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_outline_rounded,
                size: 40,
                color: Colors.orange[700],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title ?? 'Permission Required',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description ?? 'This feature requires permission to continue',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            PermissionRequestButton(
              permission: permission,
              title: title,
              description: description,
              onResult: (granted) {
                if (granted && context.mounted) {
                  // Rebuild widget to show child
                  (context as Element).markNeedsBuild();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
