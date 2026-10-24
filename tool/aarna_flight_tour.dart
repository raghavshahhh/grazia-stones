// Throwaway: opens Aarna AI, prints SHOT markers, then sends a message so the stage → header flight can be recorded.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grazia_stones/app.dart';
import 'package:grazia_stones/config/router.dart';
import 'package:grazia_stones/core/services/cache_service.dart';
import 'package:grazia_stones/core/services/storage_service.dart';
import 'package:grazia_stones/core/services/supabase_service.dart';

TextField? _field() {
  TextField? f;
  void visit(Element e) {
    if (e.widget is TextField && (e.widget as TextField).onSubmitted != null) f = e.widget as TextField;
    e.visitChildren(visit);
  }
  WidgetsBinding.instance.rootElement?.visitChildren(visit);
  return f;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'assets/config/app.env');
  await StorageService.instance.init();
  await StorageService.instance.setHasSeenAppTour(true);
  await CacheService.instance.init();
  final container = ProviderContainer();
  runApp(UncontrolledProviderScope(container: container, child: const GraziaApp()));
  unawaited(SupabaseService.instance.init().timeout(const Duration(seconds: 8), onTimeout: () {}));
  final router = container.read(appRouterProvider);
  await Future<void>.delayed(const Duration(seconds: 14));
  router.push('/aarna-ai');
  await Future<void>.delayed(const Duration(seconds: 8));
  debugPrint('SHOT:stage');
  await Future<void>.delayed(const Duration(seconds: 2));
  debugPrint('REC_START');
  await Future<void>.delayed(const Duration(seconds: 2));
  _field()?.onSubmitted?.call('Show me marble for my living room wall');
  await Future<void>.delayed(const Duration(seconds: 4));
  debugPrint('REC_STOP');
  debugPrint('SHOT:after');
  await Future<void>.delayed(const Duration(seconds: 2));
  debugPrint('TOUR_DONE');
}
