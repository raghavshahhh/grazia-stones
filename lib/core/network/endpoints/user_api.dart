import '../../models/user.dart';
import '../api_service.dart';

/// User-related API endpoints
class UserApi {
  final ApiService _api = ApiService.instance;

  // ═══════════════════════════════════════════════════════════════════════
  // PROFILE
  // ═══════════════════════════════════════════════════════════════════════

  /// Get user profile
  Future<User> getProfile() async {
    final response = await _api.get<Map<String, dynamic>>('/user/profile');
    
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.errorMessage);
    }
    
    return User.fromJson(response.data!);
  }

  /// Update user profile
  Future<User> updateProfile({
    String? name,
    String? email,
    String? phone,
    String? companyName,
    bool? isArchitect,
  }) async {
    final response = await _api.put<Map<String, dynamic>>(
      '/user/profile',
      data: {
        if (name != null) 'name': name,
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
        if (companyName != null) 'company_name': companyName,
        if (isArchitect != null) 'is_architect': isArchitect,
      },
    );
    
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.errorMessage);
    }
    
    return User.fromJson(response.data!);
  }

  /// Upload profile picture
  Future<String> uploadProfilePicture(String filePath) async {
    final response = await _api.upload<Map<String, dynamic>>(
      '/user/profile/picture',
      filePath,
      fieldName: 'avatar',
    );
    
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.errorMessage);
    }
    
    return response.data!['avatar_url'] as String;
  }

  /// Delete account
  Future<bool> deleteAccount() async {
    final response = await _api.delete('/user/account');
    return response.isSuccess;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ADDRESSES
  // ═══════════════════════════════════════════════════════════════════════

  /// Get user addresses
  Future<List<Map<String, dynamic>>> getAddresses() async {
    final response = await _api.get<Map<String, dynamic>>('/user/addresses');
    
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.errorMessage);
    }
    
    final data = response.data!['data'] as List;
    return data.cast<Map<String, dynamic>>();
  }

  /// Add new address
  Future<Map<String, dynamic>> addAddress({
    required String label,
    required String address,
    required String city,
    required String state,
    required String pincode,
    required String phone,
    bool isDefault = false,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/user/addresses',
      data: {
        'label': label,
        'address': address,
        'city': city,
        'state': state,
        'pincode': pincode,
        'phone': phone,
        'is_default': isDefault,
      },
    );
    
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.errorMessage);
    }
    
    return response.data!;
  }

  /// Update address
  Future<Map<String, dynamic>> updateAddress(
    String addressId,
    Map<String, dynamic> data,
  ) async {
    final response = await _api.put<Map<String, dynamic>>(
      '/user/addresses/$addressId',
      data: data,
    );
    
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.errorMessage);
    }
    
    return response.data!;
  }

  /// Delete address
  Future<bool> deleteAddress(String addressId) async {
    final response = await _api.delete('/user/addresses/$addressId');
    return response.isSuccess;
  }

  /// Set default address
  Future<bool> setDefaultAddress(String addressId) async {
    final response = await _api.post(
      '/user/addresses/$addressId/set-default',
    );
    return response.isSuccess;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PREFERENCES
  // ═══════════════════════════════════════════════════════════════════════

  /// Get user preferences
  Future<Map<String, dynamic>> getPreferences() async {
    final response = await _api.get<Map<String, dynamic>>('/user/preferences');
    
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.errorMessage);
    }
    
    return response.data!;
  }

  /// Update preferences
  Future<bool> updatePreferences(Map<String, dynamic> preferences) async {
    final response = await _api.put(
      '/user/preferences',
      data: preferences,
    );
    return response.isSuccess;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════════════════

  /// Get notifications
  Future<List<Map<String, dynamic>>> getNotifications({
    int page = 1,
    int limit = 20,
    bool? unreadOnly,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (unreadOnly != null) 'unread_only': unreadOnly,
    };

    final response = await _api.get<Map<String, dynamic>>(
      '/user/notifications',
      queryParameters: queryParams,
    );
    
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.errorMessage);
    }
    
    final data = response.data!['data'] as List;
    return data.cast<Map<String, dynamic>>();
  }

  /// Mark notification as read
  Future<bool> markNotificationRead(String notificationId) async {
    final response = await _api.post(
      '/user/notifications/$notificationId/read',
    );
    return response.isSuccess;
  }

  /// Mark all notifications as read
  Future<bool> markAllNotificationsRead() async {
    final response = await _api.post('/user/notifications/read-all');
    return response.isSuccess;
  }

  /// Delete notification
  Future<bool> deleteNotification(String notificationId) async {
    final response = await _api.delete('/user/notifications/$notificationId');
    return response.isSuccess;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // FCM TOKEN (Push Notifications)
  // ═══════════════════════════════════════════════════════════════════════

  /// Register FCM token
  Future<bool> registerFCMToken(String token) async {
    final response = await _api.post(
      '/user/fcm-token',
      data: {'token': token},
    );
    return response.isSuccess;
  }

  /// Remove FCM token
  Future<bool> removeFCMToken(String token) async {
    final response = await _api.delete(
      '/user/fcm-token',
      data: {'token': token},
    );
    return response.isSuccess;
  }
}
