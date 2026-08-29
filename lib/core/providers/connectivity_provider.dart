import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/connectivity_service.dart';

/// Provider for ConnectivityService instance
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService.instance;
});

/// Stream provider for network status
final networkStatusProvider = StreamProvider<NetworkStatus>((ref) {
  return ConnectivityService.instance.statusStream;
});

/// Provider for current network status (synchronous)
final currentNetworkStatusProvider = Provider<NetworkStatus>((ref) {
  return ConnectivityService.instance.status;
});

/// Provider for online/offline state
final isOnlineProvider = Provider<bool>((ref) {
  final status = ref.watch(currentNetworkStatusProvider);
  return status == NetworkStatus.online;
});

/// Provider for queued operations count
final queuedOperationsCountProvider = Provider<int>((ref) {
  // Listen to network status to trigger rebuild when status changes
  ref.watch(networkStatusProvider);
  return ConnectivityService.instance.queuedOperationsCount;
});
