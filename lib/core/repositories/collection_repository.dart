import '../models/collection.dart';
import '../repositories/base_repository.dart';

class CollectionRepository extends BaseRepository {
  CollectionRepository(super.api);

  Future<List<Collection>> getCollections() async {
    return safeCall(() async {
      final response = await api.get('/collections');
      return (response.data['data'] as List)
          .map((j) => Collection.fromJson(j))
          .toList();
    });
  }

  Future<Collection> getCollectionById(String id) async {
    return safeCall(() async {
      final response = await api.get('/collections/$id');
      return Collection.fromJson(response.data);
    });
  }
}
