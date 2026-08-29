import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/stone.dart';

import '../models/collection.dart';
import '../services/supabase_service.dart';
import '../utils/retry.dart';

/// Admin product repository for CRUD operations on stones
/// Requires admin role to perform operations
class AdminProductRepository {
  final SupabaseService _sb = SupabaseService.instance;

  /// Execute with retry logic
  Future<T> _executeWithRetry<T>(Future<T> Function() operation) async {
    return withRetry<T>(
      operation: operation,
      config: RetryConfig.database,
      onRetry: (error, attempt) {
        debugPrint('[AdminProductRepository] Retry attempt ${attempt + 1}: $error');
      },
    );
  }

  /// Verify admin access
  void _verifyAdmin() {
    final user = _sb.currentUser;
    if (user == null) throw Exception('Not authenticated');
    // RLS policies will enforce admin role at database level
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PRODUCT CRUD
  // ═══════════════════════════════════════════════════════════════════════

  /// Create new product
  Future<Stone> createProduct({
    required String name,
    required String slug,
    String? productCode,
    required String collectionId,
    String category = 'stone',
    String? description,
    String? shortDescription,
    required double pricePerSqft,
    String currency = 'INR',
    double? discountPercent,
    double? lengthCm,
    double? widthCm,
    double? thicknessMm,
    double? weightKg,
    double? coverageSqft,
    String? finish,
    String? material,
    List<String>? colors,
    List<String>? patterns,
    String? origin,
    List<String> images = const [],
    String? thumbnailUrl,
    String? model3dUrl,
    String? videoUrl,
    String stockStatus = 'in_stock',
    int stockQuantity = 0,
    List<String>? tags,
    bool featured = false,
    bool active = true,
    int sortOrder = 0,
  }) async {
    _verifyAdmin();

    return await _executeWithRetry(() async {
      final data = await _sb.client.from('stones').insert({
        'name': name,
        'slug': slug,
        'product_code': productCode,
        'collection_id': collectionId,
        'category': category,
        'description': description,
        'short_description': shortDescription,
        'price_per_sqft': pricePerSqft,
        'currency': currency,
        'discount_percent': discountPercent,
        'length_cm': lengthCm,
        'width_cm': widthCm,
        'thickness_mm': thicknessMm,
        'weight_kg': weightKg,
        'coverage_sqft': coverageSqft,
        'finish': finish,
        'material': material,
        'colors': colors,
        'patterns': patterns,
        'origin': origin,
        'images': images,
        'thumbnail_url': thumbnailUrl,
        'model_3d_url': model3dUrl,
        'video_url': videoUrl,
        'stock_status': stockStatus,
        'stock_quantity': stockQuantity,
        'tags': tags,
        'featured': featured,
        'active': active,
        'sort_order': sortOrder,
      }).select('*, collections(name, slug)').single();

      debugPrint('✅ Product created: ${data['id']}');
      return _stoneFromRow(data);
    });
  }

  /// Update existing product
  Future<Stone> updateProduct({
    required String stoneId,
    String? name,
    String? slug,
    String? productCode,
    String? collectionId,
    String? category,
    String? description,
    String? shortDescription,
    double? pricePerSqft,
    String? currency,
    double? discountPercent,
    double? lengthCm,
    double? widthCm,
    double? thicknessMm,
    double? weightKg,
    double? coverageSqft,
    String? finish,
    String? material,
    List<String>? colors,
    List<String>? patterns,
    String? origin,
    List<String>? images,
    String? thumbnailUrl,
    String? model3dUrl,
    String? videoUrl,
    String? stockStatus,
    int? stockQuantity,
    List<String>? tags,
    bool? featured,
    bool? active,
    int? sortOrder,
  }) async {
    _verifyAdmin();

    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (name != null) updates['name'] = name;
    if (slug != null) updates['slug'] = slug;
    if (productCode != null) updates['product_code'] = productCode;
    if (collectionId != null) updates['collection_id'] = collectionId;
    if (category != null) updates['category'] = category;
    if (description != null) updates['description'] = description;
    if (shortDescription != null) updates['short_description'] = shortDescription;
    if (pricePerSqft != null) updates['price_per_sqft'] = pricePerSqft;
    if (currency != null) updates['currency'] = currency;
    if (discountPercent != null) updates['discount_percent'] = discountPercent;
    if (lengthCm != null) updates['length_cm'] = lengthCm;
    if (widthCm != null) updates['width_cm'] = widthCm;
    if (thicknessMm != null) updates['thickness_mm'] = thicknessMm;
    if (weightKg != null) updates['weight_kg'] = weightKg;
    if (coverageSqft != null) updates['coverage_sqft'] = coverageSqft;
    if (finish != null) updates['finish'] = finish;
    if (material != null) updates['material'] = material;
    if (colors != null) updates['colors'] = colors;
    if (patterns != null) updates['patterns'] = patterns;
    if (origin != null) updates['origin'] = origin;
    if (images != null) updates['images'] = images;
    if (thumbnailUrl != null) updates['thumbnail_url'] = thumbnailUrl;
    if (model3dUrl != null) updates['model_3d_url'] = model3dUrl;
    if (videoUrl != null) updates['video_url'] = videoUrl;
    if (stockStatus != null) updates['stock_status'] = stockStatus;
    if (stockQuantity != null) updates['stock_quantity'] = stockQuantity;
    if (tags != null) updates['tags'] = tags;
    if (featured != null) updates['featured'] = featured;
    if (active != null) updates['active'] = active;
    if (sortOrder != null) updates['sort_order'] = sortOrder;

    return await _executeWithRetry(() async {
      final data = await _sb.client
          .from('stones')
          .update(updates)
          .eq('id', stoneId)
          .select('*, collections(name, slug)')
          .single();

      debugPrint('✅ Product updated: $stoneId');
      return _stoneFromRow(data);
    });
  }

  /// Delete product (soft delete by setting active = false)
  Future<void> deleteProduct(String stoneId) async {
    _verifyAdmin();

    await _executeWithRetry(() async {
      await _sb.client
          .from('stones')
          .update({'active': false, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', stoneId);
      debugPrint('✅ Product deleted (soft): $stoneId');
    });
  }

  /// Permanently delete product
  Future<void> permanentlyDeleteProduct(String stoneId) async {
    _verifyAdmin();

    await _executeWithRetry(() async {
      await _sb.client.from('stones').delete().eq('id', stoneId);
      debugPrint('✅ Product permanently deleted: $stoneId');
    });
  }

  /// Upload product image to Supabase Storage
  Future<String> uploadProductImage(Uint8List bytes, String fileName) async {
    _verifyAdmin();

    return await _executeWithRetry(() async {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = 'products/$timestamp\_$fileName';
      
      await _sb.client.storage.from('stones').uploadBinary(path, bytes);
      
      final publicUrl = _sb.client.storage.from('stones').getPublicUrl(path);
      debugPrint('✅ Product image uploaded: $path');
      return publicUrl;
    });
  }

  /// Delete product image from storage
  Future<void> deleteProductImage(String imageUrl) async {
    _verifyAdmin();

    try {
      final uri = Uri.parse(imageUrl);
      final path = uri.pathSegments.skip(3).join('/'); // Skip /storage/v1/object/public/stones/
      
      await _sb.client.storage.from('stones').remove([path]);
      debugPrint('✅ Product image deleted: $path');
    } catch (e) {
      debugPrint('⚠️ Failed to delete image: $e');
    }
  }

  /// Upload 3D model file
  Future<String> upload3DModel(Uint8List bytes, String fileName) async {
    _verifyAdmin();

    return await _executeWithRetry(() async {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '3d-models/$timestamp\_$fileName';
      
      await _sb.client.storage.from('stones').uploadBinary(path, bytes);
      
      final publicUrl = _sb.client.storage.from('stones').getPublicUrl(path);
      debugPrint('✅ 3D model uploaded: $path');
      return publicUrl;
    });
  }

  /// Bulk update products
  Future<void> bulkUpdateProducts(List<String> stoneIds, Map<String, dynamic> updates) async {
    _verifyAdmin();

    updates['updated_at'] = DateTime.now().toIso8601String();

    await _executeWithRetry(() async {
      for (final id in stoneIds) {
        await _sb.client.from('stones').update(updates).eq('id', id);
      }
      debugPrint('✅ Bulk updated ${stoneIds.length} products');
    });
  }

  // ═══════════════════════════════════════════════════════════════════════
  // COLLECTION CRUD
  // ═══════════════════════════════════════════════════════════════════════

  /// Create collection
  Future<Collection> createCollection({
    required String name,
    required String slug,
    String? description,
    String? imageUrl,
    int sortOrder = 0,
    bool active = true,
  }) async {
    _verifyAdmin();

    return await _executeWithRetry(() async {
      final data = await _sb.client.from('collections').insert({
        'name': name,
        'slug': slug,
        'description': description,
        'image_url': imageUrl,
        'sort_order': sortOrder,
        'active': active,
      }).select().single();

      debugPrint('✅ Collection created: ${data['id']}');
      return Collection.fromJson(data);
    });
  }

  /// Update collection
  Future<Collection> updateCollection({
    required String collectionId,
    String? name,
    String? slug,
    String? description,
    String? imageUrl,
    int? sortOrder,
    bool? active,
  }) async {
    _verifyAdmin();

    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (slug != null) updates['slug'] = slug;
    if (description != null) updates['description'] = description;
    if (imageUrl != null) updates['image_url'] = imageUrl;
    if (sortOrder != null) updates['sort_order'] = sortOrder;
    if (active != null) updates['active'] = active;

    return await _executeWithRetry(() async {
      final data = await _sb.client
          .from('collections')
          .update(updates)
          .eq('id', collectionId)
          .select()
          .single();

      debugPrint('✅ Collection updated: $collectionId');
      return Collection.fromJson(data);
    });
  }

  /// Delete collection
  Future<void> deleteCollection(String collectionId) async {
    _verifyAdmin();

    await _executeWithRetry(() async {
      await _sb.client.from('collections').delete().eq('id', collectionId);
      debugPrint('✅ Collection deleted: $collectionId');
    });
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ANALYTICS
  // ═══════════════════════════════════════════════════════════════════════

  /// Get product count
  Future<int> getProductCount({bool activeOnly = false}) async {
    return await _executeWithRetry(() async {
      var query = _sb.client.from('stones').select('id');
      if (activeOnly) {
        query = query.eq('active', true);
      }
      final response = await query.count(CountOption.exact);
      return response.count;
    });
  }

  /// Get low stock products
  Future<List<Stone>> getLowStockProducts({int threshold = 10}) async {
    _verifyAdmin();

    return await _executeWithRetry(() async {
      final data = await _sb.client
          .from('stones')
          .select('*, collections(name, slug)')
          .eq('active', true)
          .lte('stock_quantity', threshold)
          .order('stock_quantity');

      return data.map((j) => _stoneFromRow(j)).toList();
    });
  }

  // ═══════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════

  Stone _stoneFromRow(Map<String, dynamic> row) {
    return Stone.fromMap(row);
  }
}

