// AI Room Studio end to end with a fake HTTP adapter: no real render, no quota.
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/core/providers/ai_usage_provider.dart';
import 'package:grazia_stones/core/providers/stone_providers.dart' show allStonesProvider;
import 'package:grazia_stones/core/repositories/stone_repository.dart';
import 'package:grazia_stones/core/services/ai_endpoint_client.dart';
import 'package:grazia_stones/features/ai_viz/presentation/simple_ai_studio_screen.dart';
import 'package:grazia_stones/features/auth/providers/auth_riverpod_provider.dart';

const _grey = 'assets/images/mountain_ledge_m08_tex.png';
const _rust = 'assets/images/classic_ledge_07_tex.png';

Stone _stone(String id, String collection, {List<String> images = const [_grey], List<String> colours = const []}) =>
    Stone(
      id: id,
      name: 'Stone $id',
      productCode: id,
      collection: collection,
      category: 'Wall',
      pricePerSqFt: 0,
      description: '',
      images: images,
      availableColors: colours,
    );

final _me = _stone('me', 'Ledge', images: [_grey, _rust], colours: ['Grey', 'Rust']);
final _catalogue = [_me, _stone('l1', 'Ledge'), _stone('o1', 'Other')];

class _Repo extends Fake implements StoneRepository {
  @override
  Future<Stone> getStoneById(String id) async => _catalogue.firstWhere((s) => s.id == id);
}

/// Signed in, without the real notifier's Supabase/Hive startup.
class _LoggedIn extends StateNotifier<AuthRiverpodState> implements AuthRiverpodNotifier {
  _LoggedIn() : super(AuthRiverpodState(isLoggedIn: true, userId: 'u1'));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Holds each render request until the test releases it.
class _FakeAdapter implements HttpClientAdapter {
  final requests = <Map<String, dynamic>>[];
  final _gates = <Completer<void>>[];
  final png = 'data:image/png;base64,${base64Encode(img.encodePng(img.Image(width: 4, height: 4)))}';

  void release() => _gates.firstWhere((g) => !g.isCompleted).complete();

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    await requestStream?.drain<void>();
    requests.add(Map<String, dynamic>.from(options.data as Map));
    final gate = Completer<void>();
    _gates.add(gate);
    await gate.future;
    return ResponseBody.fromString(
      jsonEncode({'resultImage': png, 'creditsRemaining': 2, 'dailyRemaining': 2}),
      200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Image encoding runs in an isolate (real time), so wait outside the fake clock.
Future<void> _waitFor(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(done(), isTrue);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('progress card shows stages and time left; result offers colours and related stones', (tester) async {
    SharedPreferences.setMockInitialValues({});
    // Wide surface: the test font is much wider than Inter.
    tester.view.physicalSize = const Size(2400, 4400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final adapter = _FakeAdapter();
    final original = AIEndpointClient.dio.httpClientAdapter;
    AIEndpointClient.dio.httpClientAdapter = adapter;
    addTearDown(() => AIEndpointClient.dio.httpClientAdapter = original);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        authRiverpodProvider.overrideWith((ref) => _LoggedIn()),
        stoneRepositoryProvider.overrideWithValue(_Repo()),
        allStonesProvider.overrideWith((ref) async => _catalogue),
        aiUsageProvider.overrideWith((ref) async => null),
      ],
      child: const MaterialApp(home: SimpleAIStudioScreen(preSelectedStoneId: 'me')),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Stone me'), findsWidgets);

    // Step 1: a sample room.
    await tester.tap(find.text('Presets'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Living Room').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Generate Realistic Result'));
    await tester.pump();
    expect(find.text('Creating image'), findsOneWidget);
    expect(find.textContaining('s left'), findsOneWidget);

    await _waitFor(tester, () => adapter.requests.isNotEmpty);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Designing your wall'), findsOneWidget);
    final first = adapter.requests.single;
    expect(first['image'], startsWith('data:image/jpeg;base64,'));
    expect(first['stoneName'], 'Stone me');

    adapter.release();
    await _waitFor(tester, () => find.text('Try it in another colour').evaluate().isNotEmpty);
    await tester.pumpAndSettle();
    expect(find.text('Creating image'), findsNothing);
    expect(find.text('Grey'), findsOneWidget);
    expect(find.text('Rust'), findsOneWidget);
    expect(find.text('You may also like'), findsOneWidget);
    expect(find.text('Stone l1'), findsOneWidget);
    expect(find.text('Stone o1'), findsOneWidget); // same category, after the same-collection stone

    // Another colour starts a new render through the same endpoint (same quota path).
    await tester.ensureVisible(find.text('Rust'));
    await tester.tap(find.text('Rust'));
    await _waitFor(tester, () => adapter.requests.length == 2);
    expect(adapter.requests[1]['designImage'], isNot(first['designImage']));
    expect(adapter.requests[1]['image'], first['image']);
    adapter.release();
    await _waitFor(tester, () => find.text('Try it in another colour').evaluate().isNotEmpty);
    await tester.pumpAndSettle();

  });
}
