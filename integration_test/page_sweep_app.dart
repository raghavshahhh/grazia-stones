// Signed-in page sweep (QA tool, not a unit test). Boots the real app, signs in, opens every route and logs
// framework errors per route. Read-only: it only navigates, never submits forms, orders, quotes or AI jobs.
//   flutter run -t integration_test/page_sweep_app.dart -d <simulator> \
//     --dart-define=QA_EMAIL=... --dart-define=QA_PASSWORD=...
// A host script screenshots the simulator on each "SWEEP SHOT <name>" log line (see build/page_sweep/).
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grazia_stones/app.dart';
import 'package:grazia_stones/config/router.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/services/supabase_service.dart';
import 'package:grazia_stones/core/widgets/error_boundary.dart';
import 'package:grazia_stones/main.dart' as app;

const _email = String.fromEnvironment('QA_EMAIL');
const _password = String.fromEnvironment('QA_PASSWORD');
// Optional comma-separated subset, e.g. --dart-define=ROUTES=/cart,/measure
const _only = String.fromEnvironment('ROUTES');
// Optional: also scroll each page to its end and take a second '<name>_end' shot (--dart-define=SCROLL_END=true).
const _scrollEnd = bool.fromEnvironment('SCROLL_END');

const _routes = [
  '/home',
  '/collections',
  '/tools',
  '/live-ai',
  '/vr-showroom',
  '/profile',
  '/scan-space',
  '/wall-measurement',
  '/choose-design',
  '/ai-visualization',
  '/customize-design',
  '/compare-designs',
  '/vr-spaces',
  '/pro',
  '/resources',
  '/boq-calculator',
  '/search',
  '/wishlist',
  '/sample-order',
  '/dealers',
  '/quotes',
  '/quotes/new',
  '/custom-design',
  '/orders',
  '/cart',
  '/checkout',
  '/edit-profile',
  '/addresses',
  '/saved-designs',
  '/samples',
  '/aarna-ai',
  '/ai-chat',
  '/studio',
  '/ai-studio',
  '/ai-jobs',
  '/catalogue',
  '/wall-calc',
  '/samples/request',
  '/ai-viz',
  '/ar-view',
  '/ar-measure',
  '/measure',
  '/measure/tile-visualizer',
  '/settings',
  '/settings/permissions',
  '/about',
  '/privacy',
  '/delete-account',
  '/terms',
  '/help',
  '/admin',
  '/admin/dashboard',
  '/admin/plans',
  '/admin/products',
  '/admin/products/add',
  '/admin/collections',
  '/admin/dealers',
  '/admin/orders',
  '/admin/quotes',
  '/admin/samples',
  '/admin/ai-jobs',
  '/login',
  '/register',
  '/forgot-password',
  '/reset-password',
];

