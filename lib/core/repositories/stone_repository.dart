import '../models/stone.dart';
import '../models/collection.dart';
import '../services/supabase_service.dart';

/// Stone & collection repository backed by Supabase.
/// Replaces MockDataService fallbacks and Dio/REST calls.
class StoneRepository {
  final SupabaseService _sb = SupabaseService.instance;

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
    return data.map((j) => Stone.fromJson(j)).toList();
  }

  Future<Stone> getStoneById(String id) async {
    final data = await _sb.client
        .from('stones')
        .select('*, collections(name, slug)')
        .eq('id', id)
        .single();
    return Stone.fromJson(data);
  }

  Future<List<Stone>> searchStones(String query, {int limit = 20}) async {
    final data = await _sb.client
        .from('stones')
        .select('*, collections(name, slug)')
        .eq('active', true)
        .or('name.ilike.%$query%,product_code.ilike.%$query%,tags.cs.{$query}')
        .order('sort_order')
        .limit(limit);
    return data.map((j) => Stone.fromJson(j)).toList();
  }

  Future<List<Stone>> getTrendingStones({int limit = 10}) async {
    final data = await _sb.client
        .from('stones')
        .select('*, collections(name, slug)')
        .eq('active', true)
        .eq('featured', true)
        .order('sort_order')
        .limit(limit);
    return data.map((j) => Stone.fromJson(j)).toList();
  }

  Future<List<Stone>> getSimilarStones(String stoneId, {int limit = 5}) async {
    // Get the stone first to find its collection
    final stone = await getStoneById(stoneId);
    final data = await _sb.client
        .from('stones')
        .select('*, collections(name, slug)')
        .eq('active', true)
        .eq('collection_id', stone.collection)
        .neq('id', stoneId)
        .limit(limit);
    return data.map((j) => Stone.fromJson(j)).toList();
  }

  Future<List<Stone>> getNewArrivals({int limit = 20}) async {
    return getStones(sortBy: 'created_at', sortOrder: 'desc', limit: limit);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // COLLECTIONS
  // ═══════════════════════════════════════════════════════════════════════

  Future<List<Collection>> getCollections() async {
    final data = await _sb.client
        .from('collections')
        .select()
        .eq('active', true)
        .order('sort_order');
    return data.map((j) => Collection.fromJson(j)).toList();
  }

  Future<Collection> getCollectionById(String id) async {
    final data = await _sb.client
        .from('collections')
        .select()
        .eq('id', id)
        .single();
    return Collection.fromJson(data);
  }

  Future<List<Stone>> getStonesByCollection(String collectionId, {int page = 1, int limit = 20}) async {
    final from = (page - 1) * limit;
    final data = await _sb.client
        .from('stones')
        .select('*, collections(name, slug)')
        .eq('active', true)
        .eq('collection_id', collectionId)
        .order('sort_order')
        .range(from, from + limit - 1);
    return data.map((j) => Stone.fromJson(j)).toList();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // WISHLIST
  // ═══════════════════════════════════════════════════════════════════════

  Future<List<Stone>> getWishlist() async {
    final userId = _sb.currentUser?.id;
    if (userId == null) return [];
    final data = await _sb.client
        .from('wishlist_items')
        .select('stone_id, stones(*)')
        .eq('user_id', userId);
    return data
        .where((j) => j['stones'] != null)
        .map((j) => Stone.fromJson(j['stones']))
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

  // ═══════════════════════════════════════════════════════════════════════
  // FILTERS
  // ═══════════════════════════════════════════════════════════════════════

  Future<List<String>> getFinishes() async {
    final data = await _sb.client
        .from('stones')
        .select('finish')
        .eq('active', true)
        .not('finish', 'is', null);
    return data.map((j) => j['finish'] as String).toSet().toList()..sort();
  }

  Future<List<String>> getColors() async {
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
  }

  Future<Map<String, double>> getPriceRange() async {
    final data = await _sb.client
        .from('stones')
        .select('price_per_sqft')
        .eq('active', true);
    if (data.isEmpty) return {'min': 0, 'max': 0};
    final prices = data.map((j) => (j['price_per_sqft'] as num).toDouble()).toList();
    return {'min': prices.reduce((a, b) => a < b ? a : b), 'max': prices.reduce((a, b) => a > b ? a : b)};
  }
}
