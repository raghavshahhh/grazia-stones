import '../models/order.dart';
import '../repositories/base_repository.dart';
import '../network/endpoints/order_api.dart';

class OrderRepository extends BaseRepository {
  OrderRepository(super.api);
  
  final OrderApi _orderApi = OrderApi();

  // ═══════════════════════════════════════════════════════════════════════
  // ORDERS
  // ═══════════════════════════════════════════════════════════════════════

  Future<List<Order>> getOrders({
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    return safeCall(() async {
      return await _orderApi.getOrders(
        page: page,
        limit: limit,
        status: status,
      );
    });
  }

  Future<Order> getOrderById(String id) async {
    return safeCall(() async {
      return await _orderApi.getOrderById(id);
    });
  }

  Future<Order> createOrder({
    required List<Map<String, dynamic>> items,
    required String addressId,
    required String paymentMethod,
    String? couponCode,
    String? notes,
  }) async {
    return safeCall(() async {
      return await _orderApi.createOrder(
        items: items,
        addressId: addressId,
        paymentMethod: paymentMethod,
        couponCode: couponCode,
        notes: notes,
      );
    });
  }

  Future<void> cancelOrder(String orderId, {String? reason}) async {
    await safeCall(() async {
      await _orderApi.cancelOrder(orderId, reason: reason);
    });
  }

  Future<Map<String, dynamic>> trackOrder(String orderId) async {
    return safeCall(() async {
      return await _orderApi.trackOrder(orderId);
    });
  }

  Future<String> getOrderInvoice(String orderId) async {
    return safeCall(() async {
      return await _orderApi.getOrderInvoice(orderId);
    });
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SAMPLE ORDERS
  // ═══════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> requestSample({
    required String stoneId,
    required String addressId,
    String? notes,
  }) async {
    return safeCall(() async {
      return await _orderApi.requestSample(
        stoneId: stoneId,
        addressId: addressId,
        notes: notes,
      );
    });
  }

  Future<List<Map<String, dynamic>>> getSampleOrders() async {
    return safeCall(() async {
      return await _orderApi.getSampleOrders();
    });
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PAYMENT
  // ═══════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> initiatePayment({
    required String orderId,
    required String paymentMethod,
  }) async {
    return safeCall(() async {
      return await _orderApi.initiatePayment(
        orderId: orderId,
        paymentMethod: paymentMethod,
      );
    });
  }

  Future<bool> verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    return safeCall(() async {
      return await _orderApi.verifyPayment(
        orderId: orderId,
        paymentId: paymentId,
        signature: signature,
      );
    });
  }

  Future<bool> paymentFailed({
    required String orderId,
    required String reason,
  }) async {
    return safeCall(() async {
      return await _orderApi.paymentFailed(
        orderId: orderId,
        reason: reason,
      );
    });
  }
}
