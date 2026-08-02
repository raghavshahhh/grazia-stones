import '../models/stone.dart';
import '../repositories/base_repository.dart';

class StoneRepository extends BaseRepository {
  StoneRepository(super.api);

  Future<List<Stone>> getStones({int page = 1, int limit = 20}) async {
    return safeCall(() async {
      final response = await api.get('/stones', queryParameters: {
        'page': page,
        'limit': limit,
      });
      return (response.data['data'] as List)
          .map((j) => Stone.fromJson(j))
          .toList();
    });
  }

  Future<Stone> getStoneById(String id) async {
    return safeCall(() async {
      final response = await api.get('/stones/$id');
      return Stone.fromJson(response.data);
    });
  }

  Future<List<Stone>> searchStones(String query) async {
    return safeCall(() async {
      final response = await api.get('/stones/search', queryParameters: {
        'q': query,
      });
      return (response.data['data'] as List)
          .map((j) => Stone.fromJson(j))
          .toList();
    });
  }

  Future<List<Stone>> getStonesByCollection(String collectionId) async {
    return safeCall(() async {
      final response = await api.get('/collections/$collectionId/stones');
      return (response.data['data'] as List)
          .map((j) => Stone.fromJson(j))
          .toList();
    });
  }

  Future<List<Stone>> getPopularStones() async {
    return safeCall(() async {
      final response = await api.get('/stones/popular');
      return (response.data['data'] as List)
          .map((j) => Stone.fromJson(j))
          .toList();
    });
  }

  Future<List<Stone>> getNewArrivals() async {
    return safeCall(() async {
      final response = await api.get('/stones/new-arrivals');
      return (response.data['data'] as List)
          .map((j) => Stone.fromJson(j))
          .toList();
    });
  }
}
