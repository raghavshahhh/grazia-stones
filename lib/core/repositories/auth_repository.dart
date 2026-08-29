import '../models/user.dart';
import '../services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

/// Auth repository using Supabase Auth.
/// Supports: Phone OTP, Email/Password, Google Sign-In, Password Reset
class AuthRepository {
  final SupabaseService _sb = SupabaseService.instance;

  User? _userFromSession() {
    final u = _sb.currentUser;
    if (u == null) return null;
    return User(
      id: u.id,
      name: u.userMetadata?['full_name'] as String? ?? '',
      email: u.email ?? '',
      phone: u.phone ?? u.userMetadata?['phone'] as String?,
      avatarUrl: u.userMetadata?['avatar_url'] as String?,
      role: u.userMetadata?['role'] as String? ?? 'customer',
      createdAt: DateTime.tryParse(u.createdAt) ?? DateTime.now(),
    );
  }

  /// Send OTP to phone number
  Future<void> sendOtp(String phone) async {
    await _sb.sendOtp(phone);
  }

  /// Verify OTP — returns User on success
  Future<User> verifyOtp(String phone, String token) async {
    final res = await _sb.verifyOtp(phone, token);
    if (res.user == null) throw Exception('OTP verification failed');
    return _userFromSession()!;
  }

  /// Sign up with email and password
  Future<User> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    final res = await _sb.signUp(email, password, fullName: name);
    if (res.user == null) throw Exception('Registration failed');
    // Update phone in profile if provided
    if (phone != null) {
      await _sb.updateProfile({'phone': phone});
    }
    return _userFromSession()!;
  }

  /// Sign in with email and password
  Future<User> login(String email, String password) async {
    final res = await _sb.signIn(email, password);
    if (res.user == null) throw Exception('Login failed');
    return _userFromSession()!;
  }

  /// Sign in with Google
  Future<User> signInWithGoogle() async {
    final success = await _sb.signInWithOAuth(OAuthProvider.google);
    if (!success) throw Exception('Google sign-in failed');
    return _userFromSession()!;
  }

  /// Send password reset email
  Future<void> resetPassword(String email) async {
    await _sb.resetPassword(email);
  }

  /// Update password (when logged in)
  Future<void> updatePassword(String newPassword) async {
    await _sb.updatePassword(newPassword);
  }

  /// Get current user profile
  Future<User> getProfile() async {
    final data = await _sb.getProfile();
    if (data == null) throw Exception('Profile not found');
    return User.fromMap(data);
  }


  /// Update profile
  Future<void> updateProfile({String? name, String? email, String? phone, String? avatarUrl}) async {
    await _sb.updateProfile({
      if (name != null) 'full_name': name,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    });
  }

  /// Sign out
  Future<void> logout() async {
    await _sb.signOut();
  }

  /// Delete account
  Future<void> deleteAccount() async {
    await _sb.deleteAccount();
  }

  bool isLoggedIn() => _sb.isLoggedIn;
}
