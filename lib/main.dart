import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grazia_stones/app.dart';
import 'package:grazia_stones/core/services/storage_service.dart';
import 'package:grazia_stones/core/services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
