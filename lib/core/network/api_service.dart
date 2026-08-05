import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../services/storage_service.dart';
import '../services/firebase_service.dart';
import 'api_response.dart';
import 'exceptions.dart';

/// Centralized API service with error handling, retry logic, and auth
class ApiService {
  static ApiService? _instance;
  static ApiService get instance => _instance ??= ApiService._();
  
  ApiService._();

  late Dio _dio;
  final StorageService _storage = StorageService.instance;
  final FirebaseService _firebase = FirebaseService.instance;

  // Base URL - Change this to your actual backend URL
  static const String _baseUrl = 'https://api.graziastones.com/v1';
  static const String _devUrl = 'http://localhost:3000/api/v1';
  
  // Use dev URL in debug mode
  String get baseUrl => kDebugMode ? _devUrl : _baseUrl;

  /// Initialize Dio with interceptors
  void init() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Add interceptors
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onResponse: _onResponse,
        onError: _onError,
      ),
    );

    // Add logging interceptor in debug mode
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        requestHeader: true,
        responseHeader: false,
        error: true,
      ));
    }

    debugPrint('✅ API Service initialized with base URL: $baseUrl');
  }

  // ═══════════════════════════════════════════════════════════════════════
  // INTERCEPTORS
  // ═══════════════════════════════════════════════════════════════════════

  /// Add auth token to requests
  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Get token from Firebase or storage
    String? token = await _firebase.getIdToken();
    token ??= await _storage.getAuthToken();

    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    debugPrint('🌐 ${options.method} ${options.path}');
    handler.next(options);
  }

  /// Handle successful responses
  void _onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) {
    debugPrint('✅ Response: ${response.statusCode} ${response.requestOptions.path}');
    handler.next(response);
  }

  /// Handle errors with retry logic
  Future<void> _onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    debugPrint('❌ Error: ${err.type} ${err.requestOptions.path}');

    // Handle token expiration
    if (err.response?.statusCode == 401) {
      debugPrint('🔄 Token expired, refreshing...');
      
      try {
        // Refresh Firebase token
        await _firebase.refreshToken();
        final newToken = await _firebase.getIdToken(forceRefresh: true);
        
        if (newToken != null) {
          // Retry request with new token
          final options = err.requestOptions;
          options.headers['Authorization'] = 'Bearer $newToken';
          
          final response = await _dio.fetch(options);
          return handler.resolve(response);
        }
      } catch (e) {
        debugPrint('❌ Token refresh failed: $e');
      }
    }

    // Handle network errors with retry
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout) {
      
      final retryCount = err.requestOptions.extra['retryCount'] ?? 0;
      
      if (retryCount < 2) {
        debugPrint('🔄 Retrying request... (${retryCount + 1}/3)');
        
        await Future.delayed(Duration(seconds: retryCount + 1));
        
        final options = err.requestOptions;
        options.extra['retryCount'] = retryCount + 1;
        
        try {
          final response = await _dio.fetch(options);
          return handler.resolve(response);
        } catch (e) {
          debugPrint('❌ Retry failed: $e');
        }
      }
    }

    handler.next(err);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // HTTP METHODS
  // ═══════════════════════════════════════════════════════════════════════

  /// GET request
  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
      );
      return ApiResponse<T>.fromResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw ApiException('Unexpected error: $e');
    }
  }

  /// POST request
  Future<ApiResponse<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return ApiResponse<T>.fromResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw ApiException('Unexpected error: $e');
    }
  }

  /// PUT request
  Future<ApiResponse<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return ApiResponse<T>.fromResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw ApiException('Unexpected error: $e');
    }
  }

  /// PATCH request
  Future<ApiResponse<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.patch(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return ApiResponse<T>.fromResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw ApiException('Unexpected error: $e');
    }
  }

  /// DELETE request
  Future<ApiResponse<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return ApiResponse<T>.fromResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw ApiException('Unexpected error: $e');
    }
  }

  /// Upload file
  Future<ApiResponse<T>> upload<T>(
    String path,
    String filePath, {
    String fieldName = 'file',
    Map<String, dynamic>? data,
    ProgressCallback? onSendProgress,
  }) async {
    try {
      final formData = FormData.fromMap({
        fieldName: await MultipartFile.fromFile(filePath),
        ...?data,
      });

      final response = await _dio.post(
        path,
        data: formData,
        onSendProgress: onSendProgress,
      );
      
      return ApiResponse<T>.fromResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw ApiException('Upload failed: $e');
    }
  }

  /// Download file
  Future<void> download(
    String urlPath,
    String savePath, {
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      await _dio.download(
        urlPath,
        savePath,
        onReceiveProgress: onReceiveProgress,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw ApiException('Download failed: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ERROR HANDLING
  // ═══════════════════════════════════════════════════════════════════════

  /// Convert DioException to custom ApiException
  ApiException _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException('Connection timeout. Please check your internet connection.');
        
      case DioExceptionType.badResponse:
        return _handleResponseError(error.response);
        
      case DioExceptionType.cancel:
        return ApiException('Request cancelled');
        
      case DioExceptionType.connectionError:
        return ApiException('No internet connection. Please check your network.');
        
      case DioExceptionType.badCertificate:
        return ApiException('SSL certificate error');
        
      case DioExceptionType.unknown:
        if (error.error.toString().contains('SocketException')) {
          return ApiException('No internet connection');
        }
        return ApiException('Unexpected error: ${error.message}');
        
      default:
        return ApiException('An error occurred: ${error.message}');
    }
  }

  /// Handle HTTP response errors
  ApiException _handleResponseError(Response? response) {
    if (response == null) {
      return ApiException('No response from server');
    }

    final statusCode = response.statusCode ?? 0;
    final data = response.data;

    // Extract error message from response
    String message = 'An error occurred';
    if (data is Map<String, dynamic>) {
      message = data['message'] ?? data['error'] ?? message;
    }

    switch (statusCode) {
      case 400:
        return ValidationException(message);
      case 401:
        return UnauthorizedException(message);
      case 403:
        return ForbiddenException(message);
      case 404:
        return NotFoundException(message);
      case 422:
        return ValidationException(message);
      case 429:
        return ApiException('Too many requests. Please try again later.');
      case 500:
      case 502:
      case 503:
      case 504:
        return ServerException('Server error. Please try again later.');
      default:
        return ApiException('Error $statusCode: $message');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // UTILITY
  // ═══════════════════════════════════════════════════════════════════════

  /// Cancel all pending requests
  void cancelRequests() {
    _dio.close(force: true);
  }

  /// Get Dio instance for custom operations
  Dio get dio => _dio;
}
