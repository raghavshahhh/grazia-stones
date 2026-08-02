import '../models/dealer.dart';
import '../network/api_client.dart';
import '../services/mock_data_service.dart';

class DealerRepository {
  final ApiClient _apiClient;

  DealerRepository(this._apiClient);

  Future<List<Dealer>> getDealers({
    double? latitude,
    double? longitude,
    double? radius,
  }) async {
    try {
      final response = await _apiClient.get(
        '/dealers',
        queryParameters: {
          if (latitude != null) 'lat': latitude,
          if (longitude != null) 'lng': longitude,
          if (radius != null) 'radius': radius,
        },
      );
      return (response.data['data'] as List)
          .map((json) => Dealer.fromJson(json))
          .toList();
    } catch (e) {
      return MockDataService.dealers;
    }
  }

  Future<Dealer?> getDealerById(String id) async {
    try {
      final response = await _apiClient.get('/dealers/$id');
      return Dealer.fromJson(response.data['data']);
    } catch (e) {
      try {
        return MockDataService.dealers.firstWhere((d) => d.id == id);
      } catch (_) {
        return null;
      }
    }
  }
}
