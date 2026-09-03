import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/quote_request.dart';
import '../../../core/repositories/quote_repository.dart';

// ─── State ───
class QuoteRiverpodState {
  final List<QuoteRequest> quotes;
  final bool isLoading;
  final String? error;

  QuoteRiverpodState({
    this.quotes = const [],
    this.isLoading = false,
    this.error,
  });

  int get count => quotes.length;
  List<QuoteRequest> get pending => quotes.where((q) => q.status == 'Pending').toList();

  QuoteRiverpodState copyWith({
    List<QuoteRequest>? quotes,
    bool? isLoading,
    String? error,
  }) {
    return QuoteRiverpodState(
      quotes: quotes ?? this.quotes,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ─── Notifier ───
class QuoteRiverpodNotifier extends StateNotifier<QuoteRiverpodState> {
  final QuoteRepository? _repo;

  /// Starts empty — real quotes load via the repository (see
  /// quotes_screen.dart's quotesProvider). Never seeded with demo rows.
  QuoteRiverpodNotifier([this._repo])
      : super(QuoteRiverpodState(quotes: []));

  void addQuote(QuoteRequest quote) {
    state = state.copyWith(quotes: [quote, ...state.quotes]);
  }

  void removeQuote(String id) {
    state = state.copyWith(
      quotes: state.quotes.where((q) => q.id != id).toList(),
    );
  }

  void updateQuoteStatus(String id, String status) {
    state = state.copyWith(
      quotes: state.quotes.map((q) {
        if (q.id == id) return q.copyWith(status: status);
        return q;
      }).toList(),
    );
  }

  // ─── API methods ───
  Future<void> loadQuotes() async {
    if (_repo == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final quotes = await _repo.getQuotes();
      state = state.copyWith(quotes: quotes, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> createQuote({
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
    if (_repo == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final quote = await _repo.createQuote(
        name: name,
        phone: phone,
        email: email,
        company: company,
        stoneId: stoneId,
        stoneName: stoneName,
        quantity: quantity,
        areaSqft: areaSqft,
        message: message,
      );
      state = state.copyWith(
        quotes: [quote, ...state.quotes],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}
