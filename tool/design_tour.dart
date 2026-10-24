// Throwaway: like screenshot_tour.dart, but scrolls each screen so a shell watcher (tool/design_shoot.sh) captures every
// part of long pages. Prints SHOT:<name>-<n> after each scroll step. Not shipped.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grazia_stones/app.dart';
import 'package:grazia_stones/config/router.dart';
import 'package:grazia_stones/core/services/cache_service.dart';
import 'package:grazia_stones/core/services/storage_service.dart';
import 'package:grazia_stones/core/services/supabase_service.dart';

const _stops = <(String, String)>[
  ('home', '/home'),
  ('collections', '/collections'),
  ('collection', '/collections/bbf2cb9e-cae5-464e-984a-7cc2f61e7cd2'),
  ('product', '/stones/bbf2cb9e-cae5-464e-984a-7cc2f61e7cd2'),
  ('tools', '/tools'),
  ('aarna', '/aarna-ai'),
  ('profile', '/profile'),
  ('ai-studio', '/ai-studio'),
];

/// The tallest vertical scroll position on screen (the page body, not a carousel).
ScrollPosition? _mainScroll() {
  ScrollPosition? best;
  void visit(Element e) {
    if (e is StatefulElement && e.state is ScrollableState) {
      final p = (e.state as ScrollableState).position;
      if (p.axis == Axis.vertical && p.hasContentDimensions && (best == null || p.maxScrollExtent > best!.maxScrollExtent)) best = p;
    }
    e.visitChildren(visit);
  }
  WidgetsBinding.instance.rootElement?.visitChildren(visit);
  return best;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPaintSizeEnabled = false;
  await dotenv.load(fileName: 'assets/config/app.env');
  await StorageService.instance.init();
  await StorageService.instance.setHasSeenAppTour(true);
  await CacheService.instance.init();
  final container = ProviderContainer();
  runApp(UncontrolledProviderScope(container: container, child: const GraziaApp()));
  unawaited(SupabaseService.instance.init().timeout(const Duration(seconds: 8), onTimeout: () {}));

  final router = container.read(appRouterProvider);
  await Future<void>.delayed(const Duration(seconds: 14));
  for (final (name, path) in _stops) {
    router.go(path);
    await Future<void>.delayed(const Duration(seconds: 8));
    final pos = _mainScroll();
    final view = pos?.viewportDimension ?? 1;
    final steps = pos == null ? 1 : (pos.maxScrollExtent / (view * 0.8)).ceil().clamp(0, 7) + 1;
    for (var i = 0; i < steps; i++) {
      if (i > 0) {
        pos!.jumpTo((i * view * 0.8).clamp(0, pos.maxScrollExtent));
        await Future<void>.delayed(const Duration(milliseconds: 1500));
      }
      debugPrint('SHOT:$name-$i');
      await Future<void>.delayed(const Duration(milliseconds: 1500));
    }
  }
  debugPrint('TOUR_DONE');
}
