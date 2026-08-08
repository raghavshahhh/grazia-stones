import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/order.dart';
import '../../../core/repositories/order_repository.dart';

// ─── State ───
class OrderRiverpodState {
  final List<Order> orders;
  final Order? selectedOrder;
  final bool isLoading;
  final String? error;

  OrderRiverpodState({
    this.orders = const [],
    this.selectedOrder,
    this.isLoading = false,
    this.error,
  });

  int get count => orders.length;
  List<Order> get activeOrders => orders.where((o) => o.status != 'Cancelled').toList();

  OrderRiverpodState copyWith({
    List<Order>? orders,
    Order? selectedOrder,
    bool? isLoading,
    String? error,
  }) {
    return OrderRiverpodState(
      orders: orders ?? this.orders,
      selectedOrder: selectedOrder ?? this.selectedOrder,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ─── Notifier ───
class OrderRiverpodNotifier extends StateNotifier<OrderRiverpodState> {
  final OrderRepository? _repo;

  OrderRiverpodNotifier([this._repo]) : super(OrderRiverpodState());

  void selectOrder(Order order) {
    state = state.copyWith(selectedOrder: order);
  }

  // ─── API methods ───
  Future<void> loadOrders() async {
    final repo = _repo;
    if (repo == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final orders = await repo.getOrders();
      state = state.copyWith(orders: orders, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> createOrder({
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> address,
    required String paymentMethod,
    String? notes,
  }) async {
    final repo = _repo;
    if (repo == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final order = await repo.createOrder(
        items: items,
        address: address,
        paymentMethod: paymentMethod,
        notes: notes,
      );
      state = state.copyWith(
        orders: [order, ...state.orders],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> cancelOrder(String orderId) async {
    final repo = _repo;
    if (repo == null) return;
    try {
      await repo.cancelOrder(orderId);
      state = state.copyWith(
        orders: state.orders.map((o) {
          if (o.id == orderId) {
            return Order(
              id: o.id,
              stoneNames: o.stoneNames,
              totalAmount: o.totalAmount,
              status: 'Cancelled',
              createdAt: o.createdAt,
            );
          }
          return o;
        }).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}
