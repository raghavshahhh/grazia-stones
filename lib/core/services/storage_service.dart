import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Centralized storage service for the app
/// Handles Hive (local DB), SharedPreferences (simple key-value), and SecureStorage (sensitive data)
class StorageService {
  static StorageService? _instance;
  static StorageService get instance => _instance ??= StorageService._();
  
  StorageService._();

  late SharedPreferences _prefs;
  late FlutterSecureStorage _secureStorage;
  late Box _appBox;
  late Box _cartBox;
  late Box _wishlistBox;
  late Box _userBox;

  bool _initialized = false;

  /// Initialize all storage systems
  Future<void> init() async {
    if (_initialized) return;

    // Initialize Hive
    await Hive.initFlutter();
    
    // Open boxes
    _appBox = await Hive.openBox('app_settings');
    _cartBox = await Hive.openBox('cart');
    _wishlistBox = await Hive.openBox('wishlist');
    _userBox = await Hive.openBox('user');

    // Initialize SharedPreferences
    _prefs = await SharedPreferences.getInstance();

    // Initialize SecureStorage
    _secureStorage = const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    );

    _initialized = true;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SHARED PREFERENCES (Simple data)
  // ═══════════════════════════════════════════════════════════════════════

  Future<bool> setString(String key, String value) => _prefs.setString(key, value);
  String? getString(String key) => _prefs.getString(key);

  Future<bool> setBool(String key, bool value) => _prefs.setBool(key, value);
  bool? getBool(String key) => _prefs.getBool(key);

  Future<bool> setInt(String key, int value) => _prefs.setInt(key, value);
  int? getInt(String key) => _prefs.getInt(key);

  Future<bool> setDouble(String key, double value) => _prefs.setDouble(key, value);
  double? getDouble(String key) => _prefs.getDouble(key);

  Future<bool> setStringList(String key, List<String> value) => _prefs.setStringList(key, value);
  List<String>? getStringList(String key) => _prefs.getStringList(key);

  Future<bool> remove(String key) => _prefs.remove(key);
  Future<bool> clear() => _prefs.clear();

  // ═══════════════════════════════════════════════════════════════════════
  // SECURE STORAGE (Sensitive data like tokens)
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> secureWrite(String key, String value) => _secureStorage.write(key: key, value: value);
  Future<String?> secureRead(String key) => _secureStorage.read(key: key);
  Future<void> secureDelete(String key) => _secureStorage.delete(key: key);
  Future<void> secureDeleteAll() => _secureStorage.deleteAll();

  // Auth Token Management
  Future<void> saveAuthToken(String token) => secureWrite('auth_token', token);
  Future<String?> getAuthToken() => secureRead('auth_token');
  Future<void> deleteAuthToken() => secureDelete('auth_token');

  Future<void> saveRefreshToken(String token) => secureWrite('refresh_token', token);
  Future<String?> getRefreshToken() => secureRead('refresh_token');

  // ═══════════════════════════════════════════════════════════════════════
  // HIVE (Complex objects and lists)
  // ═══════════════════════════════════════════════════════════════════════

  // App Settings
  Future<void> saveThemeMode(bool isDark) => _appBox.put('theme_mode_v4', isDark);
  bool getThemeMode() => _appBox.get('theme_mode_v4', defaultValue: false);

  Future<void> saveOnboardingCompleted(bool completed) => _appBox.put('onboarding_completed', completed);
  bool getOnboardingCompleted() => _appBox.get('onboarding_completed', defaultValue: false);

  Future<void> saveLanguage(String lang) => _appBox.put('language', lang);
  String getLanguage() => _appBox.get('language', defaultValue: 'en');

  // Cart Management
  Future<void> saveCart(List<Map<String, dynamic>> cartItems) async {
    await _cartBox.put('items', jsonEncode(cartItems));
  }

  List<Map<String, dynamic>> getCart() {
    final data = _cartBox.get('items');
    if (data == null) return [];
    try {
      return List<Map<String, dynamic>>.from(jsonDecode(data));
    } catch (e) {
      return [];
    }
  }

  Future<void> clearCart() => _cartBox.delete('items');

  // Wishlist Management
  Future<void> saveWishlist(List<String> stoneIds) async {
    await _wishlistBox.put('stone_ids', stoneIds);
  }

