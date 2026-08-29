import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment configuration for the app
class EnvConfig {
  // Singleton
  static final EnvConfig _instance = EnvConfig._internal();
  factory EnvConfig() => _instance;
  EnvConfig._internal();

  /// Helper to get env variable with fallback hierarchy:
  /// 1. dotenv runtime (.env file)
  /// 2. const String.fromEnvironment (build flag --dart-define)
  /// 3. defaultValue
  static String _getEnv(String key, String defaultValue) {
    if (dotenv.isInitialized && dotenv.env.containsKey(key)) {
      final val = dotenv.env[key];
      if (val != null && val.isNotEmpty && !val.contains('your-') && !val.contains('_PLACEHOLDER')) {
        return val;
      }
    }
    return String.fromEnvironment(key, defaultValue: defaultValue);
  }

  static bool _getBoolEnv(String key, bool defaultValue) {
    if (dotenv.isInitialized && dotenv.env.containsKey(key)) {
      final val = dotenv.env[key]?.toLowerCase();
      if (val == 'true') return true;
      if (val == 'false') return false;
    }
    return bool.fromEnvironment(key, defaultValue: defaultValue);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ENVIRONMENT
  // ═══════════════════════════════════════════════════════════════════════

  bool get isProduction => kReleaseMode;
  bool get isDevelopment => kDebugMode;

  // ═══════════════════════════════════════════════════════════════════════
  // SUPABASE CONFIGURATION
  // ═══════════════════════════════════════════════════════════════════════

  String get supabaseUrl {
    return _getEnv('SUPABASE_URL', 'https://jrrmjtbauimrrxwjvmzh.supabase.co');
  }

  String get supabasePublishableKey {
    return _getEnv(
      'SUPABASE_PUBLISHABLE_KEY',
      _getEnv('SUPABASE_ANON_KEY', 'sb_publishable_l0K305hiCMwZ8Mh3lON3YQ_ueSMXo4a'),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // API CONFIGURATION
  // ═══════════════════════════════════════════════════════════════════════

  String get apiBaseUrl {
    // TODO: Replace with your actual backend URL
    // For now, returning dev URL in debug mode, prod URL in release
    if (isDevelopment) {
      return const String.fromEnvironment(
        'API_BASE_URL_DEV',
        defaultValue: 'http://localhost:3000/api/v1',
      );
    }
    return const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://api.graziastones.com/v1',
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // FIREBASE CONFIGURATION
  // ═══════════════════════════════════════════════════════════════════════

  // NOTE: Firebase configuration should be done via firebase_options.dart
  // Run: flutterfire configure
  // This will generate the file automatically

  String get firebaseProjectId {
    return const String.fromEnvironment(
      'FIREBASE_PROJECT_ID',
      defaultValue: 'grazia-stones',
    );
  }

  String get firebaseStorageBucket {
    return const String.fromEnvironment(
      'FIREBASE_STORAGE_BUCKET',
      defaultValue: 'grazia-stones.appspot.com',
    );
  }

// ═══════════════════════════════════════════════════════════════════════
  // NVIDIA NIM (AI) CONFIGURATION
  // ══════════════════════════════════════════════════════════════════════

  String get nvidiaNimApiKey {
    return const String.fromEnvironment(
      'NVIDIA_NIM_API_KEY',
      defaultValue: '',
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // REPLICATE (AI) CONFIGURATION (legacy - not used)
  // ═════════════════════════════════════════════════════════════════════

  String get replicateApiKey {
    return const String.fromEnvironment(
      'REPLICATE_API_TOKEN',
      defaultValue: '',
    );
  }

  String get replicateBaseUrl => 'https://api.replicate.com/v1';

  // ═══════════════════════════════════════════════════════════════════════
  // PAYMENT CONFIGURATION
  // ═══════════════════════════════════════════════════════════════════════

  String get razorpayKeyId {
    if (isDevelopment) {
      return const String.fromEnvironment(
        'RAZORPAY_KEY_ID_TEST',
        defaultValue: 'rzp_test_PLACEHOLDER',
      );
    }
    return const String.fromEnvironment(
      'RAZORPAY_KEY_ID_LIVE',
      defaultValue: 'rzp_live_PLACEHOLDER',
    );
  }

  // Note: Never expose secret key in client code!
  // This is just for documentation purposes
  // Actual secret should only be on backend

  // ═══════════════════════════════════════════════════════════════════════
  // GOOGLE OAUTH CONFIGURATION
  // ═══════════════════════════════════════════════════════════════════════

  String get googleIosClientId => _getEnv('GOOGLE_IOS_CLIENT_ID', '');
  String get googleWebClientId => _getEnv('GOOGLE_WEB_CLIENT_ID', '');

  bool get isGoogleOAuthConfigured =>
      googleIosClientId.isNotEmpty || googleWebClientId.isNotEmpty;

  // ═══════════════════════════════════════════════════════════════════════
  // CDN CONFIGURATION
  // ═══════════════════════════════════════════════════════════════════════

  String get cdnBaseUrl {
    return const String.fromEnvironment(
      'CDN_BASE_URL',
      defaultValue: 'https://res.cloudinary.com/grazia-stones/',
    );
  }

  String get cloudinaryCloudName {
    return const String.fromEnvironment(
      'CDN_CLOUD_NAME',
      defaultValue: 'grazia-stones',
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // FEATURE FLAGS
  // ═══════════════════════════════════════════════════════════════════════

  bool get enableMockData {
    // Allow mock data in development for testing
    return const bool.fromEnvironment(
      'ENABLE_MOCK_DATA',
      defaultValue: false, // Changed to false - we want real data!
    );
  }

  bool get enableAIVisualization {
    return const bool.fromEnvironment(
      'ENABLE_AI_VISUALIZATION',
      defaultValue: true,
    );
  }

  bool get enableARView {
    return const bool.fromEnvironment(
      'ENABLE_AR_VIEW',
      defaultValue: true,
    );
  }

  bool get enableDebugLogs {
    return isDevelopment || const bool.fromEnvironment(
      'ENABLE_DEBUG_LOGS',
      defaultValue: false,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ANALYTICS & MONITORING
  // ═══════════════════════════════════════════════════════════════════════

  String? get sentryDsn {
    const dsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');
    return dsn.isEmpty ? null : dsn;
  }

  String? get mixpanelToken {
    const token = String.fromEnvironment('MIXPANEL_TOKEN', defaultValue: '');
    return token.isEmpty ? null : token;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // APP INFO
  // ═══════════════════════════════════════════════════════════════════════

  String get appName {
    return const String.fromEnvironment(
      'APP_NAME',
      defaultValue: 'Grazia Stones',
    );
  }

  String get appVersion {
    return const String.fromEnvironment(
      'APP_VERSION',
      defaultValue: '1.0.0',
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TIMEOUTS & LIMITS
  // ═══════════════════════════════════════════════════════════════════════

  Duration get apiTimeout => const Duration(seconds: 30);
  Duration get uploadTimeout => const Duration(minutes: 2);
  Duration get aiProcessingTimeout => const Duration(seconds: 45);

  int get maxImageUploadSizeMB => 10;
  int get maxCacheAgeDays => 7;
  int get maxCartItems => 50;

  // ═══════════════════════════════════════════════════════════════════════
  // DEBUGGING
  // ═══════════════════════════════════════════════════════════════════════

  void printConfig() {
    if (!enableDebugLogs) return;

    debugPrint('═══════════════════════════════════════════════════');
    debugPrint('🔧 GRAZIA STONES - CONFIGURATION');
    debugPrint('═══════════════════════════════════════════════════');
    debugPrint('Environment: ${isProduction ? "PRODUCTION" : "DEVELOPMENT"}');
    debugPrint('API Base URL: $apiBaseUrl');
    debugPrint('CDN Base URL: $cdnBaseUrl');
    debugPrint('Firebase Project: $firebaseProjectId');
    debugPrint('Razorpay Key: ${razorpayKeyId.substring(0, 15)}...');
    debugPrint('NVIDIA NIM API Key: ${nvidiaNimApiKey.isNotEmpty ? "CONFIGURED" : "MISSING"}');
    debugPrint('Mock Data: ${enableMockData ? "ENABLED" : "DISABLED"}');
    debugPrint('AI Visualization: ${enableAIVisualization ? "ENABLED" : "DISABLED"}');
    debugPrint('AR View: ${enableARView ? "ENABLED" : "DISABLED"}');
    debugPrint('═══════════════════════════════════════════════════');
  }
}
