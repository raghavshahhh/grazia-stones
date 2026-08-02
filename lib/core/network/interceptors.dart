import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthInterceptor extends Interceptor {
  String? _token;

  void setToken(String token) {
    _token = token;
  }

  void clearToken() {
    _token = null;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_token != null) {
      options.headers['Authorization'] = 'Bearer $_token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      _token = null;
    }
    handler.next(err);
  }

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
  }

  Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<void> removeToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }
}

class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('🌐 REQUEST: ${options.method} ${options.uri}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint('✅ RESPONSE: ${response.statusCode} ${response.requestOptions.uri}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint('❌ ERROR: ${err.type} ${err.message}');
    handler.next(err);
  }
}

class RetryInterceptor extends Interceptor {
  final int maxRetries;
  final Duration retryDelay;

  RetryInterceptor({
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 1),
  });

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final retryCount = err.requestOptions.extra['retryCount'] ?? 0;

    if (retryCount < maxRetries &&
        err.type == DioExceptionType.connectionTimeout) {
      err.requestOptions.extra['retryCount'] = retryCount + 1;

      await Future.delayed(retryDelay * (retryCount + 1));

      try {
        final dio = Dio();
        final response = await dio.fetch(err.requestOptions);
        handler.resolve(response);
        return;
      } catch (_) {
        handler.next(err);
        return;
      }
    }

    handler.next(err);
  }
}

/// Blocks requests when device is offline.
class ConnectivityInterceptor extends Interceptor {
  final Connectivity _connectivity = Connectivity();

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final result = await _connectivity.checkConnectivity();
    if (result == ConnectivityResult.none) {
      handler.reject(DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: 'No internet connection',
      ));
      return;
    }
    handler.next(options);
  }
}

/// Adds device info headers for analytics.
class DeviceInfoInterceptor extends Interceptor {
  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['X-Platform'] = defaultTargetPlatform.name;
    options.headers['X-App-Version'] = '1.0.0'; // wire up from package_info_plus
    handler.next(options);
  }
}
