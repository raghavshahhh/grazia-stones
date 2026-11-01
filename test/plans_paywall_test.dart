import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grazia_stones/core/providers/ai_usage_provider.dart';
import 'package:grazia_stones/core/services/billing_service.dart';
import 'package:grazia_stones/features/pro/presentation/grazia_pro_screen.dart';

import 'plans_billing_test.dart' show FakeIap, product;

Future<void> pump(WidgetTester tester, FakeIap iap) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final svc = BillingService(iap: iap, currentUserId: () => 'user-uuid', verifier: (_) async {});
  await tester.pumpWidget(ProviderScope(
    overrides: [
      billingProvider.overrideWith((ref) => svc),
      aiUsageProvider.overrideWith((ref) async => null),
    ],
    child: const MaterialApp(home: GraziaProScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('no store products: honest message, no price', (tester) async {
    await pump(tester, FakeIap());
    expect(find.text('Grazia Pro'), findsOneWidget);
    expect(find.text('Plans are not available yet'), findsOneWidget);
    expect(find.textContaining('/month'), findsNothing);
  });

  testWidgets('shows the store price and switches Plus | Pro', (tester) async {
    final iap = FakeIap()..catalog = [product(BillingService.proId)];
    await pump(tester, iap);
    expect(find.text('Get Grazia Pro'), findsOneWidget);
    expect(find.textContaining('₹1,499.00/month. Auto-renews monthly.'), findsOneWidget);
    expect(find.text('200 AI renders a month (3x Plus)'), findsOneWidget);

    await tester.tap(find.text('Plus'));
    await tester.pumpAndSettle();
    expect(find.text('Grazia Plus'), findsOneWidget);
    expect(find.text('60 AI room renders a month'), findsOneWidget);
    expect(find.text('Plans are not available yet'), findsOneWidget); // Plus not in the store catalog
  });
}
