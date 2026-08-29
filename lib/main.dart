import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:grazia_stones/app.dart';
import 'package:grazia_stones/core/config/env_config.dart';
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
    await dotenv.load(fileName: ".env");
    debugPrint('✅ Environment variables loaded from .env');
  } catch (e) {
    debugPrint('⚠️ Could not load .env file, using default configurations: $e');
  }

  try {
    // Local disk only (Hive, SharedPrefs, Keychain) — fast, no network, safe
    // to await before first frame since router/auth state reads it synchronously.
    await StorageService.instance.init();
    debugPrint('✅ Storage service initialized');
  } catch (e) {
    debugPrint('❌ Storage initialization error: $e');
  }

  // Render the first frame now. Supabase init includes a network round-trip
  // (session refresh + connectivity check) and must NEVER gate app startup —
  // a slow/unreachable network would otherwise freeze the splash screen forever.
  runApp(const ProviderScope(child: GraziaApp()));

  unawaited(
    SupabaseService.instance
        .init()
        .timeout(
          const Duration(seconds: 8),
          onTimeout: () => debugPrint('⚠️ Supabase initialization timed out'),
        )
        .then((_) => debugPrint('✅ Supabase initialized'))
        .catchError((e) => debugPrint('❌ Supabase initialization error: $e')),
  );

  EnvConfig().printConfig();
}