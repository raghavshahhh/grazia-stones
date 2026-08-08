import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/cart/providers/cart_riverpod_provider.dart';
import '../features/auth/providers/auth_riverpod_provider.dart';
import '../features/quotes/providers/quote_riverpod_provider.dart';
import '../features/orders/providers/order_riverpod_provider.dart';
import '../core/repositories/stone_repository.dart';
import '../core/repositories/auth_repository.dart';
import '../core/repositories/cart_repository.dart';
import '../core/repositories/order_repository.dart';
import '../core/repositories/user_repository.dart';

// ─── Repositories (Supabase-backed, no Dio) ───
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final stoneRepositoryProvider = Provider<StoneRepository>((ref) {
  return StoneRepository();
});

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return CartRepository();
});

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository();
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

// ─── State Notifiers (Riverpod) ───
final cartRiverpodProvider = StateNotifierProvider<CartRiverpodNotifier, CartRiverpodState>((ref) {
  return CartRiverpodNotifier();
});

final authRiverpodProvider = StateNotifierProvider<AuthRiverpodNotifier, AuthRiverpodState>((ref) {
  return AuthRiverpodNotifier(ref.watch(authRepositoryProvider));
});

final quoteRiverpodProvider = StateNotifierProvider<QuoteRiverpodNotifier, QuoteRiverpodState>((ref) {
  return QuoteRiverpodNotifier();
});

final orderRiverpodProvider = StateNotifierProvider<OrderRiverpodNotifier, OrderRiverpodState>((ref) {
  return OrderRiverpodNotifier();
});
