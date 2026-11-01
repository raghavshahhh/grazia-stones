import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../../../core/services/supabase_service.dart';
import '../../../core/models/user.dart';
import '../../../core/repositories/auth_repository.dart';
import '../../../core/services/storage_service.dart';

// ─── State ───
class AuthRiverpodState {
  final String? userId;
  final String? userName;
  final String? userPhone;
  final String? userEmail;
  final String? avatarUrl;
  final String userRole;
  final bool isLoggedIn;
  final bool onboardingComplete;
  final bool isLoading;
  final String? error;
  final String? verificationId; // For OTP flow
  /// Set when a password-reset link opened the app; the user must choose a new password.
  final bool isPasswordRecovery;
  /// False until the saved session has been checked at launch; Splash waits for it, so a signed-in user is not
  /// bounced to Login while the session restores.
  final bool sessionChecked;

  AuthRiverpodState({
    this.userId,
    this.userName,
    this.userPhone,
    this.userEmail,
    this.avatarUrl,
    this.userRole = 'customer',
    this.isLoggedIn = false,
    this.onboardingComplete = false,
    this.isLoading = false,
    this.error,
    this.verificationId,
    this.isPasswordRecovery = false,
    this.sessionChecked = false,
  });

  bool get isAdmin => userRole.toLowerCase() == 'admin';
  bool get isDealer => userRole.toLowerCase() == 'dealer';

  User? get toUser => userId == null
      ? null
      : User(
          id: userId!,
          name: userName ?? '',
          email: userEmail ?? '',
          phone: userPhone,
          avatarUrl: avatarUrl,
          role: userRole,
          createdAt: DateTime.now(),
        );

  AuthRiverpodState copyWith({
    String? userId,
    String? userName,
    String? userPhone,
    String? userEmail,
    String? avatarUrl,
    String? userRole,
    bool? isLoggedIn,
    bool? onboardingComplete,
    bool? isLoading,
    String? error,
    String? verificationId,
    bool? isPasswordRecovery,
    bool? sessionChecked,
    bool clearError = false,
    bool clearVerificationId = false,
  }) {
    return AuthRiverpodState(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userPhone: userPhone ?? this.userPhone,
      userEmail: userEmail ?? this.userEmail,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      userRole: userRole ?? this.userRole,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      verificationId: clearVerificationId ? null : (verificationId ?? this.verificationId),
      isPasswordRecovery: isPasswordRecovery ?? this.isPasswordRecovery,
      sessionChecked: sessionChecked ?? this.sessionChecked,
    );
  }
}

// ─── Notifier ───
class AuthRiverpodNotifier extends StateNotifier<AuthRiverpodState> {
  final AuthRepository _repo;
  final StorageService _storage = StorageService.instance;

  StreamSubscription<sb.AuthState>? _authSub;

  AuthRiverpodNotifier(this._repo) : super(AuthRiverpodState()) {
    _start();
  }

  /// The first frame renders before Supabase finishes initialising (main.dart), so wait for the client before
  /// restoring the session and attaching the listener; reading it earlier skipped both.
  Future<void> _start() async {
    if (SupabaseService.instance.authOrNull == null) {
      await SupabaseService.instance.ready.timeout(const Duration(seconds: 10), onTimeout: () {});
    }
    if (!mounted) return;
    await _loadPersistedState();
    if (mounted) state = state.copyWith(sessionChecked: true);
    _listenForDeepLinkSignIn();
  }

