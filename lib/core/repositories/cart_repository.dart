import '../models/cart_item.dart';
import '../repositories/base_repository.dart';
import '../network/endpoints/cart_api.dart';

class CartRepository extends BaseRepository {
  CartRepository(super.api);
  
  final CartApi _cartApi = CartApi();

  // ═══════════════════════════════════════════════════════════════════════
  // CART MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════

  Future<List<CartItem>> getCartItems() async {
    return safeCall(() async {
      return await _cartApi.getCart();
    });
  }

  Future<void> addToCart(
    String stoneId,
    int quantity, {
    String finish = 'Polished',
    String? colorHex,
  }) async {
    await safeCall(() async {
      await _cartApi.addToCart(
        stoneId: stoneId,
        quantity: quantity,
        finish: finish,
        colorHex: colorHex,
      );
    });
  }

  Future<void> updateCartItem(String itemId, int quantity) async {
    await safeCall(() async {
      await _cartApi.updateCartItem(
        cartItemId: itemId,
        quantity: quantity,
      );
    });
  }

  Future<void> removeFromCart(String itemId) async {
    await safeCall(() async {
      await _cartApi.removeFromCart(itemId);
    });
  }

  Future<void> clearCart() async {
    await safeCall(() async {
      await _cartApi.clearCart();
    });
  }

  // ═══════════════════════════════════════════════════════════════════════
  // CART SUMMARY
  // ═══════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getCartSummary() async {
    return safeCall(() async {
      return await _cartApi.getCartSummary();
    });
  }

  // ═══════════════════════════════════════════════════════════════════════
  // COUPONS
  // ═══════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> applyCoupon(String couponCode) async {
    return safeCall(() async {
      return await _cartApi.applyCoupon(couponCode);
    });
  }

  Future<void> removeCoupon() async {
    await safeCall(() async {
      await _cartApi.removeCoupon();
    });
  }

  // ═══════════════════════════════════════════════════════════════════════
  // CHECKOUT
  // ═══════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> checkout({
    required String addressId,
    required String paymentMethod,
    String? notes,
  }) async {
    return safeCall(() async {
      return await _cartApi.checkout(
        addressId: addressId,
        paymentMethod: paymentMethod,
        notes: notes,
      );
    });
  }

  Future<Map<String, dynamic>> validateCart() async {
    return safeCall(() async {
      return await _cartApi.validateCart();
    });
  }
}
