import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grazia_stones/app.dart';
import 'package:grazia_stones/core/services/storage_service.dart';
import 'package:grazia_stones/core/services/supabase_service.dart';
import 'package:grazia_stones/core/widgets/error_boundary.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global Exception & Flutter Error Boundary
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('🛡️ [Grazia Global Error Boundary]: ${details.exceptionAsString()}');
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('🛡️ [Grazia Platform Dispatcher Error]: $error');
    return true;
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return GraziaGlobalErrorWidget(details: details);
  };

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  try {
    // Load .env file
    await dotenv.load(fileName: '.env');

    // Initialize storage (Hive, SharedPrefs, SecureStorage)
    await StorageService.instance.init();
    debugPrint('✅ Storage service initialized');

    // Initialize Supabase
    await SupabaseService.instance.init();
    debugPrint('✅ Supabase initialized');
  } catch (e) {
    debugPrint('❌ Service initialization error: $e');
  }

  runApp(const ProviderScope(child: GraziaApp()));
}

