import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:grazia_stones/core/constants/app_colors.dart';
import 'package:grazia_stones/core/providers/ai_usage_provider.dart';
import 'package:grazia_stones/core/services/billing_service.dart';
import 'package:grazia_stones/features/pro/presentation/grazia_pro_screen.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';

/// "Free trial · 4 days left · 3/10 today" pill for AI Studio. Tapping opens the paywall. Hidden for guests
/// and while the server has no plan data.
class AiUsageChip extends ConsumerWidget {
  const AiUsageChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = ref.watch(aiUsageProvider).valueOrNull;
    if (usage == null) return const SizedBox.shrink();
    final palette = ref.watch(themePaletteProvider);
    final warn = usage.exhausted;
    return Semantics(
      button: true,
      label: '${usage.chipLabel()}. See plans',
      child: Material(
        color: (warn ? palette.error : palette.primary).withValues(alpha: 0.1),
        shape: StadiumBorder(side: BorderSide(color: (warn ? palette.error : palette.primary).withValues(alpha: 0.35))),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () {
            HapticFeedback.selectionClick();
            openPaywall(context, plan: usage.plan == 'plus' ? 'pro' : null);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded, size: 14, color: warn ? palette.error : palette.primary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    usage.chipLabel(),
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: palette.textPrimary),
                  ),
                ),
                if (usage.plan != 'pro') ...[
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right_rounded, size: 16, color: palette.textSecondary),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Profile card: current plan, usage bar, Upgrade / Manage subscription.
class PlanUsageCard extends ConsumerWidget {
  const PlanUsageCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = ref.watch(aiUsageProvider).valueOrNull;
    if (usage == null) return const SizedBox.shrink();
    final palette = ref.watch(themePaletteProvider);
    final productId = usage.plan == 'pro' ? BillingService.proId : BillingService.plusId;
    final detail = usage.monthlyLimit != null
        ? '${usage.monthlyUsed} of ${usage.monthlyLimit} AI renders this month · ${usage.dailyUsed}/${usage.dailyLimit} today'
        : '${usage.dailyUsed} of ${usage.dailyLimit} AI renders today';
    final until = usage.isPaid && usage.periodEnd != null
        ? '${usage.isStoreSubscription ? 'Renews' : 'Active until'} ${_date(usage.periodEnd!.toLocal())}'
        : usage.isTrial
            ? '${usage.trialDaysLeft() ?? 0} trial days left'
            : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 18, color: palette.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  usage.isPaid ? 'Grazia ${usage.planLabel}' : 'AI Studio · ${usage.planLabel}',
                  style: GoogleFonts.playfairDisplay(
                      fontSize: 17, fontWeight: FontWeight.w700, color: palette.textPrimary),
                ),
              ),
              if (until != null)
                Text(until, style: GoogleFonts.inter(fontSize: 11.5, color: palette.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: usage.usedFraction,
              minHeight: 7,
              backgroundColor: palette.border,
              valueColor: AlwaysStoppedAnimation(usage.exhausted ? palette.error : AppColors.goldWarm),
            ),
          ),
          const SizedBox(height: 8),
          Text(detail, style: GoogleFonts.inter(fontSize: 12.5, color: palette.textSecondary)),
          const SizedBox(height: 12),
          Row(
            children: [
              if (usage.plan != 'pro')
                Expanded(
                  child: FilledButton(
                    onPressed: () => openPaywall(context, plan: usage.plan == 'plus' ? 'pro' : null),
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700),
                    ),
                    child: Text(usage.plan == 'plus' ? 'Upgrade to Pro' : 'Upgrade'),
                  ),
                ),
              if (usage.plan != 'pro' && usage.isStoreSubscription) const SizedBox(width: 10),
              if (usage.isStoreSubscription)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => launchUrl(BillingService.manageSubscriptionsUri(productId: productId),
                        mode: LaunchMode.externalApplication),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.textPrimary,
                      side: BorderSide(color: palette.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700),
                    ),
                    child: const Text('Manage subscription'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _date(DateTime d) => DateFormat('d MMM y').format(d);
}
