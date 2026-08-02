import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/user.dart';
import '../../../core/repositories/auth_repository.dart';

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
      error: error,
    );
  }
}

// ─── Notifier ───
class AuthRiverpodNotifier extends StateNotifier<AuthRiverpodState> {
  final AuthRepository? _repo;

  AuthRiverpodNotifier([this._repo]) : super(AuthRiverpodState());

  void login(String userId, String name, String phone, {String? email}) {
    state = state.copyWith(
      userId: userId,
      userName: name,
      userPhone: phone,
      userEmail: email,
      isLoggedIn: true,
      error: null,
    );
  }

  void logout() {
    state = AuthRiverpodState();
    _repo?.logout();
  }

  void completeOnboarding() {
    state = state.copyWith(onboardingComplete: true);
  }

  void updateProfile({String? name, String? phone, String? email}) {
    state = state.copyWith(
      userName: name,
      userPhone: phone,
      userEmail: email,
    );
  }

  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  void setError(String error) {
    state = state.copyWith(error: error, isLoading: false);
  }

  // ─── API methods ───
  Future<void> loginWithApi(String email, String password) async {
    if (_repo == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _repo!.login(email, password);
      state = state.copyWith(
        userId: user.id,
        userName: user.name,
        userPhone: user.phone,
        userEmail: user.email,
        avatarUrl: user.avatarUrl,
        isLoggedIn: true,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> register(String name, String email, String password, {String? phone}) async {
    if (_repo == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _repo!.register(name: name, email: email, password: password, phone: phone);
      state = state.copyWith(
        userId: user.id,
        userName: user.name,
        userPhone: user.phone,
        userEmail: user.email,
        avatarUrl: user.avatarUrl,
        isLoggedIn: true,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadProfile() async {
    if (_repo == null) return;
    try {
      final user = await _repo!.getProfile();
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
