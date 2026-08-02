import '../models/cart_item.dart';
import '../repositories/base_repository.dart';

class CartRepository extends BaseRepository {
  CartRepository(super.api);

  Future<List<CartItem>> getCartItems() async {
    return safeCall(() async {
      final response = await api.get('/cart');
      return (response.data['data'] as List)
          .map((j) => CartItem.fromJson(j))
          .toList();
    });
  }

  Future<void> addToCart(String stoneId, int quantity) async {
    await safeCall(() async {
      await api.post('/cart/items', data: {
        'stoneId': stoneId,
        'quantity': quantity,
      });
    });
  }

  Future<void> updateCartItem(String itemId, int quantity) async {
    await safeCall(() async {
      await api.put('/cart/items/$itemId', data: {
        'quantity': quantity,
      });
    });
  }

  Future<void> removeFromCart(String itemId) async {
    await safeCall(() async {
      await api.delete('/cart/items/$itemId');
    });
  }

  Future<void> clearCart() async {
    await safeCall(() async {
      await api.delete('/cart');
    });
  }
}
