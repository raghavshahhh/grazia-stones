import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/wishlist_item.dart';
import '../../../core/repositories/wishlist_repository.dart';

// ─── State ───
class WishlistRiverpodState {
  final List<WishlistItem> items;
  final bool isLoading;
  final String? error;

  WishlistRiverpodState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  int get count => items.length;
  bool get isEmpty => items.isEmpty;

  WishlistRiverpodState copyWith({
    List<WishlistItem>? items,
    bool? isLoading,
    String? error,
  }) {
    return WishlistRiverpodState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ─── Notifier ───
class WishlistRiverpodNotifier extends StateNotifier<WishlistRiverpodState> {
  final WishlistRepository? _repo;

  WishlistRiverpodNotifier([this._repo]) : super(WishlistRiverpodState());

  void addItem(WishlistItem item) {
    if (state.items.any((i) => i.id == item.id)) return;
    state = state.copyWith(items: [...state.items, item]);
  }

  void removeItem(String itemId) {
    state = state.copyWith(
      items: state.items.where((i) => i.id != itemId).toList(),
    );
  }

  bool isWishlisted(String stoneId) {
    return state.items.any((i) => i.stone.id == stoneId);
  }

  void toggle(String stoneId, WishlistItem Function() creator) {
    if (isWishlisted(stoneId)) {
      final item = state.items.firstWhere((i) => i.stone.id == stoneId);
      removeItem(item.id);
    } else {
      addItem(creator());
    }
  }

  // ─── API methods ───
  Future<void> loadWishlist() async {
    final repo = _repo;
    if (repo == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final items = await repo.getWishlist();
      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> addToWishlist(String stoneId) async {
    final repo = _repo;
    if (repo == null) return;
    try {
      await repo.addToWishlist(stoneId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> removeFromWishlist(String itemId) async {
    final repo = _repo;
    if (repo == null) return;
    try {
      await repo.removeFromWishlist(itemId);
      removeItem(itemId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> moveToCart(String itemId) async {
    final repo = _repo;
    if (repo == null) return;
    try {
      await repo.moveToCart(itemId);
      removeItem(itemId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}
