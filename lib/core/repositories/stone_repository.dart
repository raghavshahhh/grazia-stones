import '../models/stone.dart';
import '../models/collection.dart';
import '../services/supabase_service.dart';
import '../services/mock_data_service.dart';
import '../services/cache_service.dart';
import '../config/env_config.dart'
    show EnvConfig;
import '../utils/retry.dart';
import 'package:flutter/foundation.dart';

/// Stone & collection repository backed by Supabase.
/// Mock data is only used when explicitly enabled via ENABLE_MOCK_DATA env flag.
class StoneRepository {
  final SupabaseService _sb = SupabaseService.instance;
  final CacheService _cache = CacheService.instance;
  static const String _cacheNamespace = 'stones';

  // Mock data only enabled via environment variable for development/testing.
  // In production, this MUST be false to ensure real data from Supabase.
  bool get _useMockData => EnvConfig().enableMockData;

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

  /// Execute a Supabase query with retry logic
  Future<T> _executeWithRetry<T>(Future<T> Function() operation) async {
    return withRetry<T>(
      operation: operation,
      config: RetryConfig.database,
      onRetry: (error, attempt) {
        debugPrint('[StoneRepository] Retry attempt ${attempt + 1}: $error');
      },
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
    final cacheKey = 'list_${page}_${limit}_${search ?? ''}_${collectionId ?? ''}_${finish ?? ''}_${minPrice ?? ''}_${maxPrice ?? ''}_${sortBy ?? ''}_${sortOrder ?? ''}';
    try {
      return await _executeWithRetry(() async {
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
        await _cache.set(_cacheNamespace, cacheKey, data);
        return data.map((j) => _stoneFromRow(j)).toList();
      });
    } catch (e) {
      final cached = await _cache.get<List>(_cacheNamespace, cacheKey);
      if (cached != null && cached.isNotEmpty) {
        debugPrint('[StoneRepository] Supabase error, serving cached stones: $e');
        return cached.map((j) => _stoneFromRow(Map<String, dynamic>.from(j as Map))).toList();
      }
      if (_useMockData) {
        debugPrint('[StoneRepository] Supabase error & no cache, falling back to mock data: $e');
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

  Future<List<Stone>> getAllStones() async {
    return getStones(limit: 1000);
  }


  Future<Stone> getStoneById(String id) async {
    final cacheKey = 'stone_$id';
    try {
      return await _executeWithRetry(() async {
        final data = await _sb.client
            .from('stones')
            .select('*, collections(name, slug)')
            .eq('id', id)
            .single();
        await _cache.set(_cacheNamespace, cacheKey, data);
        return _stoneFromRow(data);
      });
    } catch (e) {
      final cached = await _cache.get<Map>(_cacheNamespace, cacheKey);
      if (cached != null) {
        debugPrint('[StoneRepository] Supabase error, serving cached stone: $e');
        return _stoneFromRow(Map<String, dynamic>.from(cached));
      }
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
    final cacheKey = 'search_${query.toLowerCase()}_$limit';
    try {
      return await _executeWithRetry(() async {
        final data = await _sb.client
            .from('stones')
            .select('*, collections(name, slug)')
            .eq('active', true)
            .or('name.ilike.%$query%,product_code.ilike.%$query%,tags.cs.{$query}')
            .order('sort_order')
            .limit(limit);
        await _cache.set(_cacheNamespace, cacheKey, data);
        return data.map((j) => _stoneFromRow(j)).toList();
      });
    } catch (e) {
      final cached = await _cache.get<List>(_cacheNamespace, cacheKey);
      if (cached != null && cached.isNotEmpty) {
        debugPrint('[StoneRepository] Supabase error, serving cached search results: $e');
        return cached.map((j) => _stoneFromRow(Map<String, dynamic>.from(j as Map))).toList();
      }
      if (_useMockData) {
        debugPrint('[StoneRepository] searchStones fallback: $e');
        return MockDataService.searchStones(query);
      }
      rethrow;
    }
  }

  Future<List<Stone>> getTrendingStones({int limit = 10}) async {
    final cacheKey = 'trending_$limit';
    try {
      return await _executeWithRetry(() async {
        final data = await _sb.client
            .from('stones')
            .select('*, collections(name, slug)')
            .eq('active', true)
            .eq('featured', true)
            .order('sort_order')
            .limit(limit);
        await _cache.set(_cacheNamespace, cacheKey, data);
        return data.map((j) => _stoneFromRow(j)).toList();
      });
    } catch (e) {
      final cached = await _cache.get<List>(_cacheNamespace, cacheKey);
      if (cached != null && cached.isNotEmpty) {
        debugPrint('[StoneRepository] Supabase error, serving cached trending stones: $e');
        return cached.map((j) => _stoneFromRow(Map<String, dynamic>.from(j as Map))).toList();
      }
      if (_useMockData) {
        debugPrint('[StoneRepository] getTrendingStones fallback: $e');
        return MockDataService.getTrendingStones();
      }
      rethrow;
    }
  }

  Future<List<Stone>> getSimilarStones(String stoneId, {int limit = 5}) async {
    final cacheKey = 'similar_${stoneId}_$limit';
    try {
      return await _executeWithRetry(() async {
        final rawStone = await _sb.client
            .from('stones')
            .select('collection_id, category')
            .eq('id', stoneId)
            .maybeSingle();

        if (rawStone == null) return [];
        final collectionId = rawStone['collection_id'];

        if (collectionId != null) {
          final data = await _sb.client
              .from('stones')
              .select('*, collections(name, slug)')
              .eq('active', true)
              .eq('collection_id', collectionId)
              .neq('id', stoneId)
              .limit(limit);
          await _cache.set(_cacheNamespace, cacheKey, data);
          return data.map((j) => _stoneFromRow(j)).toList();
        } else {
          final data = await _sb.client
              .from('stones')
              .select('*, collections(name, slug)')
              .eq('active', true)
              .eq('category', rawStone['category'] ?? 'stone')
              .neq('id', stoneId)
              .limit(limit);
          await _cache.set(_cacheNamespace, cacheKey, data);
          return data.map((j) => _stoneFromRow(j)).toList();
        }
      });
    } catch (e) {
      final cached = await _cache.get<List>(_cacheNamespace, cacheKey);
      if (cached != null && cached.isNotEmpty) {
        debugPrint('[StoneRepository] Supabase error, serving cached similar stones: $e');
        return cached.map((j) => _stoneFromRow(Map<String, dynamic>.from(j as Map))).toList();
      }
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
  // ════════════════════════════════════════════════════════════════════════

  Future<List<Collection>> getCollections() async {
    const cacheKey = 'collections_all';
    try {
      return await _executeWithRetry(() async {
        final data = await _sb.client
            .from('collections')
            .select('*, stones(count)')
            .eq('active', true)
            .order('sort_order');
            
        final processed = data.map((j) {
          final map = Map<String, dynamic>.from(j);
          final stoneCountData = j['stones'] as List?;
          int count = 0;
          if (stoneCountData != null && stoneCountData.isNotEmpty) {
            count = (stoneCountData.first['count'] as num?)?.toInt() ?? 0;
          }
          map['stone_count'] = count > 0 ? count : (j['stone_count'] ?? 18);
          return map;
        }).toList();
        await _cache.set(_cacheNamespace, cacheKey, processed);
        return processed.map((m) => Collection.fromJson(m)).toList();
      });
    } catch (e) {
      final cached = await _cache.get<List>(_cacheNamespace, cacheKey);
      if (cached != null && cached.isNotEmpty) {
        debugPrint('[StoneRepository] Supabase error, serving cached collections: $e');
        return cached.map((m) => Collection.fromJson(Map<String, dynamic>.from(m as Map))).toList();
      }
      if (_useMockData) {
        debugPrint('[StoneRepository] getCollections fallback: $e');
        return MockDataService.getAllCollections();
      }
      rethrow;
    }
  }

  Future<Collection> getCollectionById(String id) async {
    final cacheKey = 'collection_$id';
    try {
      return await _executeWithRetry(() async {
        final data = await _sb.client
            .from('collections')
            .select()
            .eq('id', id)
            .single();
        await _cache.set(_cacheNamespace, cacheKey, data);
        return Collection.fromJson(data);
      });
    } catch (e) {
      final cached = await _cache.get<Map>(_cacheNamespace, cacheKey);
      if (cached != null) {
        debugPrint('[StoneRepository] Supabase error, serving cached collection: $e');
        return Collection.fromJson(Map<String, dynamic>.from(cached));
      }
      if (_useMockData) {
        debugPrint('[StoneRepository] getCollectionById fallback: $e');
        return MockDataService.getAllCollections().firstWhere((c) => c.id == id);
      }
      rethrow;
    }
  }

  Future<List<Stone>> getStonesByCollection(String collectionId, {int page = 1, int limit = 20}) async {
    final cacheKey = 'collection_stones_${collectionId}_${page}_$limit';
    try {
      return await _executeWithRetry(() async {
        final from = (page - 1) * limit;
        final data = await _sb.client
            .from('stones')
            .select('*, collections(name, slug)')
            .eq('active', true)
            .eq('collection_id', collectionId)
            .order('sort_order')
            .range(from, from + limit - 1);
        await _cache.set(_cacheNamespace, cacheKey, data);
        return data.map((j) => _stoneFromRow(j)).toList();
      });
    } catch (e) {
      final cached = await _cache.get<List>(_cacheNamespace, cacheKey);
      if (cached != null && cached.isNotEmpty) {
        debugPrint('[StoneRepository] Supabase error, serving cached stones by collection: $e');
        return cached.map((j) => _stoneFromRow(Map<String, dynamic>.from(j as Map))).toList();
      }
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
    
    try {
      return await _executeWithRetry(() async {
        final data = await _sb.client
            .from('wishlist_items')
            .select('stone_id, stones(*)')
            .eq('user_id', userId);
        return data
            .where((j) => j['stones'] != null)
            .map((j) => _stoneFromRow(j['stones']))
            .toList();
      });
    } catch (e) {
      if (_useMockData) return [];
      rethrow;
    }
  }

  Future<void> addToWishlist(String stoneId) async {
    final userId = _sb.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');
    await _executeWithRetry(() async {
      await _sb.client.from('wishlist_items').insert({
        'user_id': userId,
        'stone_id': stoneId,
      });
    });
  }

  Future<void> removeFromWishlist(String stoneId) async {
    final userId = _sb.currentUser?.id;
    if (userId == null) return;
    await _executeWithRetry(() async {
      await _sb.client
          .from('wishlist_items')
          .delete()
          .eq('user_id', userId)
          .eq('stone_id', stoneId);
    });
  }

  Future<bool> isInWishlist(String stoneId) async {
    final userId = _sb.currentUser?.id;
    if (userId == null) return false;
    
    try {
      return await _executeWithRetry(() async {
        final data = await _sb.client
            .from('wishlist_items')
            .select('id')
            .eq('user_id', userId)
            .eq('stone_id', stoneId)
            .maybeSingle();
        return data != null;
      });
    } catch (e) {
      if (_useMockData) return false;
      rethrow;
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // FILTERS
  // ════════════════════════════════════════════════════════════════════════

  Future<List<String>> getFinishes() async {
    const cacheKey = 'finishes_list';
    try {
      return await _executeWithRetry(() async {
        final data = await _sb.client
            .from('stones')
            .select('finish')
            .eq('active', true)
            .not('finish', 'is', null);
        final list = data.map((j) => j['finish'] as String).toSet().toList()..sort();
        await _cache.set(_cacheNamespace, cacheKey, list);
        return list;
      });
    } catch (e) {
      final cached = await _cache.get<List>(_cacheNamespace, cacheKey);
      if (cached != null && cached.isNotEmpty) {
        return List<String>.from(cached);
      }
      if (_useMockData) {
        debugPrint('[StoneRepository] getFinishes fallback: $e');
        return MockDataService.getAllStones().map((s) => s.finish).toSet().toList()..sort();
      }
      rethrow;
    }
  }

  Future<List<String>> getColors() async {
    const cacheKey = 'colors_list';
    try {
      return await _executeWithRetry(() async {
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
        final list = allColors.toList()..sort();
        await _cache.set(_cacheNamespace, cacheKey, list);
        return list;
      });
    } catch (e) {
      final cached = await _cache.get<List>(_cacheNamespace, cacheKey);
      if (cached != null && cached.isNotEmpty) {
        return List<String>.from(cached);
      }
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
    const cacheKey = 'price_range';
    try {
      return await _executeWithRetry(() async {
        final data = await _sb.client
            .from('stones')
            .select('price_per_sqft')
            .eq('active', true);
        if (data.isEmpty) return {'min': 0, 'max': 0};
        final prices = data.map((j) => (j['price_per_sqft'] as num).toDouble()).toList();
        final range = {'min': prices.reduce((a, b) => a < b ? a : b), 'max': prices.reduce((a, b) => a > b ? a : b)};
        await _cache.set(_cacheNamespace, cacheKey, range);
        return range;
      });
    } catch (e) {
      final cached = await _cache.get<Map>(_cacheNamespace, cacheKey);
      if (cached != null) {
        return {
          'min': (cached['min'] as num).toDouble(),
          'max': (cached['max'] as num).toDouble(),
        };
      }
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