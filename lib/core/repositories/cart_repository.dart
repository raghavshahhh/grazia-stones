import '../models/cart_item.dart';
import '../services/supabase_service.dart';

/// Cart repository backed by Supabase `cart_items` table.
class CartRepository {
  final SupabaseService _sb = SupabaseService.instance;

  String get _userId {
    final id = _sb.currentUser?.id;
    if (id == null) throw Exception('Not logged in');
    return id;
  }

  Future<List<CartItem>> getCartItems() async {
    final data = await _sb.client
        .from('cart_items')
        .select('*, stones(id, name, images, price_per_sqft, product_code, stock_status)')
        .eq('user_id', _userId)
        .order('created_at');
    return data.map((j) => CartItem.fromJson(j)).toList();
  }

  Future<void> addToCart(String stoneId, int quantity, {String? notes}) async {
    // Upsert: if item exists, increment quantity
    final existing = await _sb.client
        .from('cart_items')
        .select('id, quantity')
        .eq('user_id', _userId)
        .eq('stone_id', stoneId)
        .maybeSingle();

    if (existing != null) {
      await _sb.client.from('cart_items').update({
        'quantity': existing['quantity'] + quantity,
      }).eq('id', existing['id']);
    } else {
      // Get stone price
      final stone = await _sb.client
          .from('stones')
          .select('price_per_sqft')
          .eq('id', stoneId)
          .single();
      await _sb.client.from('cart_items').insert({
        'user_id': _userId,
        'stone_id': stoneId,
        'quantity': quantity,
        'unit_price': stone['price_per_sqft'],
        'notes': notes,
      });
    }
  }

  Future<void> updateCartItem(String itemId, int quantity) async {
    if (quantity <= 0) {
      await removeFromCart(itemId);
      return;
    }
    await _sb.client
        .from('cart_items')
        .update({'quantity': quantity})
        .eq('id', itemId)
        .eq('user_id', _userId);
  }

  Future<void> removeFromCart(String itemId) async {
    await _sb.client
        .from('cart_items')
        .delete()
        .eq('id', itemId)
        .eq('user_id', _userId);
  }

  Future<void> clearCart() async {
    await _sb.client
        .from('cart_items')
        .delete()
        .eq('user_id', _userId);
  }

  Future<Map<String, dynamic>> getCartSummary() async {
    final items = await getCartItems();
    final subtotal = items.fold<double>(0, (sum, i) => sum + (i.pricePerSqFt * i.quantity));
    final total = subtotal; // Add tax/shipping logic here later
    return {
      'items': items,
      'subtotal': subtotal,
      'shipping': 0.0,
      'tax': 0.0,
      'total': total,
      'itemCount': items.length,
    };
  }
}
