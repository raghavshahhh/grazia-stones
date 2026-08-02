import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/stone.dart';
import '../../../core/repositories/stone_repository.dart';

// ─── State ───
class SearchRiverpodState {
  final String query;
  final List<Stone> results;
  final List<String> recentSearches;
  final bool isLoading;
  final String? error;

  SearchRiverpodState({
    this.query = '',
    this.results = const [],
    this.recentSearches = const [],
    this.isLoading = false,
    this.error,
  });

  bool get hasResults => results.isNotEmpty;
  bool get isNotEmpty => query.isNotEmpty;

  SearchRiverpodState copyWith({
    String? query,
    List<Stone>? results,
    List<String>? recentSearches,
    bool? isLoading,
    String? error,
  }) {
    return SearchRiverpodState(
      query: query ?? this.query,
      results: results ?? this.results,
      recentSearches: recentSearches ?? this.recentSearches,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ─── Notifier ───
class SearchRiverpodNotifier extends StateNotifier<SearchRiverpodState> {
  final StoneRepository? _repo;

  SearchRiverpodNotifier([this._repo]) : super(SearchRiverpodState());

  void setQuery(String query) {
    state = state.copyWith(query: query);
  }

  void clearResults() {
    state = state.copyWith(results: [], query: '');
  }

  void addRecentSearch(String query) {
    if (query.trim().isEmpty) return;
    final updated = [query, ...state.recentSearches.where((s) => s != query)].take(10).toList();
    state = state.copyWith(recentSearches: updated);
  }

  void removeRecentSearch(String query) {
    state = state.copyWith(
      recentSearches: state.recentSearches.where((s) => s != query).toList(),
    );
  }

  void clearRecentSearches() {
    state = state.copyWith(recentSearches: []);
  }

  // ─── API methods ───
  Future<void> search(String query) async {
    final repo = _repo;
    if (query.trim().isEmpty) {
      clearResults();
      return;
    }
    setQuery(query);
    addRecentSearch(query);
    if (repo == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await repo.searchStones(query);
      state = state.copyWith(results: results, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}
