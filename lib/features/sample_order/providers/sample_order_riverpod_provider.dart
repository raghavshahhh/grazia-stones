import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/sample_order.dart';
import '../../../core/repositories/sample_order_repository.dart';

// ─── State ───
class SampleOrderRiverpodState {
  final List<SampleOrder> orders;
  final bool isLoading;
  final String? error;
  final bool submitted;

  SampleOrderRiverpodState({
    this.orders = const [],
    this.isLoading = false,
    this.error,
    this.submitted = false,
  });

  int get count => orders.length;

  SampleOrderRiverpodState copyWith({
    List<SampleOrder>? orders,
    bool? isLoading,
    String? error,
    bool? submitted,
  }) {
    return SampleOrderRiverpodState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      submitted: submitted ?? this.submitted,
    );
  }
}

// ─── Notifier ───
class SampleOrderRiverpodNotifier extends StateNotifier<SampleOrderRiverpodState> {
  final SampleOrderRepository? _repo;

  SampleOrderRiverpodNotifier([this._repo]) : super(SampleOrderRiverpodState());

  void resetSubmitted() {
    state = state.copyWith(submitted: false);
  }

  // ─── API methods ───
  Future<void> loadSampleOrders() async {
    final repo = _repo;
    if (repo == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final orders = await repo.getSampleOrders();
      state = state.copyWith(orders: orders, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> requestSample({
    required String stoneId,
    required String stoneName,
    required String name,
    required String phone,
    required String address,
    required String city,
    required String pincode,
    String? notes,
  }) async {
    final repo = _repo;
    state = state.copyWith(isLoading: true, error: null, submitted: false);
    if (repo == null) {
      state = state.copyWith(isLoading: false, error: 'Repository not available');
      return;
    }
    try {
      final order = await repo.requestSample(
        stoneId: stoneId,
        name: name,
        phone: phone,
        address: address,
        city: city,
        pincode: pincode,
        notes: notes,
      );
      state = state.copyWith(
        orders: [order, ...state.orders],
        isLoading: false,
        submitted: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}
