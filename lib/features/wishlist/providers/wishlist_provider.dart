import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../../core/services/storage_service.dart';

/// Wishlist state
class WishlistState {
  final List<String> stoneIds;
  final bool isLoading;
  final String? error;

  WishlistState({
    this.stoneIds = const [],
    this.isLoading = false,
    this.error,
  });

  bool contains(String stoneId) => stoneIds.contains(stoneId);
  int get count => stoneIds.length;
  bool get isEmpty => stoneIds.isEmpty;
  bool get isNotEmpty => stoneIds.isNotEmpty;

  WishlistState copyWith({
    List<String>? stoneIds,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return WishlistState(
      stoneIds: stoneIds ?? this.stoneIds,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Wishlist notifier with persistence
class WishlistNotifier extends StateNotifier<WishlistState> {
  final StorageService _storage = StorageService.instance;

  WishlistNotifier() : super(WishlistState()) {
    _loadPersistedWishlist();
  }

  /// Load wishlist from storage on init
  Future<void> _loadPersistedWishlist() async {
    try {
      final stoneIds = _storage.getWishlist();
      state = state.copyWith(stoneIds: stoneIds);
      debugPrint('✅ Wishlist restored: ${stoneIds.length} items');
    } catch (e) {
      debugPrint('❌ Error loading wishlist: $e');
    }
  }

  /// Save wishlist to storage
  Future<void> _persistWishlist() async {
    try {
      await _storage.saveWishlist(state.stoneIds);
      debugPrint('✅ Wishlist saved: ${state.stoneIds.length} items');
    } catch (e) {
      debugPrint('❌ Error saving wishlist: $e');
    }
  }

  /// Add stone to wishlist
  Future<void> addStone(String stoneId) async {
    if (state.stoneIds.contains(stoneId)) return;

    state = state.copyWith(
      stoneIds: [...state.stoneIds, stoneId],
    );
    
    await _persistWishlist();
  }

  /// Remove stone from wishlist
  Future<void> removeStone(String stoneId) async {
    state = state.copyWith(
      stoneIds: state.stoneIds.where((id) => id != stoneId).toList(),
    );
    
    await _persistWishlist();
  }

  /// Toggle stone in wishlist
  Future<void> toggleStone(String stoneId) async {
    if (state.stoneIds.contains(stoneId)) {
      await removeStone(stoneId);
    } else {
      await addStone(stoneId);
    }
  }

  /// Remove multiple stones
  Future<void> removeMultiple(List<String> stoneIds) async {
    state = state.copyWith(
      stoneIds: state.stoneIds
          .where((id) => !stoneIds.contains(id))
          .toList(),
    );
    
    await _persistWishlist();
  }

  /// Clear entire wishlist
  Future<void> clear() async {
    state = state.copyWith(stoneIds: []);
    await _storage.clearWishlist();
    debugPrint('✅ Wishlist cleared');
  }

  /// Check if stone is in wishlist
  bool contains(String stoneId) => state.stoneIds.contains(stoneId);
}

/// Provider for wishlist
final wishlistProvider = StateNotifierProvider<WishlistNotifier, WishlistState>(
  (ref) => WishlistNotifier(),
);
