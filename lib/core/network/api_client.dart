import 'package:dio/dio.dart';

import 'exceptions.dart';

class ApiClient {
  final Dio _dio;

  ApiClient({String baseUrl = 'https://api.graziastones.com/v1'})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ));

  /// Add interceptors from outside — used by DI providers.
  void addInterceptors(List<Interceptor> interceptors) {
    _dio.interceptors.addAll(interceptors);
  }

  Dio get dio => _dio;

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return response;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return response;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return response;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return response;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.patch(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return response;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  AppException _handleError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return AppException(
          message: 'Connection timeout. Please check your internet.',
          type: ExceptionType.network,
        );
      case DioExceptionType.badResponse:
        return _handleBadResponse(e.response?.statusCode, e.response?.data);
      case DioExceptionType.cancel:
        return AppException(
          message: 'Request cancelled',
          type: ExceptionType.cancel,
        );
      default:
        if (e.type == DioExceptionType.connectionError) {
          return AppException(
            message: 'No internet connection',
            type: ExceptionType.connectionError,
          );
        }
        return AppException(
          message: 'An unexpected error occurred',
          type: ExceptionType.unknown,
        );
    }
  }

  AppException _handleBadResponse(int? statusCode, dynamic data) {
    switch (statusCode) {
      case 400:
        return AppException(
          message: data?['message'] ?? 'Bad request',
          type: ExceptionType.badRequest,
          statusCode: statusCode,
        );
      case 401:
        return AppException(
          message: 'Unauthorized. Please login again.',
          type: ExceptionType.unauthorized,
          statusCode: statusCode,
        );
      case 403:
        return AppException(
          message: 'Access denied',
          type: ExceptionType.forbidden,
          statusCode: statusCode,
        );
      case 404:
        return AppException(
          message: 'Resource not found',
          type: ExceptionType.notFound,
          statusCode: statusCode,
        );
      case 500:
        return AppException(
          message: 'Server error. Please try again later.',
          type: ExceptionType.server,
          statusCode: statusCode,
        );
      default:
        return AppException(
          message: data?['message'] ?? 'Unknown error',
          type: ExceptionType.unknown,
          statusCode: statusCode,
        );
    }
  }
}
