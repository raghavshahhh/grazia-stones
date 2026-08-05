import '../models/stone.dart';
import '../repositories/base_repository.dart';
import '../network/endpoints/stone_api.dart';
import '../services/mock_data_service.dart';

class StoneRepository extends BaseRepository {
  StoneRepository(super.api);
  
  final StoneApi _stoneApi = StoneApi();

  // ═══════════════════════════════════════════════════════════════════════
  // STONES
  // ═══════════════════════════════════════════════════════════════════════

  Future<List<Stone>> getStones({
    int page = 1,
    int limit = 20,
    String? search,
    String? collection,
    String? finish,
    double? minPrice,
    double? maxPrice,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      final response = await _stoneApi.getStones(
        page: page,
        limit: limit,
        search: search,
        collection: collection,
        finish: finish,
        minPrice: minPrice,
        maxPrice: maxPrice,
        sortBy: sortBy,
        sortOrder: sortOrder,
      );
      final list = response.data ?? [];
      return list.isNotEmpty ? list : MockDataService.getAllStones();
    } catch (_) {
      return MockDataService.getAllStones();
    }
  }

  Future<Stone> getStoneById(String id) async {
    try {
      return await _stoneApi.getStoneById(id);
    } catch (_) {
      return MockDataService.getStoneById(id) ?? MockDataService.stones.first;
    }
  }

  Future<List<Stone>> searchStones(String query, {int limit = 20}) async {
    try {
      return await _stoneApi.searchStones(query, limit: limit);
    } catch (_) {
      return MockDataService.searchStones(query);
    }
  }

  Future<List<Stone>> getTrendingStones({int limit = 10}) async {
    // DEMO MODE: Use mock data only, skip API call
    return MockDataService.getTrendingStones();
  }

  Future<List<Stone>> getSimilarStones(String stoneId, {int limit = 5}) async {
    try {
      return await _stoneApi.getSimilarStones(stoneId, limit: limit);
    } catch (_) {
      return MockDataService.stones.take(limit).toList();
    }
  }

  // Alias for backward compatibility
  Future<List<Stone>> getPopularStones() async {
    return getTrendingStones(limit: 20);
  }

  // Alias for backward compatibility
  Future<List<Stone>> getNewArrivals() async {
    return getStones(sortBy: 'created_at', sortOrder: 'desc', limit: 20);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // COLLECTIONS
  // ═══════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getCollections() async {
    // DEMO MODE: Use mock data only, skip API call
    return MockDataService.collections.map((c) => c.toJson()).toList();
  }

  Future<Map<String, dynamic>> getCollectionById(String collectionId) async {
    try {
      return await _stoneApi.getCollectionById(collectionId);
    } catch (_) {
      final c = MockDataService.collections.firstWhere(
        (elem) => elem.id == collectionId,
        orElse: () => MockDataService.collections.first,
      );
      return c.toJson();
    }
  }

  Future<List<Stone>> getStonesByCollection(
    String collectionId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final list = await _stoneApi.getStonesByCollection(
        collectionId,
        page: page,
        limit: limit,
      );
      return list.isNotEmpty
          ? list
          : MockDataService.stones
              .where((s) => s.collection.toLowerCase().contains(collectionId.toLowerCase()))
              .toList();
    } catch (_) {
      return MockDataService.stones
          .where((s) => s.collection.toLowerCase().contains(collectionId.toLowerCase()))
          .toList();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // FILTERS
  // ═══════════════════════════════════════════════════════════════════════

  Future<List<String>> getFinishes() async {
    return safeCall(() async {
      return await _stoneApi.getFinishes();
    });
  }

  Future<List<Map<String, dynamic>>> getColors() async {
    return safeCall(() async {
      return await _stoneApi.getColors();
    });
  }

  Future<Map<String, double>> getPriceRange() async {
    return safeCall(() async {
      return await _stoneApi.getPriceRange();
    });
  }

  // ═══════════════════════════════════════════════════════════════════════
  // REVIEWS
  // ═══════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getStoneReviews(
    String stoneId, {
    int page = 1,
    int limit = 10,
  }) async {
    return safeCall(() async {
      return await _stoneApi.getStoneReviews(
        stoneId,
        page: page,
        limit: limit,
      );
    });
  }

  Future<bool> addStoneReview(
    String stoneId, {
    required double rating,
    required String comment,
    List<String>? images,
  }) async {
    return safeCall(() async {
      return await _stoneApi.addStoneReview(
        stoneId,
        rating: rating,
        comment: comment,
        images: images,
      );
    });
  }

  // ═══════════════════════════════════════════════════════════════════════
  // WISHLIST
  // ═══════════════════════════════════════════════════════════════════════

  Future<List<Stone>> getWishlist() async {
    return safeCall(() async {
      return await _stoneApi.getWishlist();
    });
  }

  Future<bool> addToWishlist(String stoneId) async {
    return safeCall(() async {
      return await _stoneApi.addToWishlist(stoneId);
    });
  }

  Future<bool> removeFromWishlist(String stoneId) async {
    return safeCall(() async {
      return await _stoneApi.removeFromWishlist(stoneId);
    });
  }

  Future<bool> isInWishlist(String stoneId) async {
    return safeCall(() async {
      return await _stoneApi.isInWishlist(stoneId);
    });
  }
}
