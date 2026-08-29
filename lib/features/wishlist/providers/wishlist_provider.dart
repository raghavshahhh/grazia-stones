import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../../core/di.dart';
import '../data/wishlist_repository.dart';

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

/// Wishlist notifier with Supabase backend persistence
class WishlistNotifier extends StateNotifier<WishlistState> {
  final WishlistRepository _repository;

  WishlistNotifier(this._repository) : super(WishlistState()) {
    _loadWishlist();
  }

  /// Load wishlist from Supabase on init
  Future<void> _loadWishlist() async {
    try {
      state = state.copyWith(isLoading: true, clearError: true);
      final stoneIds = await _repository.getWishlistStoneIds();
      state = state.copyWith(stoneIds: stoneIds, isLoading: false);
      debugPrint('✅ Wishlist loaded: ${stoneIds.length} items');
    } catch (e) {
      debugPrint('ℹ️ Wishlist guest / unauthenticated: $e');
      state = state.copyWith(
        stoneIds: [],
        isLoading: false,
        clearError: true,
      );
    }
  }

  /// Reload wishlist from server
  Future<void> refresh() async {
    await _loadWishlist();
  }

  /// Add stone to wishlist
  Future<void> addStone(String stoneId) async {
    if (state.stoneIds.contains(stoneId)) return;

    // Optimistic update
    state = state.copyWith(
      stoneIds: [...state.stoneIds, stoneId],
      clearError: true,
    );
    
    try {
      await _repository.addToWishlist(stoneId);
    } catch (e) {
      // Rollback on error
      state = state.copyWith(
        stoneIds: state.stoneIds.where((id) => id != stoneId).toList(),
        error: e.toString(),
      );
      debugPrint('❌ Error adding to wishlist: $e');
      rethrow;
    }
  }

  /// Remove stone from wishlist
  Future<void> removeStone(String stoneId) async {
    final previousIds = state.stoneIds;
    
    // Optimistic update
    state = state.copyWith(
      stoneIds: state.stoneIds.where((id) => id != stoneId).toList(),
      clearError: true,
    );
    
    try {
      await _repository.removeFromWishlist(stoneId);
    } catch (e) {
      // Rollback on error
      state = state.copyWith(
        stoneIds: previousIds,
        error: e.toString(),
      );
      debugPrint('❌ Error removing from wishlist: $e');
      rethrow;
    }
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
    final previousIds = state.stoneIds;
    
    // Optimistic update
    state = state.copyWith(
      stoneIds: state.stoneIds
          .where((id) => !stoneIds.contains(id))
          .toList(),
      clearError: true,
    );
    
    try {
      await _repository.removeMultiple(stoneIds);
    } catch (e) {
      // Rollback on error
      state = state.copyWith(
        stoneIds: previousIds,
        error: e.toString(),
      );
      debugPrint('❌ Error removing multiple from wishlist: $e');
      rethrow;
    }
  }

  /// Clear entire wishlist
  Future<void> clear() async {
    final previousIds = state.stoneIds;
    
    // Optimistic update
    state = state.copyWith(stoneIds: [], clearError: true);
    
    try {
      await _repository.clearWishlist();
      debugPrint('✅ Wishlist cleared');
    } catch (e) {
      // Rollback on error
      state = state.copyWith(
        stoneIds: previousIds,
        error: e.toString(),
      );
      debugPrint('❌ Error clearing wishlist: $e');
      rethrow;
    }
  }

  /// Check if stone is in wishlist
  bool contains(String stoneId) => state.stoneIds.contains(stoneId);
}

/// Provider for wishlist
final wishlistProvider = StateNotifierProvider<WishlistNotifier, WishlistState>(
  (ref) => WishlistNotifier(ref.watch(wishlistRepositoryProvider)),
);
