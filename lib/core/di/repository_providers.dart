import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';
import '../network/interceptors.dart';
import '../repositories/auth_repository.dart';
import '../repositories/stone_repository.dart';
import '../repositories/collection_repository.dart';
import '../repositories/cart_repository.dart';
import '../repositories/order_repository.dart';
import '../repositories/quote_repository.dart';
import '../repositories/wishlist_repository.dart';
import '../repositories/sample_order_repository.dart';

/// Singleton ApiClient with all interceptors wired.
final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(baseUrl: 'https://api.graziastones.com/v1');

  client.dio.interceptors.addAll([
    AuthInterceptor(),
    ConnectivityInterceptor(),
    DeviceInfoInterceptor(),
    LoggingInterceptor(),
    RetryInterceptor(),
  ]);

  return client;
});

/// Auth interceptor — accessible for token management.
final authInterceptorProvider = Provider<AuthInterceptor>((ref) {
  return AuthInterceptor();
});

/// Repositories — one per feature.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.read(apiClientProvider), ref.read(authInterceptorProvider));
});

final stoneRepositoryProvider = Provider<StoneRepository>((ref) {
  return StoneRepository(ref.read(apiClientProvider));
});

final collectionRepositoryProvider = Provider<CollectionRepository>((ref) {
  return CollectionRepository(ref.read(apiClientProvider));
});

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return CartRepository(ref.read(apiClientProvider));
});

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository(ref.read(apiClientProvider));
});

final quoteRepositoryProvider = Provider<QuoteRepository>((ref) {
  return QuoteRepository(ref.read(apiClientProvider));
});

final wishlistRepositoryProvider = Provider<WishlistRepository>((ref) {
  return WishlistRepository(ref.read(apiClientProvider));
});

final sampleOrderRepositoryProvider = Provider<SampleOrderRepository>((ref) {
  return SampleOrderRepository(ref.read(apiClientProvider));
});
