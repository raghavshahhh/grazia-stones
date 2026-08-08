import '../models/sample_order.dart';
import '../services/supabase_service.dart';

/// Sample order repository backed by Supabase.
class SampleOrderRepository {
  final SupabaseService _sb = SupabaseService.instance;

  String get _userId {
    final id = _sb.currentUser?.id;
    if (id == null) throw Exception('Not logged in');
    return id;
  }

  Future<List<SampleOrder>> getSampleOrders() async {
    final data = await _sb.client
        .from('orders')
        .select('*, order_items(*)')
        .eq('user_id', _userId)
        .eq('is_sample', true)
        .order('created_at', ascending: false);
    return data.map((j) => SampleOrder.fromJson(j)).toList();
  }

  Future<SampleOrder> requestSample({
    required String stoneId,
    required String name,
    required String phone,
    required String address,
    required String city,
    required String pincode,
    String? notes,
  }) async {
    final now = DateTime.now();
    final orderNum = 'GS-SAMPLE-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch.toString().substring(8)}';

    final orderData = {
      'user_id': _userId,
      'order_number': orderNum,
      'status': 'pending',
      'subtotal': 0,
      'shipping_cost': 0,
      'tax': 0,
      'discount': 0,
      'total': 0,
      'currency': 'INR',
      'shipping_name': name,
      'shipping_phone': phone,
      'shipping_address': address,
      'shipping_city': city,
      'shipping_state': '',
      'shipping_pincode': pincode,
      'payment_method': 'cod',
      'payment_status': 'pending',
      'notes': 'SAMPLE ORDER - ${notes ?? ''}',
      'is_sample': true,
    };

    final orderRes = await _sb.client.from('orders').insert(orderData).select().single();

    await _sb.client.from('order_items').insert({
      'order_id': orderRes['id'],
      'stone_id': stoneId,
      'name': 'Sample',
      'product_code': '',
      'image_url': '',
      'quantity': 1,
      'unit_price': 0,
      'total_price': 0,
    });

    // Fetch full order with items
    final fullData = await _sb.client
        .from('orders')
        .select('*, order_items(*)')
        .eq('id', orderRes['id'])
        .single();
    return SampleOrder.fromJson(fullData);
  }
}
