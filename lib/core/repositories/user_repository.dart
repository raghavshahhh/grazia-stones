import '../models/user.dart';
import '../repositories/base_repository.dart';
import '../network/endpoints/user_api.dart';

class UserRepository extends BaseRepository {
  UserRepository(super.api);
  
  final UserApi _userApi = UserApi();

  // ═══════════════════════════════════════════════════════════════════════
  // PROFILE
  // ═══════════════════════════════════════════════════════════════════════

  Future<User> getProfile() async {
    return safeCall(() async {
      return await _userApi.getProfile();
    });
  }

  Future<void> updateProfile({
    String? name,
    String? email,
    String? phone,
    String? companyName,
    bool? isArchitect,
  }) async {
    await safeCall(() async {
      await _userApi.updateProfile(
        name: name,
        email: email,
        phone: phone,
        companyName: companyName,
        isArchitect: isArchitect,
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
      final fullAddr = addressLine2 != null && addressLine2.isNotEmpty
          ? '$addressLine1, $addressLine2'
          : addressLine1;
      return await _userApi.addAddress(
        label: name,
        address: fullAddr,
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
      final data = <String, dynamic>{
        if (name != null) 'label': name,
        if (addressLine1 != null)
          'address': addressLine2 != null && addressLine2.isNotEmpty
              ? '$addressLine1, $addressLine2'
              : addressLine1,
        if (city != null) 'city': city,
        if (state != null) 'state': state,
        if (pincode != null) 'pincode': pincode,
        if (phone != null) 'phone': phone,
        if (isDefault != null) 'is_default': isDefault,
      };
      await _userApi.updateAddress(addressId, data);
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
      await _userApi.updatePreferences({
        if (theme != null) 'theme': theme,
        if (language != null) 'language': language,
        if (notifications != null) 'notifications': notifications,
        if (emailNotifications != null) 'email_notifications': emailNotifications,
        if (smsNotifications != null) 'sms_notifications': smsNotifications,
      });
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
      await _userApi.markNotificationRead(notificationId);
    });
  }

  Future<void> markAllNotificationsAsRead() async {
    await safeCall(() async {
      await _userApi.markAllNotificationsRead();
    });
  }

  // ═══════════════════════════════════════════════════════════════════════
  // FCM TOKEN
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> updateFcmToken(String token) async {
    await safeCall(() async {
      await _userApi.registerFCMToken(token);
    });
  }
}
