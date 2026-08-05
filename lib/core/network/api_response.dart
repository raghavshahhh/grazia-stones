import 'package:dio/dio.dart';

/// Wrapper for API responses
class ApiResponse<T> {
  final T? data;
  final String? message;
  final int statusCode;
  final bool success;
  final Map<String, dynamic>? meta;

  ApiResponse({
    this.data,
    this.message,
    required this.statusCode,
    required this.success,
    this.meta,
  });

  /// Create from Dio Response
  factory ApiResponse.fromResponse(Response response) {
    final responseData = response.data;
    
    // Handle different response structures
    if (responseData is Map<String, dynamic>) {
      return ApiResponse<T>(
        data: responseData['data'] as T?,
        message: responseData['message'] as String?,
        statusCode: response.statusCode ?? 200,
        success: responseData['success'] as bool? ?? true,
        meta: responseData['meta'] as Map<String, dynamic>?,
      );
    } else {
      // If response is not a map, treat entire response as data
      return ApiResponse<T>(
        data: responseData as T?,
        statusCode: response.statusCode ?? 200,
        success: true,
      );
    }
  }

  /// Success response
  factory ApiResponse.success({
    T? data,
    String? message,
    int statusCode = 200,
    Map<String, dynamic>? meta,
  }) {
    return ApiResponse<T>(
      data: data,
      message: message,
      statusCode: statusCode,
      success: true,
      meta: meta,
    );
  }

  /// Error response
  factory ApiResponse.error({
    String? message,
    int statusCode = 500,
    Map<String, dynamic>? meta,
  }) {
    return ApiResponse<T>(
      message: message,
      statusCode: statusCode,
      success: false,
      meta: meta,
    );
  }

  /// Check if response is successful
  bool get isSuccess => success && statusCode >= 200 && statusCode < 300;

  /// Get error message
  String get errorMessage => message ?? 'An error occurred';

  @override
  String toString() {
    return 'ApiResponse(success: $success, statusCode: $statusCode, message: $message)';
  }
}

/// Paginated response wrapper
class PaginatedResponse<T> extends ApiResponse<List<T>> {
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int itemsPerPage;
  final bool hasNextPage;
  final bool hasPreviousPage;

  PaginatedResponse({
    required List<T> data,
    String? message,
    required int statusCode,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.itemsPerPage,
    required this.hasNextPage,
    required this.hasPreviousPage,
  }) : super(
          data: data,
          message: message,
          statusCode: statusCode,
          success: true,
        );

  /// Create from API response
  factory PaginatedResponse.fromResponse(
    Response response,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final responseData = response.data as Map<String, dynamic>;
    final itemsData = responseData['data'] as List;
    final pagination = responseData['pagination'] as Map<String, dynamic>?;

    final items = itemsData
        .map((item) => fromJson(item as Map<String, dynamic>))
        .toList();

    return PaginatedResponse<T>(
      data: items,
      message: responseData['message'] as String?,
      statusCode: response.statusCode ?? 200,
      currentPage: pagination?['current_page'] as int? ?? 1,
      totalPages: pagination?['total_pages'] as int? ?? 1,
      totalItems: pagination?['total_items'] as int? ?? items.length,
      itemsPerPage: pagination?['items_per_page'] as int? ?? items.length,
      hasNextPage: pagination?['has_next_page'] as bool? ?? false,
      hasPreviousPage: pagination?['has_previous_page'] as bool? ?? false,
    );
  }

  @override
  String toString() {
    return 'PaginatedResponse(page: $currentPage/$totalPages, items: ${data?.length}/$totalItems)';
  }
}
