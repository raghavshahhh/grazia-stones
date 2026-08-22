import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
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
  final bool isLoggedIn;
  final bool onboardingComplete;
  final bool isLoading;
  final String? error;
  final String? verificationId; // For OTP flow

  AuthRiverpodState({
    this.userId,
    this.userName,
    this.userPhone,
    this.userEmail,
    this.avatarUrl,
    this.isLoggedIn = false,
    this.onboardingComplete = false,
    this.isLoading = false,
    this.error,
    this.verificationId,
  });

  User? get toUser => userId == null
      ? null
      : User(
          id: userId!,
          name: userName ?? '',
          email: userEmail ?? '',
          phone: userPhone,
          avatarUrl: avatarUrl,
          createdAt: DateTime.now(),
        );

  AuthRiverpodState copyWith({
    String? userId,
    String? userName,
    String? userPhone,
    String? userEmail,
    String? avatarUrl,
    bool? isLoggedIn,
    bool? onboardingComplete,
    bool? isLoading,
    String? error,
    String? verificationId,
    bool clearError = false,
    bool clearVerificationId = false,
  }) {
    return AuthRiverpodState(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userPhone: userPhone ?? this.userPhone,
      userEmail: userEmail ?? this.userEmail,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      verificationId: clearVerificationId ? null : (verificationId ?? this.verificationId),
    );
  }
}

// ─── Notifier ───
class AuthRiverpodNotifier extends StateNotifier<AuthRiverpodState> {
  final AuthRepository _repo;
  final StorageService _storage = StorageService.instance;

  AuthRiverpodNotifier(this._repo) : super(AuthRiverpodState()) {
    _loadPersistedState();
  }

  Future<void> _loadPersistedState() async {
    try {
      final onboardingComplete = _storage.getOnboardingCompleted();

      // Check if Supabase has an active session
      if (_repo.isLoggedIn()) {
        final user = await _repo.getProfile();
        state = state.copyWith(
          userId: user.id,
          userName: user.name,
          userPhone: user.phone,
          userEmail: user.email,
          avatarUrl: user.avatarUrl,
          isLoggedIn: true,
          onboardingComplete: onboardingComplete,
        );
        debugPrint('✅ Auth state restored from Supabase session');
      } else {
        // No session — check local cache
        final userData = _storage.getUser();
        if (userData != null) {
          state = state.copyWith(
            userId: userData['id'] as String?,
            userName: userData['name'] as String?,
            userPhone: userData['phone'] as String?,
            userEmail: userData['email'] as String?,
            avatarUrl: userData['avatar_url'] as String?,
            isLoggedIn: true,
            onboardingComplete: onboardingComplete,
          );
        } else {
          state = state.copyWith(onboardingComplete: onboardingComplete);
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading persisted auth state: $e');
      final onboardingComplete = _storage.getOnboardingCompleted();
      state = state.copyWith(onboardingComplete: onboardingComplete);
    }
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
      debugPrint('✅ OTP sent to $phoneNumber');
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
      final user = await _repo.login(email, password);
      await _saveAndSetState(user);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Register with email/password
  Future<void> register(String name, String email, String password, {String? phone}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _repo.register(name: name, email: email, password: password, phone: phone);
      await _saveAndSetState(user);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
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
      await _storage.clearAllExceptTheme();

      state = AuthRiverpodState(
        onboardingComplete: state.onboardingComplete,
      );

      debugPrint('✅ User logged out');
    } catch (e) {
      debugPrint('❌ Logout error: $e');
    }
  }

  /// Complete onboarding
  Future<void> completeOnboarding() async {
    await _storage.saveOnboardingCompleted(true);
    state = state.copyWith(onboardingComplete: true);
  }

  /// Update profile
  Future<void> updateProfile({String? name, String? phone, String? email, String? avatarUrl}) async {
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
    await _storage.saveUser({
      'id': user.id,
      'name': user.name,
      'phone': user.phone,
      'email': user.email,
      'avatar_url': user.avatarUrl,
    });

    state = state.copyWith(
      userId: user.id,
      userName: user.name,
      userPhone: user.phone,
      userEmail: user.email,
      avatarUrl: user.avatarUrl,
      isLoggedIn: true,
      isLoading: false,
      clearError: true,
      clearVerificationId: true,
    );
  }
}
