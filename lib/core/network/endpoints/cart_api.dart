import '../../models/cart_item.dart';
import '../api_service.dart';
import '../api_response.dart';

/// Cart-related API endpoints
class CartApi {
  final ApiService _api = ApiService.instance;

  // ═══════════════════════════════════════════════════════════════════════
  // CART MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════

  /// Get user's cart
  Future<List<CartItem>> getCart() async {
    final response = await _api.get<Map<String, dynamic>>('/cart');
    
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.errorMessage);
    }
    
    final data = response.data!['data'] as List;
    return data.map((json) => CartItem.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Add item to cart
  Future<bool> addToCart({
    required String stoneId,
    required int quantity,
    required String finish,
    String? colorHex,
  }) async {
    final response = await _api.post(
      '/cart',
      data: {
        'stone_id': stoneId,
        'quantity': quantity,
        'finish': finish,
        if (colorHex != null) 'color_hex': colorHex,
      },
    );
    
    return response.isSuccess;
  }

  /// Update cart item quantity
  Future<bool> updateCartItem({
    required String cartItemId,
    required int quantity,
  }) async {
    final response = await _api.put(
      '/cart/$cartItemId',
      data: {'quantity': quantity},
    );
    
    return response.isSuccess;
  }

  /// Remove item from cart
  Future<bool> removeFromCart(String cartItemId) async {
    final response = await _api.delete('/cart/$cartItemId');
    return response.isSuccess;
  }

  /// Clear entire cart
  Future<bool> clearCart() async {
    final response = await _api.delete('/cart');
    return response.isSuccess;
  }

  /// Get cart summary (totals)
  Future<Map<String, dynamic>> getCartSummary() async {
    final response = await _api.get<Map<String, dynamic>>('/cart/summary');
    
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.errorMessage);
    }
    
    return response.data!;
  }

  /// Apply coupon code
  Future<Map<String, dynamic>> applyCoupon(String couponCode) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/cart/coupon',
      data: {'coupon_code': couponCode},
    );
    
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.errorMessage);
    }
    
    return response.data!;
  }

  /// Remove coupon
  Future<bool> removeCoupon() async {
    final response = await _api.delete('/cart/coupon');
    return response.isSuccess;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // CHECKOUT
  // ═══════════════════════════════════════════════════════════════════════

  /// Create order from cart
  Future<Map<String, dynamic>> checkout({
    required String addressId,
    required String paymentMethod,
    String? notes,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/cart/checkout',
      data: {
        'address_id': addressId,
        'payment_method': paymentMethod,
        if (notes != null) 'notes': notes,
      },
    );
    
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.errorMessage);
    }
    
    return response.data!;
  }

  /// Validate cart before checkout
  Future<Map<String, dynamic>> validateCart() async {
    final response = await _api.get<Map<String, dynamic>>('/cart/validate');
    
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.errorMessage);
    }
    
    return response.data!;
  }
}
