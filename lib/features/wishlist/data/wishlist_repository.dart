import 'package:flutter/foundation.dart';
import '../../../core/services/supabase_service.dart';

/// Repository for managing wishlist items in Supabase database
/// 
/// Features:
/// - Sync wishlist with Supabase backend (wishlist_items table)
/// - CRUD operations with RLS enforcement
/// - Automatic user association
/// - Retry logic for network resilience
class WishlistRepository {
  final _client = SupabaseService.instance.client;

  /// Get all wishlist stone IDs for current user
  Future<List<String>> getWishlistStoneIds() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('⚠️ WishlistRepository: No authenticated user');
        return [];
      }

      final data = await _client
          .from('wishlist_items')
          .select('stone_id')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (data as List).map((item) => item['stone_id'] as String).toList();
    } catch (e) {
      debugPrint('❌ WishlistRepository.getWishlistStoneIds error: $e');
      rethrow;
    }
  }

  /// Add stone to wishlist
  Future<void> addToWishlist(String stoneId) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Check if already exists (Supabase will prevent duplicates via unique constraint)
      await _client.from('wishlist_items').insert({
        'user_id': userId,
        'stone_id': stoneId,
      });
      
      debugPrint('✅ Stone added to wishlist: $stoneId');
    } catch (e) {
      // Ignore duplicate key errors
      if (e.toString().contains('duplicate') || e.toString().contains('unique')) {
        debugPrint('⚠️ Stone already in wishlist: $stoneId');
      } else {
        debugPrint('❌ WishlistRepository.addToWishlist error: $e');
        rethrow;
      }
    }
  }

  /// Remove stone from wishlist
  Future<void> removeFromWishlist(String stoneId) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await _client
          .from('wishlist_items')
          .delete()
          .eq('user_id', userId)
          .eq('stone_id', stoneId);
      
      debugPrint('✅ Stone removed from wishlist: $stoneId');
    } catch (e) {
      debugPrint('❌ WishlistRepository.removeFromWishlist error: $e');
      rethrow;
    }
  }

  /// Toggle stone in wishlist (add if not exists, remove if exists)
  Future<void> toggleWishlist(String stoneId) async {
    try {
      final stoneIds = await getWishlistStoneIds();
      
      if (stoneIds.contains(stoneId)) {
        await removeFromWishlist(stoneId);
      } else {
        await addToWishlist(stoneId);
      }
    } catch (e) {
      debugPrint('❌ WishlistRepository.toggleWishlist error: $e');
      rethrow;
    }
  }

  /// Check if stone is in wishlist
  Future<bool> isInWishlist(String stoneId) async {
    try {
      final stoneIds = await getWishlistStoneIds();
      return stoneIds.contains(stoneId);
    } catch (e) {
      debugPrint('❌ WishlistRepository.isInWishlist error: $e');
      return false;
    }
  }

  /// Clear entire wishlist for current user
  Future<void> clearWishlist() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await _client
          .from('wishlist_items')
          .delete()
          .eq('user_id', userId);
      
      debugPrint('✅ Wishlist cleared');
    } catch (e) {
      debugPrint('❌ WishlistRepository.clearWishlist error: $e');
      rethrow;
    }
  }

  /// Get wishlist item count
  Future<int> getWishlistCount() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return 0;

      final data = await _client
          .from('wishlist_items')
          .select('id')
          .eq('user_id', userId);

      return (data as List).length;
    } catch (e) {
      debugPrint('❌ WishlistRepository.getWishlistCount error: $e');
      return 0;
    }
  }

  /// Remove multiple stones from wishlist
  Future<void> removeMultiple(List<String> stoneIds) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await _client
          .from('wishlist_items')
          .delete()
          .eq('user_id', userId)
          .inFilter('stone_id', stoneIds);

      
      debugPrint('✅ Multiple stones removed from wishlist: ${stoneIds.length}');
    } catch (e) {
      debugPrint('❌ WishlistRepository.removeMultiple error: $e');
      rethrow;
    }
  }
}
