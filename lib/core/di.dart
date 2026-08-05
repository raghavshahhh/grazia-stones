import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../features/cart/providers/cart_riverpod_provider.dart';
import '../features/auth/providers/auth_riverpod_provider.dart';
import '../features/quotes/providers/quote_riverpod_provider.dart';
import '../features/orders/providers/order_riverpod_provider.dart';
import '../core/network/api_client.dart';
import '../core/repositories/stone_repository.dart';
import '../core/repositories/collection_repository.dart';
import '../core/repositories/dealer_repository.dart';
import '../core/repositories/cart_repository.dart';
import '../core/repositories/order_repository.dart';
import '../core/repositories/user_repository.dart';

// ─── Network ───
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: 'https://api.graziastones.com/v1',
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));
  return dio;
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(baseUrl: 'https://api.graziastones.com/v1');
});

// ─── Repositories ───
final stoneRepositoryProvider = Provider<StoneRepository>((ref) {
  return StoneRepository(ref.watch(apiClientProvider));
});

final collectionRepositoryProvider = Provider<CollectionRepository>((ref) {
  return CollectionRepository(ref.watch(apiClientProvider));
});

final dealerRepositoryProvider = Provider<DealerRepository>((ref) {
  return DealerRepository(ref.watch(apiClientProvider));
});

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return CartRepository(ref.watch(apiClientProvider));
});

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository(ref.watch(apiClientProvider));
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(apiClientProvider));
});

// ─── State Notifiers (Riverpod) ───
final cartRiverpodProvider = StateNotifierProvider<CartRiverpodNotifier, CartRiverpodState>((ref) {
  return CartRiverpodNotifier();
});

final authRiverpodProvider = StateNotifierProvider<AuthRiverpodNotifier, AuthRiverpodState>((ref) {
  return AuthRiverpodNotifier();
});

final quoteRiverpodProvider = StateNotifierProvider<QuoteRiverpodNotifier, QuoteRiverpodState>((ref) {
  return QuoteRiverpodNotifier();
});

final orderRiverpodProvider = StateNotifierProvider<OrderRiverpodNotifier, OrderRiverpodState>((ref) {
  return OrderRiverpodNotifier();
});