  /// Email-confirmation / magic links reopen the app with a session that
  /// supabase_flutter restores on its own. Mirror it into our auth state so
  /// the user is signed in without having to type credentials again.
  void _listenForDeepLinkSignIn() {
    final auth = SupabaseService.instance.authOrNull;
    if (auth == null) return;
    _authSub = auth.onAuthStateChange.listen((data) async {
      if (data.event == sb.AuthChangeEvent.passwordRecovery) {
        state = state.copyWith(isPasswordRecovery: true);
        return;
      }
      // tokenRefreshed: a session that was expired at startup (offline) came back once the network did.
      if (data.event != sb.AuthChangeEvent.signedIn && data.event != sb.AuthChangeEvent.tokenRefreshed) return;
      if (data.session == null || state.isLoggedIn) return;
      try {
        await _saveAndSetState(await _repo.getProfile());
      } catch (e) {
        debugPrint('❌ Deep-link sign-in sync failed: $e');
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _loadPersistedState() async {
    try {
      final onboardingComplete = _storage.getOnboardingCompleted();

      // Logged in only with a valid Supabase session. A cached user without one made every write go out as a
      // guest (quotes/samples missing from the user's history), so drop the cache instead.
      final sessionUserId = await _validSessionUserId();
      if (sessionUserId == null) {
        await _storage.clearUser();
        state = state.copyWith(onboardingComplete: onboardingComplete);
        return;
      }
      try {
        final user = await _repo.getProfile();
        state = state.copyWith(
          userId: user.id,
          userName: user.name,
          userPhone: user.phone,
          userEmail: user.email,
          avatarUrl: user.avatarUrl,
          userRole: user.role,
          isLoggedIn: true,
          onboardingComplete: onboardingComplete,
        );
        debugPrint('✅ Auth state restored from Supabase session (Role: ${user.role})');
      } catch (e) {
        // Session is valid but the profile read failed (e.g. flaky network): use the cache for display only if it
        // belongs to the same account. Admin still needs a live profile read.
        final userData = _storage.getUser();
        if (userData == null || userData['id'] != sessionUserId) rethrow;
        final cachedRole = userData['role'] as String? ?? 'customer';
        state = state.copyWith(
          userId: sessionUserId,
          userName: userData['name'] as String?,
          userPhone: userData['phone'] as String?,
          userEmail: userData['email'] as String?,
          avatarUrl: userData['avatar_url'] as String?,
          userRole: cachedRole == 'admin' ? 'customer' : cachedRole,
          isLoggedIn: true,
          onboardingComplete: onboardingComplete,
        );
      }
    } catch (e) {
      debugPrint('❌ Error loading persisted auth state: $e');
      final onboardingComplete = _storage.getOnboardingCompleted();
      state = state.copyWith(onboardingComplete: onboardingComplete);
    }
  }


  /// Id of the signed-in user if Supabase holds a session that is valid now (refreshed if expired), else null.
  Future<String?> _validSessionUserId() async {
    final auth = SupabaseService.instance.authOrNull;
    final session = auth?.currentSession;
    if (auth == null || session == null) return null;
    if (session.isExpired) {
      try {
        final refreshed = await auth.refreshSession();
        if (refreshed.session == null || refreshed.session!.isExpired) return null;
      } catch (e) {
        debugPrint('❌ Session refresh failed: $e');
        return null;
      }
    }
    return auth.currentUser?.id;
  }

  /// Send OTP to phone number
  Future<bool> sendOTP(String phoneNumber) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _repo.sendOtp(phoneNumber);
      state = state.copyWith(
        isLoading: false,
        userPhone: phoneNumber,
      );
      debugPrint('✅ OTP sent'); // no phone number in device logs
      return true;
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
      debugPrint('❌ OTP send error: $e');
      return false;
    }
  }

  /// Verify OTP and complete login
  Future<bool> verifyOTP(String otp, {String? name, String? email, bool isRegistration = false}) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final user = await _repo.verifyOtp(state.userPhone ?? '', otp);

      await _saveAndSetState(user);
      debugPrint('✅ OTP verified, user authenticated');
      return true;
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
      debugPrint('❌ OTP verification error: $e');
      return false;
    }
  }

