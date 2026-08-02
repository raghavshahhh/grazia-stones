import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/stone.dart';
import '../../../core/repositories/stone_repository.dart';

// ─── State ───
class StoneRiverpodState {
  final List<Stone> stones;
  final List<Stone> popularStones;
  final List<Stone> newArrivals;
  final Stone? selectedStone;
  final bool isLoading;
  final String? error;
  final int page;
  final bool hasMore;

  StoneRiverpodState({
    this.stones = const [],
    this.popularStones = const [],
    this.newArrivals = const [],
    this.selectedStone,
    this.isLoading = false,
    this.error,
    this.page = 1,
    this.hasMore = true,
  });

  StoneRiverpodState copyWith({
    List<Stone>? stones,
    List<Stone>? popularStones,
    List<Stone>? newArrivals,
    Stone? selectedStone,
    bool? isLoading,
    String? error,
    int? page,
    bool? hasMore,
  }) {
    return StoneRiverpodState(
      stones: stones ?? this.stones,
      popularStones: popularStones ?? this.popularStones,
      newArrivals: newArrivals ?? this.newArrivals,
      selectedStone: selectedStone ?? this.selectedStone,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

// ─── Notifier ───
class StoneRiverpodNotifier extends StateNotifier<StoneRiverpodState> {
  final StoneRepository? _repo;

  StoneRiverpodNotifier([this._repo]) : super(StoneRiverpodState());

  void selectStone(Stone stone) {
    state = state.copyWith(selectedStone: stone);
  }

  void clearSelection() {
    state = state.copyWith(selectedStone: null);
  }

  // ─── API methods ───
  Future<void> loadStones({bool refresh = false}) async {
    final repo = _repo;
    if (repo == null) return;
    if (refresh) {
      state = state.copyWith(page: 1, hasMore: true);
    }
    state = state.copyWith(isLoading: true, error: null);
    try {
      final stones = await repo.getStones(page: state.page);
      state = state.copyWith(
        stones: refresh ? stones : [...state.stones, ...stones],
        isLoading: false,
        hasMore: stones.length >= 20,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading) return;
    state = state.copyWith(page: state.page + 1);
    await loadStones();
  }

  Future<void> loadPopular() async {
    final repo = _repo;
    if (repo == null) return;
    try {
      final stones = await repo.getPopularStones();
      state = state.copyWith(popularStones: stones);
    } catch (_) {}
  }

  Future<void> loadNewArrivals() async {
    final repo = _repo;
    if (repo == null) return;
    try {
      final stones = await repo.getNewArrivals();
      state = state.copyWith(newArrivals: stones);
    } catch (_) {}
  }

  Future<void> search(String query) async {
    final repo = _repo;
    if (repo == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final stones = await repo.searchStones(query);
      state = state.copyWith(stones: stones, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadById(String id) async {
    final repo = _repo;
    if (repo == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final stone = await repo.getStoneById(id);
      state = state.copyWith(selectedStone: stone, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}
