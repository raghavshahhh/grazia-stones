import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
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
      // user_metadata is writable by the user: never a source of roles. _saveAndSetState reads profiles.role.
      role: 'customer',
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
  /// Null when the browser flow was started: the session arrives later through the auth-callback deep link.
  Future<User?> signInWithGoogle() async {
    final env = EnvConfig();
    // Native Google Sign-In on Android needs the Play app-signing SHA-1 registered on an Android OAuth client;
    // without it every Play install failed (DEVELOPER_ERROR). The browser flow through Supabase needs no SHA-1,
    // so Android (and iOS without its own client ID) always use it.
    // The browser flow shows Google's consent as "Sign in to <project>.supabase.co"; the native sheet shows the
    // consent-screen app name ("Grazia Stones"). Native needs the iOS client ID, or on Android the Android OAuth
    // clients (Play + upload SHA-1) in the same Google Cloud project: GOOGLE_ANDROID_NATIVE=true once they exist.
    final native = !kIsWeb &&
        ((defaultTargetPlatform == TargetPlatform.iOS && env.googleIosClientId.isNotEmpty) ||
            (defaultTargetPlatform == TargetPlatform.android && env.googleAndroidNative && env.googleWebClientId.isNotEmpty));
    Future<User?> browser() async {
      final launched = await _sb.signInWithOAuth(OAuthProvider.google,
          redirectTo: kIsWeb ? null : SupabaseService.authCallbackUrl);
      if (!launched) throw Exception('Google sign-in failed');
      return null;
    }
    if (!native) return browser();

    final google = GoogleSignIn(
      clientId: env.googleIosClientId.isEmpty ? null : env.googleIosClientId,
      serverClientId:
          env.googleWebClientId.isEmpty ? null : env.googleWebClientId,
      scopes: const ['email', 'profile'],
    );
    final GoogleSignInAccount? account;
    try {
      account = await google.signIn();
    } on PlatformException catch (e) {
      // A misconfigured client (e.g. DEVELOPER_ERROR: SHA-1 not registered) must not lock users out.
      if (e.code == GoogleSignIn.kSignInCanceledError) throw Exception('Google sign-in was cancelled');
      return browser();
    }
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

  /// Native Sign in with Apple (iPhone). The hashed nonce goes to Apple, the raw one to Supabase, which checks
  /// they match so a stolen ID token cannot be replayed.
  Future<User?> signInWithApple() async {
    final rawNonce = _sb.auth.generateRawNonce();
    final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
        nonce: sha256.convert(utf8.encode(rawNonce)).toString(),
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;   // the user closed the sheet: no error
      rethrow;
    }
    final idToken = credential.identityToken;
    if (idToken == null) throw Exception('Apple did not return an ID token');
    final res = await _sb.signInWithIdToken(OAuthProvider.apple, idToken, nonce: rawNonce);
    if (res.user == null) throw Exception('Apple sign-in failed');
    // Apple sends the name only on the very first sign-in; keep it.
    final name = [credential.givenName, credential.familyName].whereType<String>().join(' ').trim();
    if (name.isNotEmpty) {
      try {
        await _sb.auth.updateUser(UserAttributes(data: {'full_name': name}));
      } catch (_) {}
    }
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
    final user = User.fromMap(data);
    // Google puts the name and photo in user_metadata ('picture' on some flows); the signup trigger copied only
    // the name, so Google users showed the default avatar. Fill the gaps and save them once.
    final meta = _sb.currentUser?.userMetadata ?? const <String, dynamic>{};
    final name = user.name.isNotEmpty ? user.name : (meta['full_name'] ?? meta['name'] ?? '').toString();
    final avatar = (user.avatarUrl?.isNotEmpty ?? false) ? user.avatarUrl : (meta['avatar_url'] ?? meta['picture'])?.toString();
    if (name == user.name && avatar == user.avatarUrl) return user;
    try {
      await updateProfile(name: name.isEmpty ? null : name, avatarUrl: avatar);
    } catch (_) {} // shown either way; saved on the next sign-in
    return User(id: user.id, name: name, email: user.email, phone: user.phone, avatarUrl: avatar, role: user.role,
        createdAt: user.createdAt);
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
