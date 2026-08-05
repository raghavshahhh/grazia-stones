import '../repositories/base_repository.dart';
import '../network/endpoints/user_api.dart';

class UserRepository extends BaseRepository {
  UserRepository(super.api);
  
  final UserApi _userApi = UserApi();

  // ═══════════════════════════════════════════════════════════════════════
  // PROFILE
  // ═══════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getProfile() async {
    return safeCall(() async {
      return await _userApi.getProfile();
    });
  }

  Future<void> updateProfile({
    String? name,
    String? email,
    String? phone,
    String? address,
  }) async {
    await safeCall(() async {
      await _userApi.updateProfile(
        name: name,
        email: email,
        phone: phone,
        address: address,
      );
    });
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ADDRESSES
  // ═══════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getAddresses() async {
    return safeCall(() async {
      return await _userApi.getAddresses();
    });
  }

  Future<Map<String, dynamic>> addAddress({
    required String name,
    required String addressLine1,
    String? addressLine2,
    required String city,
    required String state,
    required String pincode,
    required String phone,
    bool isDefault = false,
  }) async {
    return safeCall(() async {
      return await _userApi.addAddress(
        name: name,
        addressLine1: addressLine1,
        addressLine2: addressLine2,
        city: city,
        state: state,
        pincode: pincode,
        phone: phone,
        isDefault: isDefault,
      );
    });
  }

  Future<void> updateAddress({
    required String addressId,
    String? name,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? state,
    String? pincode,
    String? phone,
    bool? isDefault,
  }) async {
    await safeCall(() async {
      await _userApi.updateAddress(
        addressId: addressId,
        name: name,
        addressLine1: addressLine1,
        addressLine2: addressLine2,
        city: city,
        state: state,
        pincode: pincode,
        phone: phone,
        isDefault: isDefault,
      );
    });
  }

  Future<void> deleteAddress(String addressId) async {
    await safeCall(() async {
      await _userApi.deleteAddress(addressId);
    });
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PREFERENCES
  // ═══════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getPreferences() async {
    return safeCall(() async {
      return await _userApi.getPreferences();
    });
  }

  Future<void> updatePreferences({
    String? theme,
    String? language,
    bool? notifications,
    bool? emailNotifications,
    bool? smsNotifications,
  }) async {
    await safeCall(() async {
      await _userApi.updatePreferences(
        theme: theme,
        language: language,
        notifications: notifications,
        emailNotifications: emailNotifications,
        smsNotifications: smsNotifications,
      );
    });
  }

  // ═══════════════════════════════════════════════════════════════════════
  // NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getNotifications({
    int page = 1,
    int limit = 20,
  }) async {
    return safeCall(() async {
      return await _userApi.getNotifications(page: page, limit: limit);
    });
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    await safeCall(() async {
      await _userApi.markNotificationAsRead(notificationId);
    });
  }

  Future<void> markAllNotificationsAsRead() async {
    await safeCall(() async {
      await _userApi.markAllNotificationsAsRead();
    });
  }

  // ═══════════════════════════════════════════════════════════════════════
  // FCM TOKEN
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> updateFcmToken(String token) async {
    await safeCall(() async {
      await _userApi.updateFcmToken(token);
    });
  }
}
