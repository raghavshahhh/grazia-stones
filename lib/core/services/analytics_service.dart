import 'package:flutter/foundation.dart';

/// Analytics event types
enum AnalyticsEvent {
  // App Lifecycle
  appOpened,
  appBackgrounded,
  appClosed,
  
  // User Actions
  login,
  logout,
  signUp,
  
  // Product Events
  productViewed,
  productSearch,
  productFiltered,
  productShared,
  
  // Cart Events
  addToCart,
  removeFromCart,
  cartViewed,
  
  // Wishlist Events
  addToWishlist,
  removeFromWishlist,
  wishlistViewed,
  
  // Checkout Events
  checkoutStarted,
  checkoutCompleted,
  paymentInitiated,
  paymentSucceeded,
  paymentFailed,
  
  // Quote Events
  quoteRequested,
  quoteViewed,
  quoteShared,
  quoteDownloaded,
  
  // Sample Events
  sampleRequested,
  sampleTracked,
  
  // AI Events
  aiVisualizationStarted,
  aiVisualizationCompleted,
  aiVisualizationFailed,
  roomAnalysisCompleted,
  
  // Dealer Events
  dealerSearched,
  dealerViewed,
  dealerDirections,
  dealerCalled,
  
  // Settings Events
  settingsViewed,
  permissionRequested,
  permissionGranted,
  permissionDenied,
  
  // Error Events
  errorOccurred,
  crashReported,
}

/// Analytics service (config-ready for Firebase/Mixpanel)
/// 
/// Features:
/// - Event tracking with parameters
/// - User properties
/// - Screen tracking
/// - Config-ready for external services
class AnalyticsService {
  static AnalyticsService? _instance;
  static AnalyticsService get instance => _instance ??= AnalyticsService._();

  AnalyticsService._();

  // Callbacks for external analytics services
  Function(String event, Map<String, dynamic>? parameters)? _firebaseAnalytics;
  Function(String event, Map<String, dynamic>? parameters)? _mixpanelAnalytics;
  Function(String userId, Map<String, dynamic>? properties)? _userPropertiesSetter;

  bool _isEnabled = true;
  String? _userId;

  // ═══════════════════════════════════════════════════════════════════════════
  // CONFIGURATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Initialize analytics service
  void init({
    Function(String, Map<String, dynamic>?)? firebaseCallback,
    Function(String, Map<String, dynamic>?)? mixpanelCallback,
    Function(String, Map<String, dynamic>?)? userPropertiesCallback,
  }) {
    _firebaseAnalytics = firebaseCallback;
    _mixpanelAnalytics = mixpanelCallback;
    _userPropertiesSetter = userPropertiesCallback;
    
    debugPrint('📊 Analytics service initialized');
  }