  List<String> getWishlist() {
    final data = _wishlistBox.get('stone_ids');
    if (data == null) return [];
    return List<String>.from(data);
  }

  Future<void> addToWishlist(String stoneId) async {
    final list = getWishlist();
    if (!list.contains(stoneId)) {
      list.add(stoneId);
      await saveWishlist(list);
    }
  }

  Future<void> removeFromWishlist(String stoneId) async {
    final list = getWishlist();
    list.remove(stoneId);
    await saveWishlist(list);
  }

  bool isInWishlist(String stoneId) => getWishlist().contains(stoneId);

  Future<void> clearWishlist() => _wishlistBox.delete('stone_ids');

  // User Data
  Future<void> saveUser(Map<String, dynamic> userData) async {
    await _userBox.put('user_data', jsonEncode(userData));
  }

  Map<String, dynamic>? getUser() {
    final data = _userBox.get('user_data');
    if (data == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(data));
    } catch (e) {
      return null;
    }
  }

  Future<void> clearUser() => _userBox.delete('user_data');

  // ═══════════════════════════════════════════════════════════════════════
  // REGISTERED ACCOUNTS & CREDENTIALS
  // ═══════════════════════════════════════════════════════════════════════

  static const String demoEmail = 'architect@graziastones.com';
  static const String demoPassword = 'Grazia@2025';

  /// Save or update a registered account locally
  Future<void> saveRegisteredAccount({
    required String email,
    required String password,
    required String name,
    String? phone,
    String? role,
    String? company,
  }) async {
    final accounts = getRegisteredAccounts();
    final cleanEmail = email.trim().toLowerCase();
    accounts[cleanEmail] = {
      'email': cleanEmail,
      'password': password,
      'name': name,
      'phone': phone,
      'role': role ?? 'architect',
      'company': company ?? 'Grazia Architectural Studio',
      'created_at': DateTime.now().toIso8601String(),
    };
    await _userBox.put('registered_accounts_map', jsonEncode(accounts));
  }

  /// Retrieve all registered accounts (pre-seeded + user-created)
  Map<String, Map<String, dynamic>> getRegisteredAccounts() {
    final Map<String, Map<String, dynamic>> defaults = {
      demoEmail: {
        'email': demoEmail,
        'password': demoPassword,
        'name': 'Raghav Shah',
        'phone': '9876543210',
        'role': 'architect',
        'company': 'Grazia Architectural Studio',
      },
    };

    final raw = _userBox.get('registered_accounts_map');
    if (raw == null) return defaults;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final result = Map<String, Map<String, dynamic>>.from(defaults);
      decoded.forEach((key, val) {
        if (val is Map) {
          result[key.toLowerCase()] = Map<String, dynamic>.from(val);
        }
      });
      return result;
    } catch (_) {
      return defaults;
    }
  }

  /// Match email and password against registered accounts
  Map<String, dynamic>? findRegisteredAccount(String email, String password) {
    final accounts = getRegisteredAccounts();
    final cleanEmail = email.trim().toLowerCase();
    final acc = accounts[cleanEmail];
    if (acc != null && acc['password'] == password) {
      return acc;
    }
    return null;
  }

  /// Universal Client Profile Memory (retained across quotes, samples, cart, checkout)
  Future<void> saveClientProfile({
    String? name,
    String? phone,
    String? altPhone,
    String? email,
    String? company,
    String? address,
    String? city,
    String? state,
    String? pincode,
  }) async {
    final existing = getClientProfile();
    final updated = {
      'name': (name != null && name.trim().isNotEmpty) ? name.trim() : (existing['name'] ?? ''),
      'phone': (phone != null && phone.trim().isNotEmpty) ? phone.trim() : (existing['phone'] ?? ''),
      'alt_phone': (altPhone != null && altPhone.trim().isNotEmpty) ? altPhone.trim() : (existing['alt_phone'] ?? ''),
      'email': (email != null && email.trim().isNotEmpty) ? email.trim() : (existing['email'] ?? ''),
      'company': (company != null && company.trim().isNotEmpty) ? company.trim() : (existing['company'] ?? ''),
      'address': (address != null && address.trim().isNotEmpty) ? address.trim() : (existing['address'] ?? ''),
      'city': (city != null && city.trim().isNotEmpty) ? city.trim() : (existing['city'] ?? ''),
      'state': (state != null && state.trim().isNotEmpty) ? state.trim() : (existing['state'] ?? ''),
      'pincode': (pincode != null && pincode.trim().isNotEmpty) ? pincode.trim() : (existing['pincode'] ?? ''),
    };
    await _userBox.put('client_universal_profile', jsonEncode(updated));
  }

  Map<String, String> getClientProfile() {
    final data = _userBox.get('client_universal_profile');
    if (data == null) {
      final u = getUser();
      if (u != null) {
        return {
          'name': (u['name'] ?? '').toString(),
          'phone': (u['phone'] ?? '').toString(),
          'alt_phone': (u['alt_phone'] ?? '').toString(),
          'email': (u['email'] ?? '').toString(),
          'company': (u['company'] ?? '').toString(),
          'address': (u['address'] ?? '').toString(),
          'city': (u['city'] ?? '').toString(),
          'state': (u['state'] ?? '').toString(),
          'pincode': (u['pincode'] ?? '').toString(),
        };
      }
      return {};
    }
    try {
      final map = Map<String, dynamic>.from(jsonDecode(data));
      return map.map((k, v) => MapEntry(k, (v ?? '').toString()));
    } catch (_) {
      return {};
    }
  }

  // Search History
  Future<void> addSearchQuery(String query) async {
    final history = getSearchHistory();
    history.remove(query); // Remove if already exists
    history.insert(0, query); // Add to front
    if (history.length > 20) history.removeLast(); // Keep only 20
    await _appBox.put('search_history', history);
  }

  List<String> getSearchHistory() {
    final data = _appBox.get('search_history');
    if (data == null) return [];
    return List<String>.from(data);
  }

  Future<void> clearSearchHistory() => _appBox.delete('search_history');

  // Recently Viewed Stones
  Future<void> addRecentlyViewed(String stoneId) async {
    final recent = getRecentlyViewed();
    recent.remove(stoneId);
    recent.insert(0, stoneId);
    if (recent.length > 50) recent.removeLast();
    await _appBox.put('recently_viewed', recent);
  }

  List<String> getRecentlyViewed() {
    final data = _appBox.get('recently_viewed');
    if (data == null) return [];
    return List<String>.from(data);
  }

  Future<void> clearRecentlyViewed() => _appBox.delete('recently_viewed');

  // Interactive App Tour / First-Time Guide
  bool hasSeenAppTour() => _appBox.get('has_seen_app_tour') == true;
  Future<void> setHasSeenAppTour(bool seen) => _appBox.put('has_seen_app_tour', seen);

  // Local Sample Orders
  Future<void> saveLocalSampleOrder(Map<String, dynamic> sampleJson) async {
    final list = getLocalSampleOrders();
    list.insert(0, sampleJson);
    await _appBox.put('local_sample_orders', jsonEncode(list));
  }

  List<Map<String, dynamic>> getLocalSampleOrders() {
    final raw = _appBox.get('local_sample_orders');
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return List<Map<String, dynamic>>.from(
          decoded.map((x) => Map<String, dynamic>.from(x as Map)),
        );
      }
    } catch (_) {}
    return [];
  }

  // Generic Data Storage
  Future<void> saveData(String key, Map<String, dynamic> data) async {
    await _appBox.put(key, jsonEncode(data));
  }

  Map<String, dynamic>? getData(String key) {
    final data = _appBox.get(key);
    if (data == null) return null;
    try {
      if (data is String) {
        return Map<String, dynamic>.from(jsonDecode(data));
      } else if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> deleteData(String key) => _appBox.delete(key);

  // ═══════════════════════════════════════════════════════════════════════
  // CLEANUP
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> clearAll() async {
    await _prefs.clear();
    await _secureStorage.deleteAll();
    await _appBox.clear();
    await _cartBox.clear();
    await _wishlistBox.clear();
    await _userBox.clear();
  }

  Future<void> clearAllExceptTheme() async {
    final isDark = getThemeMode();
    await clearAll();
    await saveThemeMode(isDark);
  }

  Future<void> dispose() async {
    await _appBox.close();
    await _cartBox.close();
    await _wishlistBox.close();
    await _userBox.close();
  }
}
