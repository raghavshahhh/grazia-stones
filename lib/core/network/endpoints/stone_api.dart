import '../../models/stone.dart';
import '../api_service.dart';
import '../api_response.dart';

/// Stone-related API endpoints
class StoneApi {
  final ApiService _api = ApiService.instance;

  // ═══════════════════════════════════════════════════════════════════════
  // STONES
  // ═══════════════════════════════════════════════════════════════════════

  /// Get all stones with filters
  Future<PaginatedResponse<Stone>> getStones({
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
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (search != null) 'search': search,
      if (collection != null) 'collection': collection,
      if (finish != null) 'finish': finish,
      if (minPrice != null) 'min_price': minPrice,
      if (maxPrice != null) 'max_price': maxPrice,
      if (sortBy != null) 'sort_by': sortBy,
      if (sortOrder != null) 'sort_order': sortOrder,
    };

    final response = await _api.get('/stones', queryParameters: queryParams);
    return PaginatedResponse.fromResponse(
      response as dynamic,
      (json) => Stone.fromJson(json),
    );
  }

  /// Get stone by ID
  Future<Stone> getStoneById(String stoneId) async {
    final response = await _api.get<Map<String, dynamic>>('/stones/$stoneId');
    
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.errorMessage);
    }
    
    return Stone.fromJson(response.data!);
  }

  /// Get trending stones
  Future<List<Stone>> getTrendingStones({int limit = 10}) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/stones/trending',
      queryParameters: {'limit': limit},
    );
    
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.errorMessage);
    }
    
    final data = response.data!['data'] as List;
    return data.map((json) => Stone.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Get similar stones
  Future<List<Stone>> getSimilarStones(String stoneId, {int limit = 5}) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/stones/$stoneId/similar',
      queryParameters: {'limit': limit},
    );
    
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.errorMessage);
    }
    
    final data = response.data!['data'] as List;
    return data.map((json) => Stone.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Search stones
  Future<List<Stone>> searchStones(String query, {int limit = 20}) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/stones/search',
      queryParameters: {
        'q': query,
        'limit': limit,
      },
    );
    
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.errorMessage);
    }
    
    final data = response.data!['data'] as List;
    return data.map((json) => Stone.fromJson(json as Map<String, dynamic>)).toList();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // COLLECTIONS
  // ═══════════════════════════════════════════════════════════════════════

  /// Get all collections
  Future<List<Map<String, dynamic>>> getCollections() async {
    final response = await _api.get<Map<String, dynamic>>('/collections');
    
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.errorMessage);
    }
    
    final data = response.data!['data'] as List;
    return data.cast<Map<String, dynamic>>();
  }

  /// Get collection by ID
  Future<Map<String, dynamic>> getCollectionById(String collectionId) async {
    final response = await _api.get<Map<String, dynamic>>('/collections/$collectionId');
    
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.errorMessage);
    }
    
    return response.data!;
  }

  /// Get stones by collection
  Future<List<Stone>> getStonesByCollection(String collectionId, {
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/collections/$collectionId/stones',
      queryParameters: {
        'page': page,
        'limit': limit,
      },
    );
    
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.errorMessage);
    }
    
    final data = response.data!['data'] as List;
    return data.map((json) => Stone.fromJson(json as Map<String, dynamic>)).toList();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // FILTERS
  // ═══════════════════════════════════════════════════════════════════════

  /// Get available finishes
  Future<List<String>> getFinishes() async {
    final response = await _api.get<Map<String, dynamic>>('/stones/filters/finishes');
    
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.errorMessage);
    }
    
    final data = response.data!['data'] as List;
    return data.cast<String>();
  }

  /// Get available colors
  Future<List<Map<String, dynamic>>> getColors() async {
    final response = await _api.get<Map<String, dynamic>>('/stones/filters/colors');
    
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.errorMessage);
    }
    
    final data = response.data!['data'] as List;
    return data.cast<Map<String, dynamic>>();
  }

  /// Get price range
  Future<Map<String, double>> getPriceRange() async {
    final response = await _api.get<Map<String, dynamic>>('/stones/filters/price-range');
    
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.errorMessage);
    }
    
    final data = response.data!;
    return {
      'min': (data['min'] as num).toDouble(),
      'max': (data['max'] as num).toDouble(),
    };
  }

  // ═══════════════════════════════════════════════════════════════════════
  // REVIEWS & RATINGS
  // ═══════════════════════════════════════════════════════════════════════

  /// Get stone reviews
  Future<List<Map<String, dynamic>>> getStoneReviews(
    String stoneId, {
    int page = 1,
    int limit = 10,
  }) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/stones/$stoneId/reviews',
      queryParameters: {
        'page': page,
        'limit': limit,
      },
    );
    
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.errorMessage);
    }
    
    final data = response.data!['data'] as List;
    return data.cast<Map<String, dynamic>>();
  }

  /// Add stone review
  Future<bool> addStoneReview(
    String stoneId, {
    required double rating,
    required String comment,
    List<String>? images,
  }) async {
    final response = await _api.post(
      '/stones/$stoneId/reviews',
      data: {
        'rating': rating,
        'comment': comment,
        if (images != null) 'images': images,
      },
    );
    
    return response.isSuccess;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // FAVORITES / WISHLIST
  // ═══════════════════════════════════════════════════════════════════════

  /// Get user's wishlist
  Future<List<Stone>> getWishlist() async {
    final response = await _api.get<Map<String, dynamic>>('/wishlist');
    
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.errorMessage);
    }
    
    final data = response.data!['data'] as List;
    return data.map((json) => Stone.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Add stone to wishlist
  Future<bool> addToWishlist(String stoneId) async {
    final response = await _api.post(
      '/wishlist',
      data: {'stone_id': stoneId},
    );
    
    return response.isSuccess;
  }

  /// Remove stone from wishlist
  Future<bool> removeFromWishlist(String stoneId) async {
    final response = await _api.delete('/wishlist/$stoneId');
    return response.isSuccess;
  }

  /// Check if stone is in wishlist
  Future<bool> isInWishlist(String stoneId) async {
    final response = await _api.get<Map<String, dynamic>>('/wishlist/check/$stoneId');
    
    if (!response.isSuccess || response.data == null) {
      return false;
    }
    
    return response.data!['is_in_wishlist'] as bool? ?? false;
  }
}
