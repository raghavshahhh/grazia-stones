import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

/// Network connectivity status
enum NetworkStatus {
  online,
  offline,
  unknown,
}

/// Connectivity service for monitoring network status
/// 
/// Features:
/// - Real-time connectivity monitoring
/// - Stream-based status updates
/// - Internet reachability checks (not just connection type)
/// - Offline operation queue
/// - Automatic sync on reconnection
class ConnectivityService {
  static ConnectivityService? _instance;
  static ConnectivityService get instance => _instance ??= ConnectivityService._();

  ConnectivityService._() {
    _init();
  }

  final Connectivity _connectivity = Connectivity();
  final InternetConnectionChecker _connectionChecker = InternetConnectionChecker.instance;

  NetworkStatus _currentStatus = NetworkStatus.unknown;
  final _statusController = StreamController<NetworkStatus>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<InternetConnectionStatus>? _connectionSubscription;

  // Offline operation queue
  final List<OfflineOperation> _operationQueue = [];
  bool _isSyncing = false;

  // ═══════════════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════════════════════════════════════════

  void _init() {
    // Listen to connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
      onError: (error) {
        debugPrint('❌ Connectivity error: $error');
      },
    );

    // Listen to internet connection status
    _connectionSubscription = _connectionChecker.onStatusChange.listen(
      _onConnectionStatusChanged,
      onError: (error) {
        debugPrint('❌ Connection checker error: $error');
      },
    );

    // Check initial status
    _checkInitialStatus();
  }

  Future<void> _checkInitialStatus() async {
    try {
      final hasConnection = await _connectionChecker.hasConnection;
      _updateStatus(hasConnection ? NetworkStatus.online : NetworkStatus.offline);
    } catch (e) {
      debugPrint('❌ Error checking initial connectivity: $e');
      _updateStatus(NetworkStatus.unknown);
    }
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.none)) {
      _updateStatus(NetworkStatus.offline);
    } else {
      // Has connectivity, but check if there's actual internet
      _checkInternetConnection();
    }
  }

  void _onConnectionStatusChanged(InternetConnectionStatus status) {
    switch (status) {
      case InternetConnectionStatus.connected:
        _updateStatus(NetworkStatus.online);
        break;
      case InternetConnectionStatus.disconnected:
      default:
        _updateStatus(NetworkStatus.offline);
        break;
    }
  }


  Future<void> _checkInternetConnection() async {
    try {
      final hasConnection = await _connectionChecker.hasConnection;
      _updateStatus(hasConnection ? NetworkStatus.online : NetworkStatus.offline);
    } catch (e) {
      debugPrint('❌ Error checking internet connection: $e');
    }
  }

  void _updateStatus(NetworkStatus status) {
    if (_currentStatus != status) {
      _currentStatus = status;
      _statusController.add(status);

      debugPrint('📡 Network status changed: $status');

      // Sync offline operations when coming back online
      if (status == NetworkStatus.online) {
        _syncOfflineOperations();
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get current network status
  NetworkStatus get status => _currentStatus;

  /// Check if currently online
  bool get isOnline => _currentStatus == NetworkStatus.online;

  /// Check if currently offline
  bool get isOffline => _currentStatus == NetworkStatus.offline;

  /// Stream of network status changes
  Stream<NetworkStatus> get statusStream => _statusController.stream;

  /// Check internet connection status (single check)
  Future<bool> checkConnection() async {
    try {
      return await _connectionChecker.hasConnection;
    } catch (e) {
      debugPrint('❌ Error checking connection: $e');
      return false;
    }
  }

  /// Get connection type (wifi, mobile, etc.)
  Future<List<ConnectivityResult>> getConnectivityResults() async {
    return await _connectivity.checkConnectivity();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // OFFLINE OPERATIONS QUEUE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Queue an operation to be executed when online
  void queueOperation(OfflineOperation operation) {
    _operationQueue.add(operation);
    debugPrint('📦 Queued offline operation: ${operation.id} (${_operationQueue.length} total)');
  }

  /// Get queued operations count
  int get queuedOperationsCount => _operationQueue.length;

  /// Get all queued operations
  List<OfflineOperation> get queuedOperations => List.unmodifiable(_operationQueue);

  /// Clear all queued operations
  void clearQueue() {
    _operationQueue.clear();
    debugPrint('🗑️ Cleared offline operation queue');
  }

  /// Remove specific operation from queue
  void removeOperation(String id) {
    _operationQueue.removeWhere((op) => op.id == id);
    debugPrint('🗑️ Removed operation from queue: $id');
  }

  /// Sync all queued operations
  Future<void> _syncOfflineOperations() async {
    if (_isSyncing || _operationQueue.isEmpty) {
      return;
    }

    _isSyncing = true;
    debugPrint('🔄 Syncing ${_operationQueue.length} offline operations...');

    final operations = List<OfflineOperation>.from(_operationQueue);
    _operationQueue.clear();

    int successCount = 0;
    int failureCount = 0;

    for (final operation in operations) {
      try {
        await operation.execute();
        successCount++;
        debugPrint('✅ Synced operation: ${operation.id}');
      } catch (e) {
        failureCount++;
        debugPrint('❌ Failed to sync operation ${operation.id}: $e');
        
        // Re-queue if should retry
        if (operation.shouldRetry) {
          _operationQueue.add(operation);
        }
      }
    }

    _isSyncing = false;
    debugPrint('🔄 Sync complete: $successCount succeeded, $failureCount failed');
  }

  /// Manually trigger sync
  Future<void> syncNow() async {
    if (isOffline) {
      throw Exception('Cannot sync while offline');
    }
    await _syncOfflineOperations();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CLEANUP
  // ═══════════════════════════════════════════════════════════════════════════

  /// Dispose of resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectionSubscription?.cancel();
    _statusController.close();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// OFFLINE OPERATION
// ═══════════════════════════════════════════════════════════════════════════

/// Represents an operation to be executed when online
class OfflineOperation {
  final String id;
  final String description;
  final Future<void> Function() execute;
  final bool shouldRetry;
  final DateTime queuedAt;

  OfflineOperation({
    required this.id,
    required this.description,
    required this.execute,
    this.shouldRetry = true,
  }) : queuedAt = DateTime.now();

  @override
  String toString() => 'OfflineOperation(id: $id, description: $description)';
}
