import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../../core/models/user.dart';
import '../../../core/repositories/auth_repository.dart';
import '../../../core/services/firebase_service.dart';
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
  final AuthRepository? _repo;
  final FirebaseService _firebase = FirebaseService.instance;
  final StorageService _storage = StorageService.instance;

  AuthRiverpodNotifier([this._repo]) : super(AuthRiverpodState()) {
    // Load persisted auth state on init
    _loadPersistedState();
  }

  /// Load auth state from storage on app start
  Future<void> _loadPersistedState() async {
    try {
      // Check onboarding status
      final onboardingComplete = _storage.getOnboardingCompleted();
      
      // Check if user is logged in via Firebase
      final firebaseUser = _firebase.currentUser;
      
      if (firebaseUser != null) {
        // User is logged in, load profile from storage
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
          
          debugPrint('✅ Auth state restored from storage');
        } else {
          // Firebase user exists but no local data, fetch from Firestore
          await _syncUserDataFromFirestore();
        }
      } else {
        // No Firebase user, just set onboarding status
        state = state.copyWith(onboardingComplete: onboardingComplete);
      }
    } catch (e) {
      debugPrint('❌ Error loading persisted auth state: $e');
    }
  }

  /// Sync user data from Firestore to local storage
  Future<void> _syncUserDataFromFirestore() async {
    try {
      final userData = await _firebase.getUserData();
      if (userData != null) {
        await _storage.saveUser(userData);
        state = state.copyWith(
          userId: userData['id'] as String?,
          userName: userData['name'] as String?,
          userPhone: userData['phone'] as String?,
          userEmail: userData['email'] as String?,
          avatarUrl: userData['avatar_url'] as String?,
          isLoggedIn: true,
        );
        debugPrint('✅ User data synced from Firestore');
      }
    } catch (e) {
      debugPrint('❌ Error syncing from Firestore: $e');
    }
  }

  /// Send OTP to phone number
  Future<bool> sendOTP(String phoneNumber) async {
    state = state.copyWith(isLoading: true, clearError: true);
    
    try {
      bool success = false;
      
      await _firebase.sendOTP(
        phoneNumber: phoneNumber,
        onCodeSent: (verificationId) {
          state = state.copyWith(
            verificationId: verificationId,
            isLoading: false,
            clearError: true,
          );
          success = true;
          debugPrint('✅ OTP sent successfully');
        },
        onError: (error) {
          state = state.copyWith(
            error: error,
            isLoading: false,
          );
          success = false;
          debugPrint('❌ OTP send error: $error');
        },
        onTimeout: () {
          state = state.copyWith(
            error: 'OTP request timed out',
            isLoading: false,
          );
          success = false;
        },
      );
      
      return success;
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
      return false;
    }
  }

  /// Verify OTP and complete login
  Future<bool> verifyOTP(String otp, {String? name, String? email, bool isRegistration = false}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    
    try {
      final userCredential = await _firebase.verifyOTP(
        otp: otp,
        verificationId: state.verificationId,
      );

      if (userCredential?.user == null) {
        state = state.copyWith(
          error: 'Verification failed',
          isLoading: false,
        );
        return false;
      }

      final firebaseUser = userCredential!.user!;
      
      // Create user data object
      final userData = {
        'id': firebaseUser.uid,
        'name': name ?? firebaseUser.displayName ?? 'User',
        'phone': firebaseUser.phoneNumber,
        'email': email ?? firebaseUser.email,
        'avatar_url': firebaseUser.photoURL,
        'created_at': DateTime.now().toIso8601String(),
      };

      // Save to Firestore
      if (isRegistration) {
        await _firebase.saveUserData(userData);
      }

      // Save to local storage
      await _storage.saveUser(userData);

      // Get auth token
      final token = await _firebase.getIdToken();
      if (token != null) {
        await _storage.saveAuthToken(token);
      }

      // Update state
      state = state.copyWith(
        userId: userData['id'] as String,
        userName: userData['name'] as String,
        userPhone: userData['phone'],
        userEmail: userData['email'],
        avatarUrl: userData['avatar_url'],
        isLoggedIn: true,
        isLoading: false,
        clearError: true,
        clearVerificationId: true,
      );

      debugPrint('✅ User authenticated successfully');
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

    // Save to storage
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
      // Sign out from Firebase
      await _firebase.signOut();
      
      // Clear local storage (except theme)
      await _storage.clearAllExceptTheme();
      
      // Reset state
      state = AuthRiverpodState(
        onboardingComplete: state.onboardingComplete,
      );
      
      _repo?.logout();
      
      debugPrint('✅ User logged out successfully');
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

      // Update local state
      final newState = state.copyWith(
        userName: name,
        userPhone: phone,
        userEmail: email,
        avatarUrl: avatarUrl,
        isLoading: false,
      );

      // Update in storage
      final userData = {
        'id': state.userId,
        'name': name ?? state.userName,
        'phone': phone ?? state.userPhone,
        'email': email ?? state.userEmail,
        'avatar_url': avatarUrl ?? state.avatarUrl,
      };
      await _storage.saveUser(userData);

      // Update in Firestore
      await _firebase.saveUserData(userData);

      state = newState;
      debugPrint('✅ Profile updated successfully');
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      debugPrint('❌ Profile update error: $e');
    }
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

  // ─── API methods (legacy compatibility) ───
  Future<void> loginWithApi(String email, String password) async {
    if (_repo == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _repo.login(email, password);
      login(user.id, user.name, user.phone ?? '', email: user.email);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> register(String name, String email, String password, {String? phone}) async {
    if (_repo == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _repo.register(name: name, email: email, password: password, phone: phone);
      login(user.id, user.name, user.phone ?? '', email: user.email);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadProfile() async {
    if (_repo == null) return;
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
}
