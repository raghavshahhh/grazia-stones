import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grazia_stones/shared/widgets/grazia_bottom_nav.dart';

void main() {
  Future<List<int>> pump(WidgetTester tester, {int current = 0, double textScale = 1.0}) async {
    final taps = <int>[];
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: const Size(320, 640), textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            bottomNavigationBar: GraziaBottomNav(currentIndex: current, onTap: taps.add),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return taps;
  }

  testWidgets('pill tabs and AR button map to shell tab indices', (tester) async {
    final taps = await pump(tester);
    await tester.tap(find.bySemanticsLabel('Collections'));
    await tester.tap(find.bySemanticsLabel('AI Studio'));
    await tester.tap(find.bySemanticsLabel('Profile'));
    await tester.tap(find.bySemanticsLabel('Live AR'));
    expect(taps, [1, 2, 4, GraziaBottomNav.arTabIndex]);
    expect(find.text('AR'), findsNothing); // AR lives in the round button, not the pill
  });

  testWidgets('AR selected state + 1.3 text scale on a narrow phone render without overflow', (tester) async {
    await pump(tester, current: GraziaBottomNav.arTabIndex, textScale: 2.0);
    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('Live AR'), findsOneWidget);
    bool selected(String label) => tester
        .widget<Semantics>(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == label))
        .properties
        .selected!;
    expect(selected('Live AR'), isTrue);
    expect(selected('Home'), isFalse);
    expect(tester.getSize(find.byKey(GraziaBottomNav.arKey)).width, greaterThanOrEqualTo(48));
  });
}
