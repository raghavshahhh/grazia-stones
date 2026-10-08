import '../models/sample_order.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';

/// Sample order repository backed by Supabase with local fallback.
class SampleOrderRepository {
  final SupabaseService _sb = SupabaseService.instance;

  String? get _userId => _sb.currentUser?.id;

  Future<List<SampleOrder>> getSampleOrders() async {
    final List<SampleOrder> localOrders = StorageService.instance
        .getLocalSampleOrders()
        .map((j) => SampleOrder.fromJson(j))
        .toList();

    final uid = _userId;
    if (uid == null) return localOrders;

    try {
      final data = await _sb.client
          .from('sample_requests')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false);
      final remoteOrders = data.map((j) => SampleOrder.fromJson(j)).toList();

      // Merge remote + local, deduplicating
      final seenKeys = <String>{};
      final merged = <SampleOrder>[];
      for (final o in [...remoteOrders, ...localOrders]) {
        final key = o.id.isNotEmpty ? o.id : '${o.stoneName}_${o.createdAt.millisecondsSinceEpoch}';
        if (seenKeys.add(key)) {
          merged.add(o);
        }
      }
      return merged;
    } catch (_) {
      return localOrders;
    }
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
    final now = DateTime.now();
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

    SampleOrder sampleOrder;

    // Guests can insert (RLS: "Anyone can create sample requests") but can't
    // read the row back (RLS: select is own-user-only, and a public
    // guest-rows-readable policy would leak every guest's phone/address).
    // So skip the round-trip for guests and build the confirmation locally.
    if (_userId == null) {
      try {
        await _sb.client.from('sample_requests').insert(sampleData);
      } catch (_) {}
      sampleOrder = SampleOrder(
        id: 'SMP-${now.millisecondsSinceEpoch.toString().substring(7)}',
        stoneId: stoneId,
        stoneName: sampleData['stone_name'] as String,
        name: name,
        phone: phone,
        address: address,
        city: city,
        pincode: pincode,
        createdAt: now,
      );
    } else {
      try {
        final res = await _sb.client.from('sample_requests').insert(sampleData).select().single();
        sampleOrder = SampleOrder.fromJson(res);
      } catch (_) {
        sampleOrder = SampleOrder(
          id: 'SMP-${now.millisecondsSinceEpoch.toString().substring(7)}',
          stoneId: stoneId,
          stoneName: sampleData['stone_name'] as String,
          name: name,
          phone: phone,
          address: address,
          city: city,
          pincode: pincode,
          createdAt: now,
        );
      }

      // Real notification for logged-in users (guests have no rows to read).
      try {
        await _sb.client.from('notifications').insert({
          'user_id': _userId,
          'title': 'Sample request received',
          'body': 'Your ${sampleData['stone_name']} sample request is being prepared.',
          'type': 'sample',
          'action_url': '/samples',
        });
      } catch (_) {}
    }

    // Save to local storage cache so it immediately shows in My Requests & Dashboard
    await StorageService.instance.saveLocalSampleOrder({
      'id': sampleOrder.id,
      'stone_id': sampleOrder.stoneId,
      'stone_name': sampleOrder.stoneName,
      'name': sampleOrder.name,
      'phone': sampleOrder.phone,
      'address': sampleOrder.address,
      'city': sampleOrder.city,
      'pincode': sampleOrder.pincode,
      'status': 'pending',
      'created_at': sampleOrder.createdAt.toIso8601String(),
    });

    return sampleOrder;
  }
}
