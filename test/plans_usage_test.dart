import 'package:flutter_test/flutter_test.dart';
import 'package:grazia_stones/core/providers/ai_usage_provider.dart';
import 'package:grazia_stones/features/admin/presentation/admin_plans_screen.dart';

void main() {
  final now = DateTime.utc(2026, 10, 30, 12);

  test('parses the ai-quota response and labels a trial', () {
    final u = AiUsage.fromJson({
      'plan': 'trial',
      'trialEndsAt': now.add(const Duration(days: 3, hours: 2)).toIso8601String(),
      'monthlyLimit': null,
      'monthlyUsed': 5,
      'dailyLimit': 10,
      'dailyUsed': 3,
      'creditsRemaining': 7, // old key, ignored
    });
    expect(u.trialDaysLeft(now), 4);
    expect(u.chipLabel(now), 'Free trial · 4 days left · 3/10 today');
    expect(u.usedFraction, closeTo(0.3, 1e-9));
    expect(u.exhausted, isFalse);
  });

  test('paid plan label and snake_case keys from SQL', () {
    final u = AiUsage.fromJson({'plan': 'plus', 'source': 'google_play', 'monthly_limit': 60, 'monthly_used': 12, 'daily_limit': 10, 'daily_used': 10});
    expect(u.chipLabel(), 'Plus · 12 of 60 this month');
    expect(u.isStoreSubscription, isTrue);
    expect(u.exhausted, isTrue);
  });

  test('402 reason uses the server usage', () {
    final body = {
      'code': 'monthly_limit',
      'error': 'limit',
      'usage': {'plan': 'free', 'monthlyLimit': 3, 'monthlyUsed': 3, 'dailyLimit': 3, 'dailyUsed': 1},
    };
    expect(limitReachedMessage(body), 'You have used all 3 AI renders on Free this month.');
    expect(limitReachedUsage(body)!.plan, 'free');
    expect(limitReachedMessage({'code': 'daily_limit'}), contains("today's AI render limit"));
  });

  test('admin_find_user rows: nested or flattened usage', () {
    final nested = AdminPlanUser.parse([
      {'id': 'u1', 'email': 'a@b.com', 'created_at': '2026-10-01T00:00:00Z', 'usage': {'plan': 'pro', 'monthly_limit': 200, 'daily_limit': 25}},
    ]);
    expect(nested.single.usage!.plan, 'pro');
    final flat = AdminPlanUser.parse({'id': 'u2', 'email': 'c@d.com', 'plan': 'free', 'daily_limit': 3});
    expect(flat.single.usage!.dailyLimit, 3);
    expect(AdminPlanUser.parse(null), isEmpty);
  });
}
