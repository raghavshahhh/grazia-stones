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

    // Guests can insert (RLS: "Anyone can create quotes") but can't read the
    // row back (RLS select is own-user-only — a guest-readable policy would
    // leak every guest's phone/company). Skip the round-trip for guests.
    if (_userId == null) {
      await _sb.client.from('quote_requests').insert(data);
      return QuoteRequest(
        id: '',
        stoneName: stoneName ?? 'Architectural Stone',
        finish: 'Natural',
        area: areaSqft?.toString() ?? '150 sq.ft.',
        notes: message ?? '',
        createdAt: DateTime.now(),
      );
    }

    final res = await _sb.client.from('quote_requests').insert(data).select().single();

    // Real notification for logged-in users (guests have no rows to read).
    if (_userId != null) {
      try {
        await _sb.client.from('notifications').insert({
          'user_id': _userId,
          'title': 'Quote request received',
          'body': 'We received your quote request for $stoneName. Our team will respond shortly.',
          'type': 'quote',
          'action_url': '/quotes',
        });
      } catch (_) {}
    }

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
