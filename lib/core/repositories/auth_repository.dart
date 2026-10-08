import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import '../config/env_config.dart';
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

  /// Marker error text for "account created, email confirmation pending".
  static const emailConfirmationRequired = 'email_confirmation_required';

  /// Sign up with email and password.
  /// Returns null when the account was created but Supabase requires the
  /// email to be confirmed first (no session yet).
  Future<User?> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    final res = await _sb.signUp(email, password, fullName: name);
    if (res.user == null) throw Exception('Registration failed');
    if (res.session == null) return null;
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

  /// Sign in with Google.
  /// Mobile: native Google SDK -> ID token -> Supabase (returns the user).
  /// Web: Supabase OAuth redirect; the page navigates away and the session
  /// is restored on return, so this returns null.
  Future<User?> signInWithGoogle() async {
    if (kIsWeb) {
      final launched = await _sb.signInWithOAuth(OAuthProvider.google);
      if (!launched) throw Exception('Google sign-in failed');
      return null;
    }

    final env = EnvConfig();
    final google = GoogleSignIn(
      clientId: env.googleIosClientId.isEmpty ? null : env.googleIosClientId,
      serverClientId:
          env.googleWebClientId.isEmpty ? null : env.googleWebClientId,
      scopes: const ['email', 'profile'],
    );
    final account = await google.signIn();
    if (account == null) throw Exception('Google sign-in was cancelled');

    final tokens = await account.authentication;
    final idToken = tokens.idToken;
    if (idToken == null) throw Exception('Google did not return an ID token');

    final res = await _sb.signInWithIdToken(
      OAuthProvider.google,
      idToken,
      accessToken: tokens.accessToken,
    );
    if (res.user == null) throw Exception('Google sign-in failed');
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
      'full_name': ?name,
      'email': ?email,
      'phone': ?phone,
      'avatar_url': ?avatarUrl,
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
