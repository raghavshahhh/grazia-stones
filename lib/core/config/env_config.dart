import 'package:flutter/foundation.dart';

/// Environment configuration for the app
/// In production, use flutter_dotenv or similar package to load from .env file
class EnvConfig {
  // Singleton
  static final EnvConfig _instance = EnvConfig._internal();
  factory EnvConfig() => _instance;
  EnvConfig._internal();

  // ═══════════════════════════════════════════════════════════════════════
  // ENVIRONMENT
  // ═══════════════════════════════════════════════════════════════════════

  bool get isProduction => kReleaseMode;
  bool get isDevelopment => kDebugMode;

  // ═══════════════════════════════════════════════════════════════════════
  // SUPABASE CONFIGURATION
  // ═══════════════════════════════════════════════════════════════════════

  String get supabaseUrl {
    return const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://jrrmjtbauimrrxwjvmzh.supabase.co',
    );
  }

  String get supabasePublishableKey {
    return const String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
      defaultValue: String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        defaultValue: 'sb_publishable_l0K305hiCMwZ8Mh3lON3YQ_ueSMXo4a',
      ),
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
