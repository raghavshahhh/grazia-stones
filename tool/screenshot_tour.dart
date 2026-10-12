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
  ('app-home', '/home'),
  ('app-collections', '/collections'),
  ('app-collection-detail', '/collections/bbf2cb9e-cae5-464e-984a-7cc2f61e7cd2'),
  ('app-product', '/stones/bbf2cb9e-cae5-464e-984a-7cc2f61e7cd2'),
  ('app-ai-studio', '/ai-studio'),
  ('app-tools', '/tools'),
  ('app-ar', '/live-ai'),
  ('app-measure', '/wall-measurement'),
  ('app-3d-wall', '/vr-showroom'),
  ('app-saved', '/saved-designs'),
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
  for (final (name, path) in _stops) {
    router.go(path);
    await Future<void>.delayed(const Duration(seconds: 10));
    debugPrint('SHOT:$name');
    await Future<void>.delayed(const Duration(seconds: 3));
  }
  debugPrint('TOUR_DONE');
}
