import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'supabase_service.dart';

/// Shared HTTP client for the Vercel-hosted AI proxy endpoints
/// (api/wall-detect.js, api/generate-visualization.js).
///
/// Those endpoints enforce an Origin allowlist meant for browser callers.
/// Native mobile clients don't send an Origin header by default, so we set
/// it explicitly to our own production domain, which is already on the
/// endpoint's allowlist.
///
/// If the user is logged in, their Supabase access token is attached so the
/// endpoint can verify it server-side and apply the authenticated rate
/// limit. Logged-out (guest) calls intentionally omit the header — AI Room
/// Studio has no login gate, so guest usage is expected and the endpoints
/// handle that case with a stricter, separate rate limit rather than
/// rejecting the request.
class AIEndpointClient {
  static const String baseUrl = 'https://grazia-stones.vercel.app';

  /// Tests swap its httpClientAdapter so no real render (or quota) is spent.
  @visibleForTesting
  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 90),
      headers: {'Origin': baseUrl},
    ),
  );

  static Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final accessToken =
        SupabaseService.instance.clientOrNull?.auth.currentSession?.accessToken;
    final response = await dio.post(
      path,
      data: body,
      options: accessToken != null
          ? Options(headers: {'Authorization': 'Bearer $accessToken'})
          : null,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
    return response.data as Map<String, dynamic>;
  }
}
