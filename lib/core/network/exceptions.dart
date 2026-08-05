enum ExceptionType {
  network,
  connectionError,
  badRequest,
  unauthorized,
  forbidden,
  notFound,
  server,
  cancel,
  unknown,
}

class AppException implements Exception {
  final String message;
  final ExceptionType type;
  final int? statusCode;

  AppException({
    required this.message,
    required this.type,
    this.statusCode,
  });

  @override
  String toString() => 'AppException: $message (${type.name})';

  String get userFriendlyMessage {
    switch (type) {
      case ExceptionType.network:
        return 'No internet connection. Please check your network.';
      case ExceptionType.connectionError:
        return 'Unable to connect. Please check your internet and try again.';
      case ExceptionType.unauthorized:
        return 'Session expired. Please login again.';
      case ExceptionType.notFound:
        return 'The item you are looking for could not be found.';
      case ExceptionType.server:
        return 'Something went wrong on our end. Please try again.';
      default:
        return message;
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException: $message';
}

class ValidationException extends ApiException {
  ValidationException(super.message, {super.statusCode});
}

class UnauthorizedException extends ApiException {
  UnauthorizedException(super.message, {super.statusCode});
}

class ForbiddenException extends ApiException {
  ForbiddenException(super.message, {super.statusCode});
}

class NotFoundException extends ApiException {
  NotFoundException(super.message, {super.statusCode});
}

class ServerException extends ApiException {
  ServerException(super.message, {super.statusCode});
}