  /// Enable/disable analytics
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    debugPrint('📊 Analytics ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Check if analytics is enabled
  bool get isEnabled => _isEnabled;

  // ═══════════════════════════════════════════════════════════════════════════
  // USER IDENTIFICATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Set current user ID
  void setUserId(String? userId) {
    _userId = userId;
    if (userId != null) {
      _userPropertiesSetter?.call(userId, null);
      debugPrint('📊 User ID set: $userId');
    }
  }

  /// Set user properties
  void setUserProperties(Map<String, dynamic> properties) {
    if (!_isEnabled) return;
    
    if (_userId != null) {
      _userPropertiesSetter?.call(_userId!, properties);
    }
    
    if (kDebugMode) {
      debugPrint('📊 User properties: $properties');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EVENT TRACKING
  // ═══════════════════════════════════════════════════════════════════════════

  /// Track an analytics event
  void logEvent(
    AnalyticsEvent event, {
    Map<String, dynamic>? parameters,
  }) {
    if (!_isEnabled) return;

    final eventName = _getEventName(event);
    final enrichedParams = _enrichParameters(parameters ?? {});

    // Log to console in debug mode
    if (kDebugMode) {
      debugPrint('📊 Event: $eventName');
      if (enrichedParams.isNotEmpty) {
        debugPrint('   Parameters: $enrichedParams');
      }
    }

    // Send to Firebase Analytics
    _firebaseAnalytics?.call(eventName, enrichedParams);

    // Send to Mixpanel
    _mixpanelAnalytics?.call(eventName, enrichedParams);
  }

  /// Track screen view
  void logScreenView(String screenName, {String? screenClass}) {
    if (!_isEnabled) return;

    final parameters = {
      'screen_name': screenName,
      if (screenClass != null) 'screen_class': screenClass,
    };

    if (kDebugMode) {
      debugPrint('📊 Screen: $screenName');
    }

    _firebaseAnalytics?.call('screen_view', parameters);
    _mixpanelAnalytics?.call('screen_view', parameters);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SPECIFIC EVENT HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  void logLogin(String method) {
    logEvent(AnalyticsEvent.login, parameters: {'method': method});
  }

  void logSignUp(String method) {
    logEvent(AnalyticsEvent.signUp, parameters: {'method': method});
  }

  void logProductView(String productId, String productName, {String? category}) {
    logEvent(AnalyticsEvent.productViewed, parameters: {
      'product_id': productId,
      'product_name': productName,
      if (category != null) 'category': category,
    });
  }

  void logProductSearch(String query, {int? resultCount}) {
    logEvent(AnalyticsEvent.productSearch, parameters: {
      'search_query': query,
      if (resultCount != null) 'result_count': resultCount,
    });
  }

  void logAddToCart(String productId, String productName, double price) {
    logEvent(AnalyticsEvent.addToCart, parameters: {
      'product_id': productId,
      'product_name': productName,
      'price': price,
    });
  }

  void logRemoveFromCart(String productId) {
    logEvent(AnalyticsEvent.removeFromCart, parameters: {
      'product_id': productId,
    });
  }

  void logCheckoutStarted(double totalAmount, int itemCount) {
    logEvent(AnalyticsEvent.checkoutStarted, parameters: {
      'total_amount': totalAmount,
      'item_count': itemCount,
    });
  }

  void logPurchase({
    required String orderId,
    required double amount,
    required String currency,
    int? itemCount,
  }) {
    logEvent(AnalyticsEvent.checkoutCompleted, parameters: {
      'order_id': orderId,
      'amount': amount,
      'currency': currency,
      if (itemCount != null) 'item_count': itemCount,
    });
  }

  void logPaymentMethod(String method, double amount) {
    logEvent(AnalyticsEvent.paymentInitiated, parameters: {
      'payment_method': method,
      'amount': amount,
    });
  }

  void logQuoteRequest({
    required int stoneCount,
    required String projectType,
  }) {
    logEvent(AnalyticsEvent.quoteRequested, parameters: {
      'stone_count': stoneCount,
      'project_type': projectType,
    });
  }

  void logAIVisualization({
    required String stoneId,
    required bool success,
    int? processingTimeMs,
  }) {
    final event = success
        ? AnalyticsEvent.aiVisualizationCompleted
        : AnalyticsEvent.aiVisualizationFailed;
    
    logEvent(event, parameters: {
      'stone_id': stoneId,
      if (processingTimeMs != null) 'processing_time_ms': processingTimeMs,
    });
  }

  void logRoomAnalysis({
    required int wallCount,
    required int objectCount,
    required bool success,
  }) {
    logEvent(AnalyticsEvent.roomAnalysisCompleted, parameters: {
      'wall_count': wallCount,
      'object_count': objectCount,
      'success': success,
    });
  }

  void logDealerSearch({
    String? location,
    int? resultCount,
  }) {
    logEvent(AnalyticsEvent.dealerSearched, parameters: {
      if (location != null) 'location': location,
      if (resultCount != null) 'result_count': resultCount,
    });
  }

  void logPermission({
    required String permission,
    required bool granted,
  }) {
    final event = granted
        ? AnalyticsEvent.permissionGranted
        : AnalyticsEvent.permissionDenied;
    
    logEvent(event, parameters: {'permission': permission});
  }

  void logError({
    required String errorType,
    required String errorMessage,
    String? stackTrace,
  }) {
    logEvent(AnalyticsEvent.errorOccurred, parameters: {
      'error_type': errorType,
      'error_message': errorMessage,
      if (stackTrace != null) 'has_stack_trace': true,
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  String _getEventName(AnalyticsEvent event) {
    return event.toString().split('.').last;
  }

  Map<String, dynamic> _enrichParameters(Map<String, dynamic> parameters) {
    return {
      ...parameters,
      'timestamp': DateTime.now().toIso8601String(),
      if (_userId != null) 'user_id': _userId,
    };
  }
}
