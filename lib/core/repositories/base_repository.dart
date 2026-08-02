import '../network/api_client.dart';
import '../network/exceptions.dart';

/// Base repository with shared logic for all feature repositories.
abstract class BaseRepository {
  final ApiClient api;

  BaseRepository(this.api);

  /// Wraps any async call with统一 error handling.
  Future<T> safeCall<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException(
        message: 'Unexpected error: $e',
        type: ExceptionType.unknown,
      );
    }
  }
}
