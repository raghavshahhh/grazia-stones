import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';

/// Offline mode banner
/// 
/// Shows a persistent banner at the top when offline
class OfflineBanner extends StatelessWidget {
  final bool showQueuedCount;

  const OfflineBanner({
    super.key,
    this.showQueuedCount = true,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<NetworkStatus>(
      stream: ConnectivityService.instance.statusStream,
      initialData: ConnectivityService.instance.status,
      builder: (context, snapshot) {
        final status = snapshot.data ?? NetworkStatus.unknown;

        if (status == NetworkStatus.online) {
          return const SizedBox.shrink();
        }

        final queuedCount = ConnectivityService.instance.queuedOperationsCount;

        return Material(
          color: status == NetworkStatus.offline ? Colors.grey[800] : Colors.orange,
          child: SafeArea(
            bottom: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    status == NetworkStatus.offline
                        ? Icons.wifi_off_rounded
                        : Icons.signal_wifi_statusbar_null_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          status == NetworkStatus.offline
                              ? 'No Internet Connection'
                              : 'Connection Status Unknown',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (showQueuedCount && queuedCount > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            '$queuedCount operation${queuedCount == 1 ? '' : 's'} queued',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.info_outline_rounded,
                    color: Colors.white.withValues(alpha: 0.7),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Connectivity status indicator (small icon)
class ConnectivityIndicator extends StatelessWidget {
  final bool showLabel;
  final double iconSize;

  const ConnectivityIndicator({
    super.key,
    this.showLabel = false,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<NetworkStatus>(
      stream: ConnectivityService.instance.statusStream,
      initialData: ConnectivityService.instance.status,
      builder: (context, snapshot) {
        final status = snapshot.data ?? NetworkStatus.unknown;

        if (status == NetworkStatus.online) {
          return const SizedBox.shrink();
        }

        IconData icon;
        Color color;
        String label;

        switch (status) {
          case NetworkStatus.offline:
            icon = Icons.wifi_off_rounded;
            color = Colors.red;
            label = 'Offline';
            break;
          case NetworkStatus.unknown:
            icon = Icons.signal_wifi_statusbar_null_rounded;
            color = Colors.orange;
            label = 'Unknown';
            break;
          case NetworkStatus.online:
            icon = Icons.wifi_rounded;
            color = Colors.green;
            label = 'Online';
            break;
        }

        if (!showLabel) {
          return Icon(icon, color: color, size: iconSize);
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: iconSize),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Connectivity wrapper that shows content only when online
/// 
/// Shows offline message when no connection
class ConnectivityGuard extends StatelessWidget {
  final Widget child;
  final Widget? offlineWidget;
  final String? offlineMessage;
  final bool allowOfflineAccess;

  const ConnectivityGuard({
    super.key,
    required this.child,
    this.offlineWidget,
    this.offlineMessage,
    this.allowOfflineAccess = false,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<NetworkStatus>(
      stream: ConnectivityService.instance.statusStream,
      initialData: ConnectivityService.instance.status,
      builder: (context, snapshot) {
        final status = snapshot.data ?? NetworkStatus.unknown;

        if (status == NetworkStatus.online || allowOfflineAccess) {
          return child;
        }

        return offlineWidget ?? _buildDefaultOfflineWidget(context);
      },
    );
  }

  Widget _buildDefaultOfflineWidget(BuildContext context) {
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
                color: Colors.grey.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                size: 40,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Internet Connection',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              offlineMessage ??
                  'Please check your connection and try again.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                final isOnline = await ConnectivityService.instance.checkConnection();
                if (context.mounted) {
                  if (isOnline) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Connection restored!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Still offline. Please try again.'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sync indicator for queued operations
class SyncIndicator extends StatelessWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<NetworkStatus>(
      stream: ConnectivityService.instance.statusStream,
      initialData: ConnectivityService.instance.status,
      builder: (context, snapshot) {
        final status = snapshot.data ?? NetworkStatus.unknown;
        final queuedCount = ConnectivityService.instance.queuedOperationsCount;

        if (status == NetworkStatus.online || queuedCount == 0) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.orange.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.sync_rounded,
                  color: Colors.orange,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Pending Sync',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange[700],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$queuedCount action${queuedCount == 1 ? '' : 's'} will sync when online',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Offline mode toggle for testing
class OfflineModeToggle extends StatefulWidget {
  const OfflineModeToggle({super.key});

  @override
  State<OfflineModeToggle> createState() => _OfflineModeToggleState();
}

class _OfflineModeToggleState extends State<OfflineModeToggle> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<NetworkStatus>(
      stream: ConnectivityService.instance.statusStream,
      initialData: ConnectivityService.instance.status,
      builder: (context, snapshot) {
        final status = snapshot.data ?? NetworkStatus.unknown;
        final queuedCount = ConnectivityService.instance.queuedOperationsCount;

        return ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getStatusColor(status).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getStatusIcon(status),
              color: _getStatusColor(status),
              size: 20,
            ),
          ),
          title: const Text(
            'Network Status',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(_getStatusLabel(status)),
              if (queuedCount > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '$queuedCount queued operation${queuedCount == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ],
          ),
          trailing: status == NetworkStatus.online && queuedCount > 0
              ? TextButton(
                  onPressed: () async {
                    try {
                      await ConnectivityService.instance.syncNow();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Sync completed'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Sync failed: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Sync'),
                )
              : null,
        );
      },
    );
  }

  Color _getStatusColor(NetworkStatus status) {
    switch (status) {
      case NetworkStatus.online:
        return Colors.green;
      case NetworkStatus.offline:
        return Colors.red;
      case NetworkStatus.unknown:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(NetworkStatus status) {
    switch (status) {
      case NetworkStatus.online:
        return Icons.wifi_rounded;
      case NetworkStatus.offline:
        return Icons.wifi_off_rounded;
      case NetworkStatus.unknown:
        return Icons.signal_wifi_statusbar_null_rounded;
    }
  }

  String _getStatusLabel(NetworkStatus status) {
    switch (status) {
      case NetworkStatus.online:
        return 'Connected';
      case NetworkStatus.offline:
        return 'No connection';
      case NetworkStatus.unknown:
        return 'Status unknown';
    }
  }
}
