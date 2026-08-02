import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/cart_item.dart';
import '../../../core/models/stone.dart';
import '../../../core/repositories/cart_repository.dart';

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

  CartRiverpodNotifier([this._repo]) : super(CartRiverpodState());

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
  }

  void removeItem(String stoneId) {
    state = state.copyWith(
      items: state.items.where((i) => i.stoneId != stoneId).toList(),
    );
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
  }

  void clear() {
    state = state.copyWith(items: []);
  }

  // ─── API methods ───
  Future<void> loadCart() async {
    if (_repo == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final items = await _repo!.getCartItems();
      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> syncToServer() async {
    if (_repo == null) return;
    for (final item in state.items) {
      await _repo!.addToCart(item.stoneId, item.quantity);
    }
  }
}
