import 'package:dio/dio.dart';

/// Shared HTTP client for the Vercel-hosted AI proxy endpoints
/// (api/wall-detect.js, api/generate-visualization.js).
///
/// Those endpoints enforce an Origin allowlist meant for browser callers.
/// Native mobile clients don't send an Origin header by default, so we set
/// it explicitly to our own production domain, which is already on the
/// endpoint's allowlist.
class AIEndpointClient {
  static const String baseUrl = 'https://grazia-stones.vercel.app';

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 90),
      headers: {'Origin': baseUrl},
    ),
  );

  static Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _dio.post(path, data: body);
    return response.data as Map<String, dynamic>;
  }
}
