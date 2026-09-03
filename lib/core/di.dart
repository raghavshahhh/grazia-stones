import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/cart/providers/cart_riverpod_provider.dart';
import '../features/auth/providers/auth_riverpod_provider.dart';
import '../features/quotes/providers/quote_riverpod_provider.dart';
import '../features/orders/providers/order_riverpod_provider.dart';
import '../core/repositories/stone_repository.dart';
import '../core/repositories/auth_repository.dart';
import '../core/repositories/cart_repository.dart';
import '../core/repositories/order_repository.dart';
import '../core/repositories/sample_order_repository.dart';
import '../core/repositories/quote_repository.dart';
import '../core/repositories/user_repository.dart';

import '../core/repositories/dealer_repository.dart';
import '../core/repositories/admin_product_repository.dart';
import '../core/repositories/ai_job_repository.dart';
import '../features/wishlist/data/wishlist_repository.dart';
import '../core/error/error_handler.dart';
import '../core/services/permission_service.dart';
import '../core/services/connectivity_service.dart';
import '../core/services/analytics_service.dart';
import '../core/services/crash_reporting_service.dart';
import '../core/services/app_lifecycle_service.dart';
import '../core/services/state_restoration_service.dart';
import '../core/services/deep_link_service.dart';

// ─── Error Handler ───
final errorHandlerProvider = Provider<ErrorHandler>((ref) {
  return ErrorHandler.instance;
});

// ─── Permission Service ───
final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService.instance;
});

// ─── Connectivity Service ───
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService.instance;
});

// ─── Analytics & Monitoring ───
final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService.instance;
});

final crashReportingServiceProvider = Provider<CrashReportingService>((ref) {
  return CrashReportingService.instance;
});

// ─── Lifecycle & State Management ───
final appLifecycleServiceProvider = Provider<AppLifecycleService>((ref) {
  return AppLifecycleService.instance;
});

final stateRestorationServiceProvider = Provider<StateRestorationService>((ref) {
  return StateRestorationService.instance;
});

final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  return DeepLinkService.instance;
});

// ─── Repositories (Supabase-backed, no Dio) ───
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final stoneRepositoryProvider = Provider<StoneRepository>((ref) {
  return StoneRepository();
});

final adminProductRepositoryProvider = Provider<AdminProductRepository>((ref) {
  return AdminProductRepository();
});

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return CartRepository();
});

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository();
});

final sampleOrderRepositoryProvider = Provider<SampleOrderRepository>((ref) {
  return SampleOrderRepository();
});

final quoteRepositoryProvider = Provider<QuoteRepository>((ref) {
  return QuoteRepository();
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

final dealerRepositoryProvider = Provider<DealerRepository>((ref) {
  return DealerRepository();
});

final wishlistRepositoryProvider = Provider<WishlistRepository>((ref) {
  return WishlistRepository();
});

final aiJobRepositoryProvider = Provider<AIJobRepository>((ref) {
  return AIJobRepository();
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
