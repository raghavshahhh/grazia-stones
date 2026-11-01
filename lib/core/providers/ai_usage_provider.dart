import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di.dart';
import '../services/ai_endpoint_client.dart';
import '../services/billing_service.dart';

/// AI Studio plan usage from `POST /api/ai-quota` (docs/subscriptions_contract.md).
class AiUsage {
  const AiUsage({
    required this.plan,
    this.source,
    this.periodEnd,
    this.trialEndsAt,
    this.monthlyLimit,
    this.monthlyUsed = 0,
    required this.dailyLimit,
    this.dailyUsed = 0,
    this.resetsAt,
  });

  /// 'trial' | 'free' | 'plus' | 'pro'
  final String plan;

  /// 'google_play' | 'app_store' | 'admin' | null
  final String? source;
  final DateTime? periodEnd;
  final DateTime? trialEndsAt;

  /// null = no monthly cap (trial).
  final int? monthlyLimit;
  final int monthlyUsed;
  final int dailyLimit;
  final int dailyUsed;
  final DateTime? resetsAt;

  factory AiUsage.fromJson(Map<String, dynamic> j) {
    int toInt(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    DateTime? toDate(Object? v) => v is String ? DateTime.tryParse(v) : null;
    // camelCase from the Vercel API, snake_case straight from the SQL functions (admin RPCs).
    Object? v(String camel, String snake) => j[camel] ?? j[snake];
    return AiUsage(
      plan: (j['plan'] as String?) ?? 'free',
      source: j['source'] as String?,
      periodEnd: toDate(v('periodEnd', 'period_end')),
      trialEndsAt: toDate(v('trialEndsAt', 'trial_ends_at')),
      monthlyLimit: v('monthlyLimit', 'monthly_limit') == null ? null : toInt(v('monthlyLimit', 'monthly_limit')),
      monthlyUsed: toInt(v('monthlyUsed', 'monthly_used')),
      dailyLimit: toInt(v('dailyLimit', 'daily_limit')),
      dailyUsed: toInt(v('dailyUsed', 'daily_used')),
      resetsAt: toDate(v('resetsAt', 'resets_at')),
    );
  }

  bool get isPaid => plan == 'plus' || plan == 'pro';
  bool get isTrial => plan == 'trial';
  bool get isStoreSubscription => source == 'google_play' || source == 'app_store';

  String get planLabel => switch (plan) {
        'trial' => 'Free trial',
        'plus' => 'Plus',
        'pro' => 'Pro',
        _ => 'Free',
      };

  /// Whole days left in the trial, rounded up (so the last day reads "1 day left").
  int? trialDaysLeft([DateTime? now]) {
    if (!isTrial || trialEndsAt == null) return null;
    final left = trialEndsAt!.difference(now ?? DateTime.now());
    if (left.isNegative) return 0;
    return (left.inMinutes / (60 * 24)).ceil();
  }

  /// Share of the governing limit used (monthly, or daily when there is no monthly cap). 0..1.
  double get usedFraction {
    final limit = monthlyLimit ?? dailyLimit;
    final used = monthlyLimit != null ? monthlyUsed : dailyUsed;
    if (limit <= 0) return 1;
    return (used / limit).clamp(0, 1).toDouble();
  }

  bool get exhausted =>
      dailyUsed >= dailyLimit || (monthlyLimit != null && monthlyUsed >= monthlyLimit!);

  /// "Free trial · 4 days left · 3/10 today" / "Plus · 12 of 60 this month".
  String chipLabel([DateTime? now]) {
    if (isTrial) {
      final d = trialDaysLeft(now) ?? 0;
      return 'Free trial · $d ${d == 1 ? 'day' : 'days'} left · $dailyUsed/$dailyLimit today';
    }
    if (monthlyLimit != null) return '$planLabel · $monthlyUsed of $monthlyLimit this month';
    return '$planLabel · $dailyUsed/$dailyLimit today';
  }
}

/// Null for guests. Refresh with `ref.invalidate(aiUsageProvider)` after a render; purchases refresh it
/// automatically through [BillingService.entitlementChanged].
final aiUsageProvider = FutureProvider<AiUsage?>((ref) async {
  final userId = ref.watch(authRiverpodProvider.select((s) => s.isLoggedIn ? s.userId : null));
  final tick = BillingService.entitlementChanged;
  void refresh() => ref.invalidateSelf();
  tick.addListener(refresh);
  ref.onDispose(() => tick.removeListener(refresh));
  if (userId == null) return null;
  final data = await AIEndpointClient.post('/api/ai-quota', const {});
  // Old server builds answer without `plan`; show nothing rather than a made-up plan.
  if (data['plan'] is! String) return null;
  return AiUsage.fromJson(data);
});

/// User-facing reason for a 402 `{code: 'daily_limit'|'monthly_limit', usage: {...}}` from generate-visualization.
String limitReachedMessage(Object? body) {
  final usage = limitReachedUsage(body);
  final plan = usage?.planLabel;
  if (body is Map && body['code'] == 'monthly_limit') {
    return usage?.monthlyLimit != null
        ? 'You have used all ${usage!.monthlyLimit} AI renders on $plan this month.'
        : 'You have used all your AI renders for this month.';
  }
  return usage != null
      ? "You have used today's ${usage.dailyLimit} AI renders on $plan. More tomorrow, or upgrade for a higher limit."
      : "You have reached today's AI render limit. Please try again tomorrow.";
}

AiUsage? limitReachedUsage(Object? body) {
  final u = body is Map ? body['usage'] : null;
  return u is Map && u['plan'] is String ? AiUsage.fromJson(Map<String, dynamic>.from(u)) : null;
}
