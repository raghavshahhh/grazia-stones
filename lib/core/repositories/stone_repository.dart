import '../models/stone.dart';
import '../repositories/base_repository.dart';
import '../network/endpoints/stone_api.dart';

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
    return safeCall(() async {
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
      return response.data ?? [];
    });
  }

  Future<Stone> getStoneById(String id) async {
    return safeCall(() async {
      return await _stoneApi.getStoneById(id);
    });
  }

  Future<List<Stone>> searchStones(String query, {int limit = 20}) async {
    return safeCall(() async {
      return await _stoneApi.searchStones(query, limit: limit);
    });
  }

  Future<List<Stone>> getTrendingStones({int limit = 10}) async {
    return safeCall(() async {
      return await _stoneApi.getTrendingStones(limit: limit);
    });
  }

  Future<List<Stone>> getSimilarStones(String stoneId, {int limit = 5}) async {
    return safeCall(() async {
      return await _stoneApi.getSimilarStones(stoneId, limit: limit);
    });
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
    return safeCall(() async {
      return await _stoneApi.getCollections();
    });
  }

  Future<Map<String, dynamic>> getCollectionById(String collectionId) async {
    return safeCall(() async {
      return await _stoneApi.getCollectionById(collectionId);
    });
  }

  Future<List<Stone>> getStonesByCollection(
    String collectionId, {
    int page = 1,
    int limit = 20,
  }) async {
    return safeCall(() async {
      return await _stoneApi.getStonesByCollection(
        collectionId,
        page: page,
        limit: limit,
      );
    });
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
