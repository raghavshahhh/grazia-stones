import '../models/sample_order.dart';
import '../services/supabase_service.dart';

/// Sample order repository backed by Supabase.
class SampleOrderRepository {
  final SupabaseService _sb = SupabaseService.instance;

  String? get _userId => _sb.currentUser?.id;

  Future<List<SampleOrder>> getSampleOrders() async {
    final uid = _userId;
    if (uid == null) return [];
    final data = await _sb.client
        .from('sample_requests')
        .select()
        .eq('user_id', uid)
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
    String? stoneName,
  }) async {
    final sampleData = {
      'user_id': _userId,
      'stone_id': stoneId.startsWith('http') || stoneId.length < 10 ? null : stoneId,
      'name': name,
      'phone': phone,
      'address': address,
      'city': city,
      'pincode': pincode,
      'stone_name': stoneName ?? 'Architectural Stone Sample',
      'quantity': 1,
      'message': notes,
      'status': 'pending',
    };

    // Guests can insert (RLS: "Anyone can create sample requests") but can't
    // read the row back (RLS: select is own-user-only, and a public
    // guest-rows-readable policy would leak every guest's phone/address).
    // So skip the round-trip for guests and build the confirmation locally.
    if (_userId == null) {
      await _sb.client.from('sample_requests').insert(sampleData);
      return SampleOrder(
        id: '',
        stoneId: stoneId,
        stoneName: sampleData['stone_name'] as String,
        name: name,
        phone: phone,
        address: address,
        city: city,
        pincode: pincode,
        createdAt: DateTime.now(),
      );
    }

    final res = await _sb.client.from('sample_requests').insert(sampleData).select().single();
    return SampleOrder.fromJson(res);
  }
}
