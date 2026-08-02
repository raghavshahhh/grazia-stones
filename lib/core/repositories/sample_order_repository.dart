import '../models/sample_order.dart';
import '../repositories/base_repository.dart';

class SampleOrderRepository extends BaseRepository {
  SampleOrderRepository(super.api);

  Future<List<SampleOrder>> getSampleOrders() async {
    return safeCall(() async {
      final response = await api.get('/sample-orders');
      return (response.data['data'] as List)
          .map((j) => SampleOrder.fromJson(j))
          .toList();
    });
  }

  Future<SampleOrder> requestSample({
    required String stoneId,
    required String name,
    required String phone,
    required String address,
    required String city,
    required String pincode,
    String? notes,
  }) async {
    return safeCall(() async {
      final response = await api.post('/sample-orders', data: {
        'stoneId': stoneId,
        'name': name,
        'phone': phone,
        'address': address,
        'city': city,
        'pincode': pincode,
        if (notes != null) 'notes': notes,
      });
      return SampleOrder.fromJson(response.data);
    });
  }
}