Element? _find(bool Function(Element) test) {
  Element? hit;
  void visit(Element e) {
    if (hit != null) return;
    if (test(e)) {
      hit = e;
      return;
    }
    e.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(visit);
  return hit;
}

int _count(bool Function(Widget) test) {
  var n = 0;
  void visit(Element e) {
    if (test(e.widget)) n++;
    e.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(visit);
  return n;
}

Future<void> main() async {
  app.main();
  var current = 'boot';
  final errors = <String, List<String>>{};
  void record(String text) {
    errors.putIfAbsent(current, () => []).add(text);
    debugPrint('SWEEP ERR [$current] ${text.length > 300 ? text.substring(0, 300) : text}');
  }

  final appOnError = FlutterError.onError;
  FlutterError.onError = (d) {
    appOnError?.call(d);
    final where = d.toString().split('\n').where((l) => l.contains('package:grazia_stones')).take(2).join(' | ');
    record('${d.exceptionAsString().split('\n').first} @ $where');
  };
  final appPlatformError = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (e, s) {
    record('async: $e @ ${s.toString().split('\n').where((l) => l.contains('grazia_stones')).take(2).join(' | ')}');
    return appPlatformError?.call(e, s) ?? true;
  };

  await Future.delayed(const Duration(seconds: 5));
  await SupabaseService.instance.ready.timeout(const Duration(seconds: 15), onTimeout: () {});
  final container = ProviderScope.containerOf(_find((e) => e.widget is GraziaApp)!);
  await container.read(authRiverpodProvider.notifier).loginWithApi(_email, _password);
  await Future.delayed(const Duration(seconds: 3));
  final auth = container.read(authRiverpodProvider);
  debugPrint('SWEEP AUTH loggedIn=${auth.isLoggedIn} admin=${auth.isAdmin}');
  if (!auth.isLoggedIn) {
    debugPrint('SWEEP DONE (sign-in failed)');
    return;
  }

  final client = SupabaseService.instance.client;
  final routes = _only.isEmpty ? [..._routes] : _only.split(',');
  final skipped = <String, String>{};
  Future<void> addId(String table, String col, String route, {bool own = false, String? select}) async {
    try {
      var q = client.from(table).select(select ?? col).not(select == null ? col : 'metadata->>$col', 'is', null);
      if (own) q = q.eq('user_id', client.auth.currentUser!.id);
      final rows = await q.limit(1);
      if (rows.isEmpty) {
        skipped[route] = 'no $table row visible to QA account';
      } else {
        routes.add(route.replaceFirst(RegExp(r':\w+'), '${rows.first[col]}'));
      }
    } catch (e) {
      skipped[route] = 'id lookup failed: $e';
    }
  }

  if (_only.isEmpty) {
    await addId('collections', 'id', '/collections/:id');
    await addId('stones', 'id', '/stones/:id');
    await addId('stones', 'id', '/stone/:id');
    await addId('stones', 'id', '/admin/products/edit/:id');
    await addId('ai_jobs', 'batch_id', '/ai-viz/results/:batchId', own: true, select: 'batch_id:metadata->>batch_id');
    // Last: '/' re-enters the shell via splash; from inside the shell it trips the bottom-nav GlobalKey clash.
    routes.addAll(['/onboarding', '/']);
  }
  debugPrint('SWEEP SKIPPED ${jsonEncode(skipped)}');

  final router = container.read(appRouterProvider);
  final results = <Map<String, dynamic>>[];
  var i = 0;
  for (final route in routes) {
    i++;
    current = route;
    router.go(route);
    await Future.delayed(const Duration(milliseconds: 4500));
    final landed = router.routerDelegate.currentConfiguration.uri.toString();
    final errorWidgets = _count((w) => w is ErrorWidget || w is GraziaGlobalErrorWidget);
    final name = '${i.toString().padLeft(2, '0')}${route.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')}';
    results.add({
      'route': route,
      'landed': landed,
      'errors': errors[route] ?? [],
      'errorWidgets': errorWidgets,
      'shot': name,
    });
    debugPrint('SWEEP ROUTE $route -> $landed errors=${errors[route]?.length ?? 0} errorWidgets=$errorWidgets');
    debugPrint('SWEEP SHOT $name');
    await Future.delayed(const Duration(milliseconds: 2000));
    if (_scrollEnd) {
      void toEnd(Element e) {
        if (e is StatefulElement && e.state is ScrollableState) {
          final p = (e.state as ScrollableState).position;
          if (p.axis == Axis.vertical && p.maxScrollExtent > 0) p.jumpTo(p.maxScrollExtent);
        }
        e.visitChildren(toEnd);
      }
      // Twice: lazy slivers grow maxScrollExtent after the first jump.
      for (var k = 0; k < 2; k++) {
        WidgetsBinding.instance.rootElement?.visitChildren(toEnd);
        await Future.delayed(const Duration(milliseconds: 1200));
      }
      debugPrint('SWEEP SHOT ${name}_end');
      await Future.delayed(const Duration(milliseconds: 2000));
    }
  }
  current = 'done';
  debugPrint('SWEEP DONE');
  for (final r in results) {
    debugPrint('SWEEP JSON ${jsonEncode(r)}');
  }
}
