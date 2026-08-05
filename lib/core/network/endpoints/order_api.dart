import '../../models/order.dart';
import '../api_service.dart';
import '../api_response.dart';

/// Order-related API endpoints
class OrderApi {
  final ApiService _api = ApiService.instance;

  // ═══════════════════════════════════════════════════════════════════════
  // ORDERS
  // ═══════════════════════════════════════════════════════════════════════

  /// Get user's orders
  Future<List<Order>> getOrders({
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (status != null) 'status': status,
    };

    final response = await _api.get<Map<String, dynamic>>(
      '/orders',
      queryParameters: queryParams,
    );
    
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.errorMessage);
    }
    
    final data = response.data!['data'] as List;
    return data.map((json) => Order.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Get order by ID
  Future<Order> getOrderById(String orderId) async {
    final response = await _api.get<Map<String, dynamic>>('/orders/$orderId');
    
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.errorMessage);
    }
    
    return Order.fromJson(response.data!);
  }

  /// Create new order
  Future<Order> createOrder({
    required List<Map<String, dynamic>> items,
    required String addressId,
    required String paymentMethod,
    String? couponCode,
    String? notes,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/orders',
      data: {
        'items': items,
        'address_id': addressId,
        'payment_method': paymentMethod,
        if (couponCode != null) 'coupon_code': couponCode,
        if (notes != null) 'notes': notes,
      },
    );
    
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.errorMessage);
    }
    
    return Order.fromJson(response.data!);
  }

  /// Cancel order
  Future<bool> cancelOrder(String orderId, {String? reason}) async {
    final response = await _api.post(
      '/orders/$orderId/cancel',
      data: {
        if (reason != null) 'reason': reason,
      },
    );
    
    return response.isSuccess;
  }

  /// Track order
  Future<Map<String, dynamic>> trackOrder(String orderId) async {
    final response = await _api.get<Map<String, dynamic>>('/orders/$orderId/track');
    
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.errorMessage);
    }
    
    return response.data!;
  }

  /// Get order invoice
  Future<String> getOrderInvoice(String orderId) async {
    final response = await _api.get<Map<String, dynamic>>('/orders/$orderId/invoice');
    
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.errorMessage);
    }
    
    return response.data!['invoice_url'] as String;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SAMPLE ORDERS
  // ═══════════════════════════════════════════════════════════════════════

  /// Request sample order
  Future<Map<String, dynamic>> requestSample({
    required String stoneId,
    required String addressId,
    String? notes,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/orders/samples',
      data: {
        'stone_id': stoneId,
        'address_id': addressId,
        if (notes != null) 'notes': notes,
      },
    );
    
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.errorMessage);
    }
    
    return response.data!;
  }

  /// Get sample orders
  Future<List<Map<String, dynamic>>> getSampleOrders() async {
    final response = await _api.get<Map<String, dynamic>>('/orders/samples');
    
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.errorMessage);
    }
    
    final data = response.data!['data'] as List;
    return data.cast<Map<String, dynamic>>();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PAYMENT
  // ═══════════════════════════════════════════════════════════════════════

  /// Initiate payment for order
  Future<Map<String, dynamic>> initiatePayment({
    required String orderId,
    required String paymentMethod,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/orders/$orderId/payment',
      data: {'payment_method': paymentMethod},
    );
    
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.errorMessage);
    }
    
    return response.data!;
  }

  /// Verify payment
  Future<bool> verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    final response = await _api.post(
      '/orders/$orderId/payment/verify',
      data: {
        'payment_id': paymentId,
        'signature': signature,
      },
    );
    
    return response.isSuccess;
  }

  /// Payment failed callback
  Future<bool> paymentFailed({
    required String orderId,
    required String reason,
  }) async {
    final response = await _api.post(
      '/orders/$orderId/payment/failed',
      data: {'reason': reason},
    );
    
    return response.isSuccess;
  }
}
