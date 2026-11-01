import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grazia_stones/features/admin/presentation/admin_ai_usage_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> pump(WidgetTester tester, AdminAiUsageLoader load) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(child: MaterialApp(home: AdminAiUsageScreen(load: load))));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final rows = AdminAiUsageRow.parse([
    {
      'user_id': 'u1', 'email': 'heavy@test.com', 'full_name': 'Heavy User', 'plan': 'pro',
      'renders': 42, 'chats': 3, 'prompt_tokens': 80000, 'output_tokens': 45678, 'total_tokens': 125678,
      'failed': 2, 'last_used': DateTime.now().subtract(const Duration(hours: 2)).toUtc().toIso8601String(),
    },
    {'user_id': 'u2', 'email': 'light@test.com', 'plan': 'free', 'renders': 1, 'chats': 0, 'total_tokens': 2300},
    {'user_id': null, 'chats': 5, 'total_tokens': 900},
  ]);

  testWidgets('shows totals, users and switches period', (tester) async {
    final calls = <DateTime?>[];
    await pump(tester, (since) async {
      calls.add(since);
      return since == null ? rows : rows.take(1).toList();
    });

    // Default period is 7 days.
    expect(calls.single, isNotNull);
    expect(DateTime.now().difference(calls.single!).inDays, 7);
    expect(find.text('Heavy User'), findsOneWidget);
    expect(find.text('Pro'), findsOneWidget);
    expect(find.textContaining('42 renders · 3 chats · 1,25,678 tokens · 2 failed'), findsOneWidget);
    expect(find.textContaining('last used 2 hours ago'), findsOneWidget);
    expect(find.text('Active users'), findsOneWidget);

    await tester.tap(find.text('All time'));
    await tester.pumpAndSettle();
    expect(calls.last, isNull);
    expect(find.text('light@test.com'), findsOneWidget);
    expect(find.text('Guests (signed out)'), findsOneWidget);
    expect(find.text('1,28,878'), findsOneWidget); // total tokens across all rows
    expect(find.text('43'), findsOneWidget); // renders
    expect(find.text('2'), findsOneWidget); // active users: guests are not counted
  });

  testWidgets('empty period is honest', (tester) async {
    await pump(tester, (_) async => const []);
    expect(find.text('No AI usage in this period.'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(4));
  });

  testWidgets('missing RPC says tracking is not enabled', (tester) async {
    await pump(tester, (_) async => throw const PostgrestException(message: 'Could not find the function public.admin_ai_usage', code: 'PGRST202'));
    expect(find.text('Usage tracking is not enabled on the server yet.'), findsOneWidget);
    expect(find.text('Renders'), findsNothing);
  });

  testWidgets('other errors are shown, not hidden', (tester) async {
    await pump(tester, (_) async => throw const PostgrestException(message: 'admin only', code: '42501'));
    expect(find.text('Could not load AI usage'), findsOneWidget);
    expect(find.text('admin only'), findsOneWidget);
  });
}
