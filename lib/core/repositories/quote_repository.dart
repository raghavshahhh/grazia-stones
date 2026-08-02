import '../models/quote_request.dart';
import '../repositories/base_repository.dart';

class QuoteRepository extends BaseRepository {
  QuoteRepository(super.api);

  Future<List<QuoteRequest>> getQuotes() async {
    return safeCall(() async {
      final response = await api.get('/quotes');
      return (response.data['data'] as List)
          .map((j) => QuoteRequest.fromJson(j))
          .toList();
    });
  }

  Future<QuoteRequest> createQuote({
    required String stoneId,
    required int quantity,
    String? notes,
  }) async {
    return safeCall(() async {
      final response = await api.post('/quotes', data: {
        'stoneId': stoneId,
        'quantity': quantity,
        if (notes != null) 'notes': notes,
      });
      return QuoteRequest.fromJson(response.data);
    });
  }

  Future<void> cancelQuote(String quoteId) async {
    await safeCall(() async {
      await api.post('/quotes/$quoteId/cancel');
    });
  }
}
