import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/dealer.dart';

// ─── State ───
class DealerRiverpodState {
  final List<Dealer> dealers;
  final Dealer? selectedDealer;
  final bool isLoading;
  final String? error;

  DealerRiverpodState({
    this.dealers = const [],
    this.selectedDealer,
    this.isLoading = false,
    this.error,
  });

  DealerRiverpodState copyWith({
    List<Dealer>? dealers,
    Dealer? selectedDealer,
    bool? isLoading,
    String? error,
  }) {
    return DealerRiverpodState(
      dealers: dealers ?? this.dealers,
      selectedDealer: selectedDealer ?? this.selectedDealer,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ─── Simple API service for dealers ───
class DealerApiService {
  final dynamic _api;
  DealerApiService(this._api);

  Future<List<Dealer>> getDealers() async {
    final response = await _api.get('/dealers');
    return (response.data['data'] as List)
        .map((j) => Dealer.fromJson(j))
        .toList();
  }

  Future<Dealer> getDealerById(String id) async {
    final response = await _api.get('/dealers/$id');
    return Dealer.fromJson(response.data);
  }

  Future<List<Dealer>> getNearbyDealers(double lat, double lng) async {
    final response = await _api.get('/dealers/nearby', queryParameters: {
      'lat': lat,
      'lng': lng,
    });
    return (response.data['data'] as List)
        .map((j) => Dealer.fromJson(j))
        .toList();
  }
}

// ─── Notifier ───
class DealerRiverpodNotifier extends StateNotifier<DealerRiverpodState> {
  final DealerApiService? _api;

  DealerRiverpodNotifier([this._api]) : super(DealerRiverpodState());

  void selectDealer(Dealer dealer) {
    state = state.copyWith(selectedDealer: dealer);
  }

  // ─── API methods ───
  Future<void> loadDealers() async {
    final api = _api;
    if (api == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final dealers = await api.getDealers();
      state = state.copyWith(dealers: dealers, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadNearbyDealers(double lat, double lng) async {
    final api = _api;
    if (api == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final dealers = await api.getNearbyDealers(lat, lng);
      state = state.copyWith(dealers: dealers, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}
