import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grazia_stones/core/models/collection.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/core/providers/stone_providers.dart';
import 'package:grazia_stones/features/collections/presentation/collection_detail_screen.dart';

const _patina = Collection(id: 'c1', name: 'Patina Series', description: '');
const _empty = Collection(id: 'c2', name: 'Opus Series', description: '');
const _stone = Stone(
  id: 's1',
  name: 'Patina Grey',
  productCode: 'P1',
  collection: 'Patina Series',
  category: 'Ledge Stone',
  pricePerSqFt: 0,
  description: '',
);
const _orphan = Stone(
  id: 's2',
  name: 'Orphan Stone',
  productCode: 'X',
  collection: '',
  category: 'Ledge Stone',
  pricePerSqFt: 0,
  description: '',
);

Future<void> _pump(WidgetTester tester, String id) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      allCollectionsProvider.overrideWith((ref) async => [_patina, _empty]),
      allStonesProvider.overrideWith((ref) async => [_stone, _orphan]),
    ],
    child: MaterialApp(home: CollectionDetailScreen(collectionId: id)),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('unknown id shows Collection Not Found, not the first collection', (tester) async {
    await _pump(tester, 'bogus');
    expect(find.text('Collection Not Found'), findsOneWidget);
    expect(find.text('Patina Series'), findsNothing);
  });

  testWidgets('empty collection shows empty state, never other collections\' stones', (tester) async {
    await _pump(tester, 'c2');
    expect(find.text('No designs in this collection yet'), findsOneWidget);
    expect(find.text('Patina Grey'), findsNothing);
    expect(find.text('Orphan Stone'), findsNothing);
  });
}
