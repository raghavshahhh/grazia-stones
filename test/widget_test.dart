import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grazia_stones/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const GraziaApp());
    await tester.pumpAndSettle();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
