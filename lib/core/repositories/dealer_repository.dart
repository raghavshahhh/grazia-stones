import '../models/dealer.dart';
import '../services/supabase_service.dart';

/// Dealer repository backed by Supabase `dealers` table.
class DealerRepository {
  final SupabaseService _sb = SupabaseService.instance;

  Future<List<Dealer>> getDealers({
    double? latitude,
    double? longitude,
    double? radius,
  }) async {
    try {
      var builder = _sb.client
          .from('dealers')
          .select()
          .eq('active', true)
          .order('rating', ascending: false);

      final data = await builder;
      return data.map((j) => Dealer.fromJson(j)).toList();
    } catch (e) {
      // Dealer list isn't critical path — fail soft to empty rather than
      // breaking whatever screen renders it.
      return [];
    }
  }

  Future<Dealer?> getDealerById(String id) async {
    final data = await _sb.client
        .from('dealers')
        .select()
        .eq('id', id)
        .maybeSingle();
    return data != null ? Dealer.fromJson(data) : null;
  }
}
