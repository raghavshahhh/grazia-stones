import '../models/order.dart';
import '../repositories/base_repository.dart';

class OrderRepository extends BaseRepository {
  OrderRepository(super.api);

  Future<List<Order>> getOrders() async {
    return safeCall(() async {
      final response = await api.get('/orders');
      return (response.data['data'] as List)
          .map((j) => Order.fromJson(j))
          .toList();
    });
  }

  Future<Order> getOrderById(String id) async {
    return safeCall(() async {
      final response = await api.get('/orders/$id');
      return Order.fromJson(response.data);
    });
  }

  Future<Order> createOrder({
    required String shippingAddress,
    required String paymentMethod,
    String? notes,
  }) async {
    return safeCall(() async {
      final response = await api.post('/orders', data: {
        'shippingAddress': shippingAddress,
        'paymentMethod': paymentMethod,
        if (notes != null) 'notes': notes,
      });
      return Order.fromJson(response.data);
    });
  }

  Future<void> cancelOrder(String orderId) async {
    await safeCall(() async {
      await api.post('/orders/$orderId/cancel');
    });
  }
}
