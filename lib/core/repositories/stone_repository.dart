import '../models/stone.dart';
import '../models/collection.dart';
import '../services/supabase_service.dart';
import '../services/mock_data_service.dart';
import 'package:flutter/foundation.dart';

/// Stone & collection repository backed by Supabase, with a mock-data
/// safety net so the catalogue/AR product carousel keeps working even
/// if Supabase credentials aren't reachable in a given deployment.
class StoneRepository {
  final SupabaseService _sb = SupabaseService.instance;

  // Falls back to catalogue mock data whenever Supabase actually fails —
  // not just in dev builds — so the storefront/AR product carousel never
  // shows a broken catalogue if backend credentials aren't reachable.
  // Real Supabase is still attempted first on every call above.
  bool get _useMockData => true;

  /// Maps a real `stones` row (snake_case Postgres columns, dimensions in
  /// cm/mm numerics) to the shape [Stone.fromJson] expects (camelCase,
  /// dimensions as display strings) — the live schema and the app's model
  /// were built independently and don't share a wire format.
  Stone _stoneFromRow(Map<String, dynamic> row) {
    final lengthCm = (row['length_cm'] as num?)?.toDouble();
    final widthCm = (row['width_cm'] as num?)?.toDouble();
    final thicknessMm = (row['thickness_mm'] as num?)?.toDouble();
    final lengthMm = lengthCm != null ? (lengthCm * 10).round() : null;
    final widthMm = widthCm != null ? (widthCm * 10).round() : null;
    final collectionName = (row['collections'] as Map<String, dynamic>?)?['name'] as String?;
    final images = List<String>.from(row['images'] ?? const []);

    return Stone(
      id: row['id']?.toString() ?? '',
      name: row['name'] ?? '',
      productCode: row['product_code'] ?? '',
      collection: collectionName ?? row['collection_id']?.toString() ?? '',
      category: row['category'] ?? '',
      pricePerSqFt: (row['price_per_sqft'] as num?)?.toDouble() ?? 0,
      description: row['description'] ?? '',
      images: images,
      mainImageUrl: row['thumbnail_url'] ?? (images.isNotEmpty ? images.first : null),
      rating: 0.0,
      reviewCount: 0,
      length: lengthMm != null ? '${lengthMm}mm' : '',
      width: widthMm != null ? '${widthMm}mm' : '',
      thickness: thicknessMm != null ? '${thicknessMm.toStringAsFixed(0)}mm' : '',
      size: (lengthMm != null && widthMm != null)
          ? '$lengthMm×$widthMm${thicknessMm != null ? '×${thicknessMm.toStringAsFixed(0)}' : ''}mm'
          : '',
      sqftPerBox: (row['coverage_sqft'] as num?)?.toDouble() ?? 0,
      piecesPerBox: 0,
      finish: row['finish'] ?? '',
      texture: row['material'] ?? '',
      availableColors: List<String>.from(row['colors'] ?? const []),
      idealFor: List<String>.from(row['tags'] ?? const []),
      isFeatured: row['featured'] == true,
      inStock: row['stock_status'] == null || row['stock_status'] == 'in_stock',
      stockQuantity: (row['stock_quantity'] as num?)?.toInt() ?? 0,
      weight: row['weight_kg'] != null ? '${row['weight_kg']}kg' : null,
      origin: row['origin'],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // STONES
  // ═══════════════════════════════════════════════════════════════════════

  Future<List<Stone>> getStones({
    int page = 1,
    int limit = 20,
    String? search,
    String? collectionId,
    String? finish,
    double? minPrice,
    double? maxPrice,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      var query = _sb.client
          .from('stones')
          .select('*, collections(name, slug)')
          .eq('active', true);

      if (search != null && search.isNotEmpty) {
        query = query.or('name.ilike.%$search%,product_code.ilike.%$search%,description.ilike.%$search%');
      }
      if (collectionId != null) {
        query = query.eq('collection_id', collectionId);
      }
      if (finish != null) {
        query = query.eq('finish', finish);
      }
      if (minPrice != null) {
        query = query.gte('price_per_sqft', minPrice);
      }
      if (maxPrice != null) {
        query = query.lte('price_per_sqft', maxPrice);
      }

      final from = (page - 1) * limit;
      final to = from + limit - 1;
      final data = await query
          .order(sortBy ?? 'sort_order', ascending: sortOrder == 'asc')
          .range(from, to);
      return data.map((j) => _stoneFromRow(j)).toList();
    } catch (e) {
      if (_useMockData) {
        debugPrint('[StoneRepository] Supabase error, falling back to mock data: $e');
        var stones = search != null && search.isNotEmpty
            ? MockDataService.searchStones(search)
            : collectionId != null
                ? MockDataService.getStonesByCollection(collectionId)
                : MockDataService.getAllStones();
        if (finish != null) stones = stones.where((s) => s.finish == finish).toList();
        if (minPrice != null) stones = stones.where((s) => s.pricePerSqFt >= minPrice).toList();
        if (maxPrice != null) stones = stones.where((s) => s.pricePerSqFt <= maxPrice).toList();
        return stones;
      }
      rethrow;
    }
  }

  Future<Stone> getStoneById(String id) async {
    try {
      final data = await _sb.client
          .from('stones')
          .select('*, collections(name, slug)')
          .eq('id', id)
          .single();
      return _stoneFromRow(data);
    } catch (e) {
      if (_useMockData) {
        debugPrint('[StoneRepository] getStoneById fallback: $e');
        final stone = MockDataService.getStoneById(id);
        if (stone == null) throw Exception('Stone not found: $id');
        return stone;
      }
      rethrow;
    }
  }

  Future<List<Stone>> searchStones(String query, {int limit = 20}) async {
    try {
      final data = await _sb.client
          .from('stones')
          .select('*, collections(name, slug)')
          .eq('active', true)
          .or('name.ilike.%$query%,product_code.ilike.%$query%,tags.cs.{$query}')
          .order('sort_order')
          .limit(limit);
      return data.map((j) => _stoneFromRow(j)).toList();
    } catch (e) {
      if (_useMockData) {
        debugPrint('[StoneRepository] searchStones fallback: $e');
        return MockDataService.searchStones(query);
      }
      rethrow;
    }
  }

  Future<List<Stone>> getTrendingStones({int limit = 10}) async {
    try {
      final data = await _sb.client
          .from('stones')
          .select('*, collections(name, slug)')
          .eq('active', true)
          .eq('featured', true)
          .order('sort_order')
          .limit(limit);
      return data.map((j) => _stoneFromRow(j)).toList();
    } catch (e) {
      if (_useMockData) {
        debugPrint('[StoneRepository] getTrendingStones fallback: $e');
        return MockDataService.getTrendingStones();
      }
      rethrow;
    }
  }

  Future<List<Stone>> getSimilarStones(String stoneId, {int limit = 5}) async {
    try {
      final stone = await getStoneById(stoneId);
      final data = await _sb.client
          .from('stones')
          .select('*, collections(name, slug)')
          .eq('active', true)
          .eq('collection_id', stone.collection)
          .neq('id', stoneId)
          .limit(limit);
      return data.map((j) => _stoneFromRow(j)).toList();
    } catch (e) {
      if (_useMockData) {
        debugPrint('[StoneRepository] getSimilarStones fallback: $e');
        final stone = MockDataService.getStoneById(stoneId);
        if (stone == null) return [];
        return MockDataService.getAllStones()
            .where((s) => s.collection == stone.collection && s.id != stoneId)
            .take(limit)
            .toList();
      }
      rethrow;
    }
  }

  Future<List<Stone>> getNewArrivals({int limit = 20}) async {
    return getStones(sortBy: 'created_at', sortOrder: 'desc', limit: limit);
  }

  // ════════════════════════════════════════════════════════════════════════
  // COLLECTIONS
  // ═══════════════════════════════════════════════════════════════════════

  Future<List<Collection>> getCollections() async {
    try {
      final data = await _sb.client
          .from('collections')
          .select()
          .eq('active', true)
          .order('sort_order');
      return data.map((j) => Collection.fromJson(j)).toList();
    } catch (e) {
      if (_useMockData) {
        debugPrint('[StoneRepository] getCollections fallback: $e');
        return MockDataService.getAllCollections();
      }
      rethrow;
    }
  }

  Future<Collection> getCollectionById(String id) async {
    try {
      final data = await _sb.client
          .from('collections')
          .select()
          .eq('id', id)
          .single();
      return Collection.fromJson(data);
    } catch (e) {
      if (_useMockData) {
        debugPrint('[StoneRepository] getCollectionById fallback: $e');
        return MockDataService.getAllCollections().firstWhere((c) => c.id == id);
      }
      rethrow;
    }
  }

  Future<List<Stone>> getStonesByCollection(String collectionId, {int page = 1, int limit = 20}) async {
    try {
      final from = (page - 1) * limit;
      final data = await _sb.client
          .from('stones')
          .select('*, collections(name, slug)')
          .eq('active', true)
          .eq('collection_id', collectionId)
          .order('sort_order')
          .range(from, from + limit - 1);
      return data.map((j) => _stoneFromRow(j)).toList();
    } catch (e) {
      if (_useMockData) {
        debugPrint('[StoneRepository] getStonesByCollection fallback: $e');
        return MockDataService.getStonesByCollection(collectionId);
      }
      rethrow;
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // WISHLIST
  // ════════════════════════════════════════════════════════════════════════

  Future<List<Stone>> getWishlist() async {
    final userId = _sb.currentUser?.id;
    if (userId == null) return [];
    final data = await _sb.client
        .from('wishlist_items')
        .select('stone_id, stones(*)')
        .eq('user_id', userId);
    return data
        .where((j) => j['stones'] != null)
        .map((j) => _stoneFromRow(j['stones']))
        .toList();
  }

  Future<void> addToWishlist(String stoneId) async {
    final userId = _sb.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');
    await _sb.client.from('wishlist_items').insert({
      'user_id': userId,
      'stone_id': stoneId,
    });
  }

  Future<void> removeFromWishlist(String stoneId) async {
    final userId = _sb.currentUser?.id;
    if (userId == null) return;
    await _sb.client
        .from('wishlist_items')
        .delete()
        .eq('user_id', userId)
        .eq('stone_id', stoneId);
  }

  Future<bool> isInWishlist(String stoneId) async {
    final userId = _sb.currentUser?.id;
    if (userId == null) return false;
    final data = await _sb.client
        .from('wishlist_items')
        .select('id')
        .eq('user_id', userId)
        .eq('stone_id', stoneId)
        .maybeSingle();
    return data != null;
  }

  // ════════════════════════════════════════════════════════════════════════
  // FILTERS
  // ════════════════════════════════════════════════════════════════════════

  Future<List<String>> getFinishes() async {
    try {
      final data = await _sb.client
          .from('stones')
          .select('finish')
          .eq('active', true)
          .not('finish', 'is', null);
      return data.map((j) => j['finish'] as String).toSet().toList()..sort();
    } catch (e) {
      if (_useMockData) {
        debugPrint('[StoneRepository] getFinishes fallback: $e');
        return MockDataService.getAllStones().map((s) => s.finish).toSet().toList()..sort();
      }
      rethrow;
    }
  }

  Future<List<String>> getColors() async {
    try {
      final data = await _sb.client
          .from('stones')
          .select('colors')
          .eq('active', true);
      final allColors = <String>{};
      for (final row in data) {
        if (row['colors'] is List) {
          allColors.addAll(List<String>.from(row['colors']));
        }
      }
      return allColors.toList()..sort();
    } catch (e) {
      if (_useMockData) {
        debugPrint('[StoneRepository] getColors fallback: $e');
        final allColors = <String>{};
        for (final s in MockDataService.getAllStones()) {
          allColors.addAll(s.availableColors);
        }
        return allColors.toList()..sort();
      }
      rethrow;
    }
  }

  Future<Map<String, double>> getPriceRange() async {
    try {
      final data = await _sb.client
          .from('stones')
          .select('price_per_sqft')
          .eq('active', true);
      if (data.isEmpty) return {'min': 0, 'max': 0};
      final prices = data.map((j) => (j['price_per_sqft'] as num).toDouble()).toList();
      return {'min': prices.reduce((a, b) => a < b ? a : b), 'max': prices.reduce((a, b) => a > b ? a : b)};
    } catch (e) {
      if (_useMockData) {
        debugPrint('[StoneRepository] getPriceRange fallback: $e');
        final prices = MockDataService.getAllStones().map((s) => s.pricePerSqFt).toList();
        if (prices.isEmpty) return {'min': 0, 'max': 0};
        return {'min': prices.reduce((a, b) => a < b ? a : b), 'max': prices.reduce((a, b) => a > b ? a : b)};
      }
      rethrow;
    }
  }
}