import 'dart:typed_data';
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
        .from('profiles')
        .select()
        .eq('id', _userId)
        .single();
    return User.fromMap(data);
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
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

    final data = await _sb.client
        .from('profiles')
        .update(updates)
        .eq('id', _userId)
        .select()
        .single();
    return User.fromMap(data);
  }

  Future<String> uploadAvatar(Uint8List bytes, String fileExtension) async {
    final fileName = '$_userId/avatar_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
    final path = await _sb.client.storage
        .from('avatars')
        .uploadBinary(fileName, bytes);
    final publicUrl = _sb.client.storage.from('avatars').getPublicUrl(fileName);
    await updateProfile(avatarUrl: publicUrl);
    return publicUrl;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ADDRESSES
  // ═══════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getAddresses() async {
    final data = await _sb.client
        .from('addresses')
        .select()
        .eq('user_id', _userId)
        .order('is_default', ascending: false)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<Map<String, dynamic>> addAddress({
    required String name,
    required String phone,
    required String addressLine1,
    String? addressLine2,
    required String city,
    required String state,
    required String pincode,
    String label = 'Home',
    bool isDefault = false,
  }) async {
    if (isDefault) {
      await _sb.client
          .from('addresses')
          .update({'is_default': false})
          .eq('user_id', _userId);
    }

    final data = await _sb.client.from('addresses').insert({
      'user_id': _userId,
      'label': label,
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

  Future<void> updateAddress({
    required String addressId,
    String? name,
    String? phone,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? state,
    String? pincode,
    String? label,
    bool? isDefault,
  }) async {
    if (isDefault == true) {
      await _sb.client
          .from('addresses')
          .update({'is_default': false})
          .eq('user_id', _userId);
    }

    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (phone != null) updates['phone'] = phone;
    if (addressLine1 != null) updates['address_line1'] = addressLine1;
    if (addressLine2 != null) updates['address_line2'] = addressLine2;
    if (city != null) updates['city'] = city;
    if (state != null) updates['state'] = state;
    if (pincode != null) updates['pincode'] = pincode;
    if (label != null) updates['label'] = label;
    if (isDefault != null) updates['is_default'] = isDefault;

    await _sb.client
        .from('addresses')
        .update(updates)
        .eq('id', addressId)
        .eq('user_id', _userId);
  }

  Future<void> setDefaultAddress(String addressId) async {
    await _sb.client
        .from('addresses')
        .update({'is_default': false})
        .eq('user_id', _userId);

    await _sb.client
        .from('addresses')
        .update({'is_default': true})
        .eq('id', addressId)
        .eq('user_id', _userId);
  }

  Future<void> deleteAddress(String addressId) async {
    await _sb.client
        .from('addresses')
        .delete()
        .eq('id', addressId)
        .eq('user_id', _userId);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SAVED DESIGNS (AI Room Visualizations)
  // ═══════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getSavedDesigns() async {
    final data = await _sb.client
        .from('saved_designs')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<Map<String, dynamic>> saveDesign({
    String? stoneId,
    required String stoneName,
    String? roomImageUrl,
    required String generatedImageUrl,
    String? color,
    String? finish,
    String? notes,
  }) async {
    final data = await _sb.client.from('saved_designs').insert({
      'user_id': _userId,
      'stone_id': stoneId,
      'stone_name': stoneName,
      'room_image_url': roomImageUrl,
      'generated_image_url': generatedImageUrl,
      'color': color,
      'finish': finish,
      'notes': notes,
    }).select().single();
    return data;
  }

  Future<void> deleteSavedDesign(String designId) async {
    await _sb.client
        .from('saved_designs')
        .delete()
        .eq('id', designId)
        .eq('user_id', _userId);
  }
}

