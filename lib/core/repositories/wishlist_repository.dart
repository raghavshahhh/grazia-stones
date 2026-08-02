import '../models/wishlist_item.dart';
import '../repositories/base_repository.dart';

class WishlistRepository extends BaseRepository {
  WishlistRepository(super.api);

  Future<List<WishlistItem>> getWishlist() async {
    return safeCall(() async {
      final response = await api.get('/wishlist');
      return (response.data['data'] as List)
          .map((j) => WishlistItem.fromJson(j))
          .toList();
    });
  }

  Future<void> addToWishlist(String stoneId) async {
    await safeCall(() async {
      await api.post('/wishlist', data: {'stoneId': stoneId});
    });
  }

  Future<void> removeFromWishlist(String itemId) async {
    await safeCall(() async {
      await api.delete('/wishlist/$itemId');
    });
  }

  Future<void> moveToCart(String itemId) async {
    await safeCall(() async {
      await api.post('/wishlist/$itemId/move-to-cart');
    });
  }
}
