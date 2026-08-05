import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grazia_stones/app.dart';
import 'package:grazia_stones/core/services/storage_service.dart';
// DEMO MODE: Firebase, ML Kit, Payment services disabled
// import 'package:grazia_stones/core/services/firebase_service.dart';
import 'package:grazia_stones/core/network/api_service.dart';
// import 'package:grazia_stones/core/services/ml_kit_service.dart';
// import 'package:grazia_stones/core/services/payment_service.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize services (DEMO MODE - only essential services)
  try {
    // Initialize storage service first (Hive, SharedPrefs, SecureStorage)
    await StorageService.instance.init();
    debugPrint('✅ Storage service initialized');

    // DEMO MODE: Skip Firebase initialization
    // await FirebaseService.instance.init();
    debugPrint('⚠️ Firebase DISABLED for demo');

    // Initialize API service (Dio with interceptors) - will use mock data
    ApiService.instance.init();
    debugPrint('✅ API service initialized (mock mode)');

    // DEMO MODE: Skip ML Kit initialization
    // await MLKitService.instance.init();
    debugPrint('⚠️ ML Kit DISABLED for demo');

    // DEMO MODE: Skip Payment service initialization
    // PaymentService.instance.init();
    debugPrint('⚠️ Razorpay DISABLED for demo');
  } catch (e) {
    debugPrint('❌ Service initialization error: $e');
    // Continue app even if services fail to initialize
  }

  // Run app
  runApp(const ProviderScope(child: GraziaApp()));
}
