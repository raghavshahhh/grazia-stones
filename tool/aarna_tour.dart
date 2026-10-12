// Throwaway: boots the real app and walks the router so a shell watcher can
// capture simulator screenshots on each SHOT:<name> marker. Not shipped.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grazia_stones/app.dart';
import 'package:grazia_stones/config/router.dart';
import 'package:grazia_stones/core/services/cache_service.dart';
import 'package:grazia_stones/core/services/storage_service.dart';
import 'package:grazia_stones/core/services/supabase_service.dart';

const _stops = <(String, String)>[
  ('app-aarna', '/aarna-ai'),
];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'assets/config/app.env');
  await StorageService.instance.init();
  await CacheService.instance.init();
  final container = ProviderContainer();
  runApp(UncontrolledProviderScope(container: container, child: const GraziaApp()));
  unawaited(SupabaseService.instance.init().timeout(const Duration(seconds: 8), onTimeout: () {}));

  final router = container.read(appRouterProvider);
  await Future<void>.delayed(const Duration(seconds: 12));
  debugPrint('REC_START');
  for (final (name, path) in _stops) {
    router.go(path);
    await Future<void>.delayed(const Duration(seconds: 28));
    debugPrint('SHOT:$name');
    await Future<void>.delayed(const Duration(seconds: 3));
  }
  debugPrint('TOUR_DONE');
}
