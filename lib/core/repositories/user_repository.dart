import '../models/user.dart';
import '../services/supabase_service.dart';

/// User repository backed by Supabase.
class UserRepository {
  final SupabaseService _sb = SupabaseService.instance;

  String get _userId {
    final id = _sb.currentUser?.id;
    if (id == null) throw Exception('Not logged in');
    return id;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PROFILE
  // ═══════════════════════════════════════════════════════════════════════

  Future<User> getProfile() async {
    final data = await _sb.client
        .from('users')
        .select()
        .eq('id', _userId)
        .single();
    return User.fromJson(data);
  }

  Future<User> updateProfile({
    String? name,
    String? phone,
    String? email,
    String? companyName,
    String? avatarUrl,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (name != null) updates['full_name'] = name;
    if (phone != null) updates['phone'] = phone;
    if (email != null) updates['email'] = email;
    if (companyName != null) updates['company_name'] = companyName;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

    final data = await _sb.client
        .from('users')
        .update(updates)
        .eq('id', _userId)
        .select()
        .single();
    return User.fromJson(data);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ADDRESSES
  // ═══════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getAddresses() async {
    final data = await _sb.client
        .from('user_addresses')
        .select()
        .eq('user_id', _userId)
        .order('is_default', ascending: false);
    return data;
  }

  Future<Map<String, dynamic>> addAddress({
    required String name,
    required String phone,
    required String addressLine1,
    String? addressLine2,
    required String city,
    required String state,
    required String pincode,
    bool isDefault = false,
  }) async {
    final data = await _sb.client.from('user_addresses').insert({
      'user_id': _userId,
      'name': name,
      'phone': phone,
      'address_line1': addressLine1,
      'address_line2': addressLine2,
      'city': city,
      'state': state,
      'pincode': pincode,
      'is_default': isDefault,
    }).select().single();
    return data;
  }

  Future<void> deleteAddress(String addressId) async {
    await _sb.client
        .from('user_addresses')
        .delete()
        .eq('id', addressId)
        .eq('user_id', _userId);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PREFERENCES
  // ═══════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getPreferences() async {
    final data = await _sb.client
        .from('users')
        .select('preferences')
        .eq('id', _userId)
        .single();
    return data['preferences'] ?? {};
  }

  Future<void> updatePreferences(Map<String, dynamic> prefs) async {
    await _sb.client.from('users').update({
      'preferences': prefs,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', _userId);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getNotifications({
    int page = 1,
    int limit = 20,
  }) async {
    final from = (page - 1) * limit;
    final data = await _sb.client
        .from('notifications')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false)
        .range(from, from + limit - 1);
    return data;
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _sb.client.from('notifications').update({
      'read': true,
    }).eq('id', notificationId);
  }
}
