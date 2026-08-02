import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/collection.dart';
import '../../../core/repositories/collection_repository.dart';

// ─── State ───
class CollectionRiverpodState {
  final List<Collection> collections;
  final Collection? selectedCollection;
  final bool isLoading;
  final String? error;

  CollectionRiverpodState({
    this.collections = const [],
    this.selectedCollection,
    this.isLoading = false,
    this.error,
  });

  CollectionRiverpodState copyWith({
    List<Collection>? collections,
    Collection? selectedCollection,
    bool? isLoading,
    String? error,
  }) {
    return CollectionRiverpodState(
      collections: collections ?? this.collections,
      selectedCollection: selectedCollection ?? this.selectedCollection,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ─── Notifier ───
class CollectionRiverpodNotifier extends StateNotifier<CollectionRiverpodState> {
  final CollectionRepository? _repo;

  CollectionRiverpodNotifier([this._repo]) : super(CollectionRiverpodState());

  void selectCollection(Collection collection) {
    state = state.copyWith(selectedCollection: collection);
  }

  void clearSelection() {
    state = state.copyWith(selectedCollection: null);
  }

  // ─── API methods ───
  Future<void> loadCollections() async {
    final repo = _repo;
    if (repo == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final collections = await repo.getCollections();
      state = state.copyWith(collections: collections, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadById(String id) async {
    final repo = _repo;
    if (repo == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final collection = await repo.getCollectionById(id);
      state = state.copyWith(selectedCollection: collection, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}
