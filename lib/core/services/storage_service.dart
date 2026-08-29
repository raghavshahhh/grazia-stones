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
  Future<void> saveThemeMode(bool isDark) => _appBox.put('theme_dark', isDark);
  bool getThemeMode() => _appBox.get('theme_dark', defaultValue: false);

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