  /// Login with email/password
  Future<void> loginWithApi(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _repo.login(email.trim(), password);
      await _saveAndSetState(user);
    } catch (e) {
      // No local-account fallback: it signed in a fake user (also in profile builds) whenever Supabase failed.
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Register with email/password
  Future<void> register(
    String name,
    String email,
    String password, {
    String? phone,
    String? role,
    String? company,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _repo.register(
        name: name.trim(),
        email: email.trim(),
        password: password,
        phone: phone,
      );
      if (user == null) {
        // Supabase created the account but wants the email confirmed before
        // it issues a session. Never fake a login without a real session —
        // orders/quotes need a real user behind RLS.
        state = state.copyWith(
          isLoading: false,
          error: AuthRepository.emailConfirmationRequired,
        );
        return;
      }
      await _saveAndSetState(user);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      debugPrint('❌ Register error: $e');
    }
  }

  /// Sign in with Google
  Future<void> signInWithGoogle() => _socialSignIn(_repo.signInWithGoogle);

  /// Sign in with Apple (iPhone)
  Future<void> signInWithApple() => _socialSignIn(_repo.signInWithApple);

  /// A null user means a browser flow was started; [_listenForDeepLinkSignIn] finishes it.
  Future<void> _socialSignIn(Future<User?> Function() signIn) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await signIn();
      if (user == null) {
        state = state.copyWith(isLoading: false);
        return;
      }
      await _saveAndSetState(user);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Send password reset email
  Future<void> sendPasswordReset(String email) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.resetPassword(email);
      state = state.copyWith(isLoading: false);
      debugPrint('✅ Password reset email sent'); // no email in device logs
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      debugPrint('❌ Password reset error: $e');
      rethrow;
    }
  }

  /// Update password (when logged in, or in the recovery session a reset link opens)
  Future<void> updatePassword(String newPassword) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.updatePassword(newPassword);
      state = state.copyWith(isLoading: false, isPasswordRecovery: false);
      // A recovery link signs in without a signedIn event; mirror that session now that the password is set.
      if (!state.isLoggedIn && _repo.isLoggedIn()) {
        try {
          await _saveAndSetState(await _repo.getProfile());
        } catch (e) {
          debugPrint('❌ Post-reset sign-in sync failed: $e');
        }
      }
      debugPrint('✅ Password updated');
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      debugPrint('❌ Password update error: $e');
      rethrow;
    }
  }

  /// Delete account
  Future<void> deleteAccount() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.deleteAccount();
      await _storage.clearAllExceptTheme();
      state = AuthRiverpodState(onboardingComplete: state.onboardingComplete);
      debugPrint('✅ Account deleted');
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      debugPrint('❌ Account deletion error: $e');
      rethrow;
    }
  }

  /// Login (legacy method for backward compatibility)
  void login(String userId, String name, String phone, {String? email}) async {
    state = state.copyWith(
      userId: userId,
      userName: name,
      userPhone: phone,
      userEmail: email,
      isLoggedIn: true,
      error: null,
    );

    await _storage.saveUser({
      'id': userId,
      'name': name,
      'phone': phone,
      'email': email,
    });
  }

  /// Logout
  Future<void> logout() async {
    try {
      await _repo.logout();
    } catch (e) {
      // Offline: the server call failed before the local session was removed. Drop it locally anyway, or the
      // user stays signed in while the UI shows the login screen.
      debugPrint('❌ Logout error: $e');
      try {
        await SupabaseService.instance.authOrNull?.signOut(scope: sb.SignOutScope.local);
      } catch (_) {}
    } finally {
      await _storage.clearAllExceptTheme();
      state = AuthRiverpodState(onboardingComplete: state.onboardingComplete);
    }
  }

  /// Complete onboarding
  Future<void> completeOnboarding() async {
    await _storage.saveOnboardingCompleted(true);
    state = state.copyWith(onboardingComplete: true);
  }

  /// Update profile
  Future<void> updateProfile({String? name, String? phone, String? email, String? avatarUrl}) async {
    // Guests have no profile row; caching an id-less user made the next launch act as a ghost signed-in user.
    if (!state.isLoggedIn || state.userId == null) {
      throw StateError('Sign in to save your profile.');
    }
    try {
      state = state.copyWith(isLoading: true);

      await _repo.updateProfile(name: name, phone: phone, email: email, avatarUrl: avatarUrl);

      final userData = {
        'id': state.userId,
        'name': name ?? state.userName,
        'phone': phone ?? state.userPhone,
        'email': email ?? state.userEmail,
        'avatar_url': avatarUrl ?? state.avatarUrl,
      };
      await _storage.saveUser(userData);

      state = state.copyWith(
        userName: name,
        userPhone: phone,
        userEmail: email,
        avatarUrl: avatarUrl,
        isLoading: false,
      );
      debugPrint('✅ Profile updated');
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      debugPrint('❌ Profile update error: $e');
      rethrow;
    }
  }

  Future<void> loadProfile() async {
    try {
      final user = await _repo.getProfile();
      state = state.copyWith(
        userId: user.id,
        userName: user.name,
        userPhone: user.phone,
        userEmail: user.email,
        avatarUrl: user.avatarUrl,
      );
    } catch (_) {}
  }

  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  void setError(String error) {
    state = state.copyWith(error: error, isLoading: false);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  // ─── Helpers ───
  Future<void> _saveAndSetState(User user) async {
    // Role is the backend profiles table's business — never trust client
    // metadata or email heuristics for authorization. Fetch the real
    // profile; fall back to the session claim only if the fetch fails.
    // Only profiles.role (server, RLS-protected) grants a role; if it cannot be read, the user is a customer.
    var role = 'customer';
    try {
      final profile = await _repo.getProfile();
      if (profile.role.isNotEmpty) role = profile.role;
    } catch (_) {
      // Profile fetch failed (e.g. trigger lag): no elevated role without proof.
    }

    await _storage.saveUser({
      'id': user.id,
      'name': user.name,
      'phone': user.phone,
      'email': user.email,
      'avatar_url': user.avatarUrl,
      'role': role,
    });

    state = state.copyWith(
      userId: user.id,
      userName: user.name,
      userPhone: user.phone,
      userEmail: user.email,
      avatarUrl: user.avatarUrl,
      userRole: role,
      isLoggedIn: true,
      isLoading: false,
      clearError: true,
      clearVerificationId: true,
    );
  }
}

