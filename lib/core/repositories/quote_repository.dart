import '../models/quote_request.dart';
import '../services/supabase_service.dart';

class QuoteRepository {
  final SupabaseService _sb = SupabaseService.instance;

  String? get _userId => _sb.currentUser?.id;

  Future<List<QuoteRequest>> getQuotes() async {
    final uid = _userId;
    if (uid == null) return [];
    final data = await _sb.client
        .from('quote_requests')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    return (data as List).map((j) => QuoteRequest.fromJson(j)).toList();
  }

  Future<QuoteRequest> createQuote({
    required String name,
    required String phone,
    String? email,
    String? company,
    String? stoneId,
    String? stoneName,
    int? quantity,
    double? areaSqft,
    String? message,
  }) async {
    final data = {
      'user_id': _userId,
      'name': name,
      'phone': phone,
      'email': email,
      'company': company,
      'stone_id': stoneId,
      'stone_name': stoneName,
      'quantity': quantity ?? 1,
      'area_sqft': areaSqft,
      'message': message,
    };

    final res = await _sb.client.from('quote_requests').insert(data).select().single();
    return QuoteRequest.fromJson(res);
  }

  Future<void> cancelQuote(String quoteId) async {
    final uid = _userId;
    if (uid != null) {
      await _sb.client
          .from('quote_requests')
          .update({'status': 'cancelled'})
          .eq('id', quoteId)
          .eq('user_id', uid);
    }
  }
}
