import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../../core/models/cart_item.dart';
import '../../../core/models/stone.dart';
import '../../../core/repositories/cart_repository.dart';
import '../../../core/services/storage_service.dart';

// ─── State ───
class CartRiverpodState {
  final List<CartItem> items;
  final bool isLoading;
  final String? error;

  CartRiverpodState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  int get itemCount => items.length;
  double get total => items.fold(0, (sum, item) => sum + item.totalPrice);
  bool get isEmpty => items.isEmpty;

  CartRiverpodState copyWith({
    List<CartItem>? items,
    bool? isLoading,
    String? error,
  }) {
    return CartRiverpodState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ─── Notifier ───
class CartRiverpodNotifier extends StateNotifier<CartRiverpodState> {
  final CartRepository? _repo;
  final StorageService _storage = StorageService.instance;

  CartRiverpodNotifier([this._repo]) : super(CartRiverpodState()) {
    // Load cart from storage on initialization
    _loadPersistedCart();
  }

  /// Load cart from local storage on app start
  Future<void> _loadPersistedCart() async {
    try {
      final cartData = _storage.getCart();
      if (cartData.isEmpty) return;

      // Convert stored data back to CartItem objects
      final items = cartData.map((data) {
        return CartItem(
          stoneId: data['stoneId'] as String,
          name: data['name'] as String,
          finish: data['finish'] as String? ?? 'Polished',
          pricePerSqFt: (data['pricePerSqFt'] as num).toDouble(),
          quantity: data['quantity'] as int,
          colorHex: data['colorHex'] as String? ?? '#1C1C1E',
        );
      }).toList();

      state = state.copyWith(items: items);
      debugPrint('✅ Cart restored from storage: ${items.length} items');
    } catch (e) {
      debugPrint('❌ Error loading cart from storage: $e');
    }
  }

  /// Save cart to local storage
  Future<void> _persistCart() async {
    try {
      final cartData = state.items.map((item) => {
        'stoneId': item.stoneId,
        'name': item.name,
        'finish': item.finish,
        'pricePerSqFt': item.pricePerSqFt,
        'quantity': item.quantity,
        'colorHex': item.colorHex,
      }).toList();

      await _storage.saveCart(cartData);
      debugPrint('✅ Cart saved to storage: ${cartData.length} items');
    } catch (e) {
      debugPrint('❌ Error saving cart to storage: $e');
    }
  }

  void addItem(Stone stone, {String finish = 'Polished', int quantity = 1, String colorHex = '#1C1C1E'}) {
    final existingIndex = state.items.indexWhere((i) => i.stoneId == stone.id);
    if (existingIndex >= 0) {
      final updated = [...state.items];
      updated[existingIndex] = updated[existingIndex].copyWith(
        quantity: updated[existingIndex].quantity + quantity,
      );
      state = state.copyWith(items: updated);
    } else {
      state = state.copyWith(
        items: [
          ...state.items,
          CartItem(
            stoneId: stone.id,
            name: stone.name,
            finish: finish,
            pricePerSqFt: stone.pricePerSqFt,
            quantity: quantity,
            colorHex: colorHex,
          ),
        ],
      );
    }
    
    // Persist after adding
    _persistCart();
  }

  void removeItem(String stoneId) {
    state = state.copyWith(
      items: state.items.where((i) => i.stoneId != stoneId).toList(),
    );
    
    // Persist after removing
    _persistCart();
  }

  void updateQuantity(String stoneId, int quantity) {
    if (quantity <= 0) {
      removeItem(stoneId);
      return;
    }
    final updated = state.items.map((item) {
      if (item.stoneId == stoneId) {
        return item.copyWith(quantity: quantity);
      }
      return item;
    }).toList();
    state = state.copyWith(items: updated);
    
    // Persist after updating
    _persistCart();
  }

  Future<void> clear() async {
    state = state.copyWith(items: []);
    
    // Clear from storage
    await _storage.clearCart();
    debugPrint('✅ Cart cleared');
  }

  // ─── API methods ───
  Future<void> loadCart() async {
    if (_repo == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final items = await _repo.getCartItems();
      state = state.copyWith(items: items, isLoading: false);
      
      // Persist after loading from server
      _persistCart();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      debugPrint('❌ Error loading cart from server: $e');
    }
  }

  Future<void> syncToServer() async {
    if (_repo == null) return;
    try {
      for (final item in state.items) {
        await _repo.addToCart(item.stoneId, item.quantity);
      }
      debugPrint('✅ Cart synced to server');
    } catch (e) {
      debugPrint('❌ Error syncing cart to server: $e');
    }
  }

  /// Manual save (can be called when needed)
  Future<void> save() async {
    await _persistCart();
  }
}
