import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';


/// State restoration service
/// 
/// Features:
/// - Save/restore navigation state
/// - Preserve form data
/// - Auto-save on app pause
/// - Clear on logout
class StateRestorationService {
  static StateRestorationService? _instance;
  static StateRestorationService get instance => _instance ??= StateRestorationService._();

  StateRestorationService._();

  SharedPreferences? _prefs;

  // Keys
  static const String _navigationStateKey = 'navigation_state';
  static const String _formDataPrefix = 'form_data_';
  static const String _scrollPositionPrefix = 'scroll_position_';
  static const String _lastRouteKey = 'last_route';
  static const String _appStateKey = 'app_state';

  // ═══════════════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    debugPrint('💾 State restoration service initialized');
  }

  Future<void> _ensureInitialized() async {
    if (_prefs == null) {
      await init();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NAVIGATION STATE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Save navigation state
  Future<void> saveNavigationState(Map<String, dynamic> state) async {
    await _ensureInitialized();
    try {
      final stateJson = jsonEncode(state);
      await _prefs!.setString(_navigationStateKey, stateJson);
      debugPrint('💾 Navigation state saved');
    } catch (e) {
      debugPrint('❌ Error saving navigation state: $e');
    }
  }

  /// Restore navigation state
  Future<Map<String, dynamic>?> restoreNavigationState() async {
    await _ensureInitialized();
    try {
      final stateJson = _prefs!.getString(_navigationStateKey);
      if (stateJson != null) {
        debugPrint('💾 Navigation state restored');
        return jsonDecode(stateJson) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('❌ Error restoring navigation state: $e');
    }
    return null;
  }

  /// Save last route
  Future<void> saveLastRoute(String route) async {
    await _ensureInitialized();
    await _prefs!.setString(_lastRouteKey, route);
    debugPrint('💾 Last route saved: $route');
  }

  /// Get last route
  Future<String?> getLastRoute() async {
    await _ensureInitialized();
    return _prefs!.getString(_lastRouteKey);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FORM DATA
  // ═══════════════════════════════════════════════════════════════════════════

  /// Save form data
  Future<void> saveFormData(String formId, Map<String, dynamic> data) async {
    await _ensureInitialized();
    try {
      final dataJson = jsonEncode(data);
      await _prefs!.setString('$_formDataPrefix$formId', dataJson);
      debugPrint('💾 Form data saved: $formId');
    } catch (e) {
      debugPrint('❌ Error saving form data: $e');
    }
  }

  /// Restore form data
  Future<Map<String, dynamic>?> restoreFormData(String formId) async {
    await _ensureInitialized();
    try {
      final dataJson = _prefs!.getString('$_formDataPrefix$formId');
      if (dataJson != null) {
        debugPrint('💾 Form data restored: $formId');
        return jsonDecode(dataJson) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('❌ Error restoring form data: $e');
    }
    return null;
  }

  /// Clear form data
  Future<void> clearFormData(String formId) async {
    await _ensureInitialized();
    await _prefs!.remove('$_formDataPrefix$formId');
    debugPrint('💾 Form data cleared: $formId');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SCROLL POSITION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Save scroll position for a screen
  Future<void> saveScrollPosition(String screenId, double position) async {
    await _ensureInitialized();
    await _prefs!.setDouble('$_scrollPositionPrefix$screenId', position);
  }

  /// Restore scroll position
  Future<double?> restoreScrollPosition(String screenId) async {
    await _ensureInitialized();
    return _prefs!.getDouble('$_scrollPositionPrefix$screenId');
  }

  /// Clear scroll position
  Future<void> clearScrollPosition(String screenId) async {
    await _ensureInitialized();
    await _prefs!.remove('$_scrollPositionPrefix$screenId');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // APP STATE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Save general app state
  Future<void> saveAppState(Map<String, dynamic> state) async {
    await _ensureInitialized();
    try {
      final stateJson = jsonEncode(state);
      await _prefs!.setString(_appStateKey, stateJson);
      debugPrint('💾 App state saved');
    } catch (e) {
      debugPrint('❌ Error saving app state: $e');
    }
  }

  /// Restore app state
  Future<Map<String, dynamic>?> restoreAppState() async {
    await _ensureInitialized();
    try {
      final stateJson = _prefs!.getString(_appStateKey);
      if (stateJson != null) {
        debugPrint('💾 App state restored');
        return jsonDecode(stateJson) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('❌ Error restoring app state: $e');
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CLEANUP
  // ═══════════════════════════════════════════════════════════════════════════

  /// Clear all restoration data
  Future<void> clearAll() async {
    await _ensureInitialized();
    final keys = _prefs!.getKeys();
    
    for (final key in keys) {
      if (key == _navigationStateKey ||
          key == _lastRouteKey ||
          key == _appStateKey ||
          key.startsWith(_formDataPrefix) ||
          key.startsWith(_scrollPositionPrefix)) {
        await _prefs!.remove(key);
      }
    }
    
    debugPrint('💾 All restoration data cleared');
  }

  /// Clear all form data
  Future<void> clearAllFormData() async {
    await _ensureInitialized();
    final keys = _prefs!.getKeys();
    
    for (final key in keys) {
      if (key.startsWith(_formDataPrefix)) {
        await _prefs!.remove(key);
      }
    }
    
    debugPrint('💾 All form data cleared');
  }

  /// Clear all scroll positions
  Future<void> clearAllScrollPositions() async {
    await _ensureInitialized();
    final keys = _prefs!.getKeys();
    
    for (final key in keys) {
      if (key.startsWith(_scrollPositionPrefix)) {
        await _prefs!.remove(key);
      }
    }
    
    debugPrint('💾 All scroll positions cleared');
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// RESTORATION MIXIN
// ═══════════════════════════════════════════════════════════════════════════

/// Mixin for automatic form state restoration
mixin FormRestorationMixin<T extends StatefulWidget> on State<T> {
  String get formId;
  
  /// Override this to provide form data for saving
  Map<String, dynamic> getFormData();
  
  /// Override this to restore form data
  void setFormData(Map<String, dynamic> data);

  @override
  void initState() {
    super.initState();
    _restoreFormData();
  }

  Future<void> _restoreFormData() async {
    final data = await StateRestorationService.instance.restoreFormData(formId);
    if (data != null && mounted) {
      setFormData(data);
    }
  }

  Future<void> saveFormState() async {
    await StateRestorationService.instance.saveFormData(formId, getFormData());
  }

  Future<void> clearFormState() async {
    await StateRestorationService.instance.clearFormData(formId);
  }

  @override
  void dispose() {
    // Auto-save on dispose
    saveFormState();
    super.dispose();
  }
}

/// Mixin for automatic scroll position restoration
mixin ScrollRestorationMixin<T extends StatefulWidget> on State<T> {
  String get screenId;
  late ScrollController scrollController;

  @override
  void initState() {
    super.initState();
    scrollController = ScrollController();
    _restoreScrollPosition();
  }

  Future<void> _restoreScrollPosition() async {
    final position = await StateRestorationService.instance.restoreScrollPosition(screenId);
    if (position != null && mounted && scrollController.hasClients) {
      scrollController.jumpTo(position);
    }
  }

  Future<void> saveScrollState() async {
    if (scrollController.hasClients) {
      await StateRestorationService.instance.saveScrollPosition(
        screenId,
        scrollController.offset,
      );
    }
  }

  @override
  void dispose() {
    // Save scroll position before dispose
    saveScrollState();
    scrollController.dispose();
    super.dispose();
  }
}
