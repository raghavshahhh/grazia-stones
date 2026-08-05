import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grazia_stones/app.dart';
import 'package:grazia_stones/core/services/storage_service.dart';
import 'package:grazia_stones/core/services/firebase_service.dart';
import 'package:grazia_stones/core/network/api_service.dart';
import 'package:grazia_stones/core/services/ml_kit_service.dart';
import 'package:grazia_stones/core/services/payment_service.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize services
  try {
    // Initialize storage service first (Hive, SharedPrefs, SecureStorage)
    await StorageService.instance.init();
    debugPrint('✅ Storage service initialized');

    // Initialize Firebase (Auth, Firestore, Storage)
    await FirebaseService.instance.init();
    debugPrint('✅ Firebase service initialized');

    // Initialize API service (Dio with interceptors)
    ApiService.instance.init();
    debugPrint('✅ API service initialized');

    // Initialize ML Kit service (Image labeling)
    await MLKitService.instance.init();
    debugPrint('✅ ML Kit service initialized');

    // Initialize Payment service (Razorpay)
    PaymentService.instance.init();
    debugPrint('✅ Payment service initialized');
  } catch (e) {
    debugPrint('❌ Service initialization error: $e');
    // Continue app even if services fail to initialize
  }

  // Run app
  runApp(const ProviderScope(child: GraziaApp()));
}
