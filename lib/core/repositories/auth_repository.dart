import '../models/user.dart';
import '../network/interceptors.dart';
import '../repositories/base_repository.dart';

class AuthRepository extends BaseRepository {
  final AuthInterceptor _authInterceptor;

  AuthRepository(super.api, this._authInterceptor);

  Future<User> login(String email, String password) async {
    return safeCall(() async {
      final response = await api.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      final user = User.fromJson(response.data['user']);
      await _authInterceptor.saveToken(response.data['token']);
      return user;
    });
  }

  Future<User> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    return safeCall(() async {
      final response = await api.post('/auth/register', data: {
        'name': name,
        'email': email,
        'password': password,
        if (phone != null) 'phone': phone,
      });
      final user = User.fromJson(response.data['user']);
      await _authInterceptor.saveToken(response.data['token']);
      return user;
    });
  }

  Future<User> getProfile() async {
    return safeCall(() async {
      final response = await api.get('/auth/profile');
      return User.fromJson(response.data);
    });
  }

  Future<void> logout() async {
    await _authInterceptor.removeToken();
  }

  Future<bool> isLoggedIn() async {
    await _authInterceptor.loadToken();
    // Token is loaded from SharedPreferences; if present, user is logged in.
    // The AuthInterceptor exposes it via the Authorization header check.
    return true; // Will be refined with actual token validation
  }
}
