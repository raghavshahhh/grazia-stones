import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../../core/di.dart';
import '../../../core/models/cart_item.dart';
import '../../../core/repositories/cart_repository.dart';

/// Cart state with Supabase backend
class CartSupabaseState {
  final List<CartItem> items;
  final bool isLoading;
  final String? error;

  CartSupabaseState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  int get itemCount => items.length;
  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);
  double get subtotal => items.fold(0.0, (sum, item) => sum + item.totalPrice);
  double get gst => subtotal * 0.18;
  double get shipping => subtotal > 10000 ? 0 : 500;
  double get total => subtotal + gst + shipping;
  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  CartSupabaseState copyWith({
    List<CartItem>? items,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return CartSupabaseState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Cart notifier with Supabase backend persistence
class CartSupabaseNotifier extends StateNotifier<CartSupabaseState> {
  final CartRepository _repository;

  CartSupabaseNotifier(this._repository) : super(CartSupabaseState()) {
    _loadCart();
  }

  /// Load cart from Supabase on init
  Future<void> _loadCart() async {
    try {
      state = state.copyWith(isLoading: true, clearError: true);
      final items = await _repository.getCartItems();
      state = state.copyWith(items: items, isLoading: false);
      debugPrint('✅ Cart loaded: ${items.length} items');
    } catch (e) {
      debugPrint('❌ Error loading cart: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Refresh cart from server
  Future<void> refresh() async {
    await _loadCart();
  }

  /// Add item to cart
  Future<void> addItem({
    required String stoneId,
    required String stoneName,
    required double pricePerSqFt,
    String finish = 'Polished',
    int quantity = 1,
    String? colorHex,
  }) async {
    try {
      state = state.copyWith(clearError: true);
      
      // CartRepository.addToCart handles price lookup from Supabase directly.
      // stoneName, pricePerSqFt, finish, colorHex are stored locally in optimistic
      // UI but the server authoritative price comes from the stones table.
      await _repository.addToCart(
        stoneId,
        quantity,
      );
      
      // Reload to get updated cart
      await _loadCart();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      debugPrint('❌ Error adding to cart: $e');
      rethrow;
    }
  }

  /// Update item quantity
  Future<void> updateQuantity(String cartItemId, int newQuantity) async {
    if (newQuantity < 0) return;

    // Optimistic update
    final previousItems = state.items;
    final updatedItems = state.items.map((item) {
      if (item.id == cartItemId) {
        return item.copyWith(quantity: newQuantity);
      }
      return item;
    }).toList();

    state = state.copyWith(items: updatedItems, clearError: true);

    try {
      await _repository.updateCartItem(cartItemId, newQuantity);
    } catch (e) {
      // Rollback on error
      state = state.copyWith(
        items: previousItems,
        error: e.toString(),
      );
      debugPrint('❌ Error updating quantity: $e');
      rethrow;
    }
  }

  /// Remove item from cart
  Future<void> removeItem(String cartItemId) async {
    // Optimistic update
    final previousItems = state.items;
    final updatedItems = state.items.where((item) => item.id != cartItemId).toList();

    state = state.copyWith(items: updatedItems, clearError: true);

    try {
      await _repository.removeFromCart(cartItemId);
    } catch (e) {
      // Rollback on error
      state = state.copyWith(
        items: previousItems,
        error: e.toString(),
      );
      debugPrint('❌ Error removing from cart: $e');
      rethrow;
    }
  }

  /// Clear entire cart
  Future<void> clear() async {
    final previousItems = state.items;

    // Optimistic update
    state = state.copyWith(items: [], clearError: true);

    try {
      await _repository.clearCart();
      debugPrint('✅ Cart cleared');
    } catch (e) {
      // Rollback on error
      state = state.copyWith(
        items: previousItems,
        error: e.toString(),
      );
      debugPrint('❌ Error clearing cart: $e');
      rethrow;
    }
  }

  /// Increment item quantity
  Future<void> incrementQuantity(String cartItemId) async {
    final item = state.items.firstWhere((i) => i.id == cartItemId);
    await updateQuantity(cartItemId, item.quantity + 1);
  }

  /// Decrement item quantity (removes if quantity becomes 0)
  Future<void> decrementQuantity(String cartItemId) async {
    final item = state.items.firstWhere((i) => i.id == cartItemId);
    if (item.quantity <= 1) {
      await removeItem(cartItemId);
    } else {
      await updateQuantity(cartItemId, item.quantity - 1);
    }
  }
}

/// Provider for Supabase-backed cart
final cartSupabaseProvider = StateNotifierProvider<CartSupabaseNotifier, CartSupabaseState>(
  (ref) => CartSupabaseNotifier(ref.watch(cartRepositoryProvider)),
);
