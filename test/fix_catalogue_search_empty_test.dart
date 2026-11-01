import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/models/collection.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/core/repositories/stone_repository.dart';
import 'package:grazia_stones/core/services/mock_data_service.dart';
import 'package:grazia_stones/features/search/presentation/search_screen.dart';
import 'package:grazia_stones/features/wishlist/data/wishlist_repository.dart';
import 'package:grazia_stones/features/wishlist/providers/wishlist_provider.dart';

class _FakeStoneRepo implements StoneRepository {
  _FakeStoneRepo({this.fail = false});
  bool fail;
  int stoneCalls = 0;

  @override
  Future<List<Collection>> getCollections() async {
    if (fail) throw Exception('offline');
    return [];
  }

  @override
  Future<List<Stone>> getAllStones() async {
    stoneCalls++;
    if (fail) throw Exception('offline');
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeWishlistRepo implements WishlistRepository {
  @override
  Future<List<String>> getWishlistStoneIds() async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pump(WidgetTester tester, _FakeStoneRepo repo) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      stoneRepositoryProvider.overrideWithValue(repo),
      wishlistProvider.overrideWith((ref) => WishlistNotifier(_FakeWishlistRepo())),
    ],
    child: const MaterialApp(home: SearchScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('empty repository shows empty state, never mock products', (tester) async {
    await _pump(tester, _FakeStoneRepo());

    expect(find.text('Stones (0)'), findsOneWidget);
    expect(find.text('Collections (0)'), findsOneWidget);
    expect(find.text('No designs available yet'), findsOneWidget);
    expect(find.text(MockDataService.stones.first.name), findsNothing);
  });

  testWidgets('query with no match offers Clear search', (tester) async {
    await _pump(tester, _FakeStoneRepo());

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(find.text('No designs match "zzz"'), findsOneWidget);
    await tester.tap(find.text('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('No designs available yet'), findsOneWidget);
  });

  testWidgets('failure shows error state and Retry re-runs the query', (tester) async {
    final repo = _FakeStoneRepo(fail: true);
    await _pump(tester, repo);

    expect(find.text('Stones (0)'), findsNothing); // error state replaces the results
    final retry = find.byIcon(Icons.refresh_rounded);
    expect(retry, findsOneWidget);

    repo.fail = false;
    final before = repo.stoneCalls;
    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(repo.stoneCalls, greaterThan(before));
    expect(find.text('Stones (0)'), findsOneWidget);
  });
}
