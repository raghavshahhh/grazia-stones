import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:grazia_stones/core/constants/app_colors.dart';
import 'package:grazia_stones/core/providers/ai_usage_provider.dart';
import 'package:grazia_stones/core/services/billing_service.dart';

/// Opens the AI Studio plans paywall. [reason] is shown on top (e.g. the 402 limit message).
void openPaywall(BuildContext context, {String? plan, String? reason}) {
  context.push(Uri(path: '/pro', queryParameters: {
    'plan': ?plan,
    'reason': ?reason,
  }).toString());
}

/// The plan copy lists only what a plan really changes: AI Room Studio render counts
/// (docs/subscriptions_contract.md). Everything else in the app is free for everyone.
const Map<String, List<String>> kPlanFeatures = {
  'plus': [
    'Everything in Free: catalogue, quotes, samples, Live AR and Aarna',
    '60 AI room renders a month',
    'Up to 10 renders a day',
  ],
  'pro': [
    'Everything in Plus',
    '200 AI renders a month (3x Plus)',
    'Up to 25 a day',
  ],
};

/// AI Studio plans paywall: Plus | Pro, store price, restore, legal links.
class GraziaProScreen extends ConsumerStatefulWidget {
  const GraziaProScreen({super.key, this.initialPlan = 'pro', this.reason});

  /// 'plus' or 'pro'.
  final String initialPlan;
  final String? reason;

  @override
  ConsumerState<GraziaProScreen> createState() => _GraziaProScreenState();
}

class _GraziaProScreenState extends ConsumerState<GraziaProScreen> with SingleTickerProviderStateMixin {
  static const _bg = Color(0xFF0F0E0C);
  static const _card = Color(0xFF1A1816);
  static const _line = Color(0xFF2C2925);

  late String _plan = widget.initialPlan == 'plus' ? 'plus' : 'pro';
  late final AnimationController _intro =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  bool _introStarted = false;

  String get _productId => _plan == 'pro' ? BillingService.proId : BillingService.plusId;
  String get _planName => _plan == 'pro' ? 'Pro' : 'Plus';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final billing = ref.read(billingProvider);
      billing.clearMessage();
      billing.loadProducts();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_introStarted) return;
    _introStarted = true;
    if (MediaQuery.of(context).disableAnimations) {
      _intro.value = 1;
    } else {
      _intro.forward();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  /// Staggered fade + slide for entrance item [i].
  Widget _enter(int i, Widget child) {
    final start = (i * 0.1).clamp(0.0, 0.6);
    final anim = CurvedAnimation(parent: _intro, curve: Interval(start, start + 0.4, curve: Curves.easeOutCubic));
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(anim),
        child: child,
      ),
    );
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  void _signIn() {
    final back = Uri(path: '/pro', queryParameters: {'plan': _plan}).toString();
    context.push('/login?redirect=${Uri.encodeComponent(back)}');
  }

  Future<void> _buy(BillingService billing) async {
    HapticFeedback.mediumImpact();
    if (!await billing.buy(_productId)) _signIn();
  }

  Future<void> _restore(BillingService billing) async {
    HapticFeedback.selectionClick();
    if (!await billing.restore()) _signIn();
  }

  Future<void> _manage() async {
    await launchUrl(BillingService.manageSubscriptionsUri(productId: _productId), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final billing = ref.watch(billingProvider);
    final usage = ref.watch(aiUsageProvider).valueOrNull;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final switchDuration = reduceMotion ? Duration.zero : const Duration(milliseconds: 280);
    final heroHeight = (MediaQuery.of(context).size.height * 0.34).clamp(220.0, 340.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _hero(heroHeight),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _enter(0, _title(switchDuration)),
                            if (widget.reason != null) ...[
                              const SizedBox(height: 14),
                              _enter(1, _reasonBanner(widget.reason!)),
                            ],
                            if (usage != null) ...[
                              const SizedBox(height: 12),
                              _enter(1, _currentPlanLine(usage)),
                            ],
                            const SizedBox(height: 22),
                            _enter(2, _switch(switchDuration)),
                            const SizedBox(height: 16),
                            _enter(3, _features(switchDuration)),
                            const SizedBox(height: 22),
                            _enter(4, _cta(billing, usage)),
                            _enter(5, _footer(billing, usage)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 12,
              child: Material(
                color: Colors.black.withValues(alpha: 0.45),
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                  onPressed: _close,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero(double height) {
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/hero_luxury_fireplace.jpg', fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.55, 1.0],
                colors: [Color(0x33000000), Color(0x660F0E0C), _bg],
              ),
            ),
          ),
          Positioned(
            left: 22,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.goldLight.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome_rounded, size: 13, color: AppColors.goldLight),
                  const SizedBox(width: 6),
                  Text('AI ROOM STUDIO',
                      style: GoogleFonts.inter(
                          fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.6, color: AppColors.goldLight)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _title(Duration d) {
    return AnimatedSwitcher(
      duration: d,
      child: Column(
        key: ValueKey(_plan),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Grazia $_planName',
              style: GoogleFonts.playfairDisplay(
                  fontSize: 36, fontWeight: FontWeight.w700, color: Colors.white, height: 1.1)),
          const SizedBox(height: 8),
          Text(
            _plan == 'pro'
                ? 'The most AI room renders, for designers working on many projects.'
                : 'More AI room renders every month to try stones on your own walls.',
            style: GoogleFonts.inter(fontSize: 14.5, height: 1.45, color: Colors.white.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  Widget _reasonBanner(String reason) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.goldWarm.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.goldWarm.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.goldLight, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(reason, style: GoogleFonts.inter(fontSize: 13, height: 1.4, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _currentPlanLine(AiUsage usage) {
    return Text(
      'Your plan: ${usage.chipLabel()}',
      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.goldLight),
    );
  }

  Widget _switch(Duration d) {
    return LayoutBuilder(builder: (context, c) {
      return Container(
        height: 48,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: _line),
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: d,
              curve: Curves.easeOutCubic,
              alignment: _plan == 'plus' ? Alignment.centerLeft : Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppColors.goldGradient,
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (final p in const ['plus', 'pro'])
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: _plan == p,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(26),
                        onTap: () {
                          if (_plan == p) return;
                          HapticFeedback.selectionClick();
                          setState(() => _plan = p);
                        },
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: d,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _plan == p ? AppColors.black : Colors.white.withValues(alpha: 0.7),
                            ),
                            child: Text(p == 'plus' ? 'Plus' : 'Pro'),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _features(Duration d) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _line),
      ),
      child: AnimatedSize(
        duration: d,
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: d,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topLeft,
            children: [...previous, ?current],
          ),
          child: Column(
            key: ValueKey(_plan),
            children: [
              for (final f in kPlanFeatures[_plan]!)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: AppColors.goldWarm.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded, size: 15, color: AppColors.goldLight),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(f,
                            style: GoogleFonts.inter(fontSize: 14.5, height: 1.45, color: Colors.white)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cta(BillingService billing, AiUsage? usage) {
    final product = billing.products[_productId];
    final onThisPlan = usage?.plan == _plan;
    final loading = billing.phase == BillingPhase.loading && product == null;

    String label;
    VoidCallback? onTap;
    if (billing.phase == BillingPhase.success) {
      label = 'Continue';
      onTap = _close;
    } else if (!BillingService.supported) {
      label = 'Available in the Android and iPhone app';
    } else if (loading) {
      label = 'Loading plans...';
    } else if (billing.storeAvailable == false) {
      label = '${BillingService.storeName} is not available';
    } else if (product == null) {
      label = 'Plans are not available yet';
    } else if (onThisPlan) {
      label = 'You are on Grazia $_planName';
    } else if (!billing.signedIn) {
      label = 'Sign in to get Grazia $_planName';
      onTap = _signIn;
    } else {
      label = 'Get Grazia $_planName';
      onTap = billing.busy ? null : () => _buy(billing);
    }
    final working = billing.busy || billing.phase == BillingPhase.pending;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Opacity(
          opacity: onTap == null && !working ? 0.5 : 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppColors.goldGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: AppColors.goldWarm.withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 6)),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onTap,
                child: SizedBox(
                  height: 56,
                  child: Center(
                    child: working && billing.phase != BillingPhase.loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.black))
                        : Text(label,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                                fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.black)),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (product != null)
          Text(
            '${product.price}/month. Auto-renews monthly. Cancel anytime in ${BillingService.storeName}.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)),
          ),
        if (!BillingService.supported)
          Text(
            'Subscriptions are sold through Google Play and the App Store.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)),
          ),
        if (billing.message != null) ...[
          const SizedBox(height: 10),
          Text(
            billing.message!,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: switch (billing.phase) {
                BillingPhase.success => AppColors.success,
                BillingPhase.error => const Color(0xFFFF8A80),
                _ => Colors.white.withValues(alpha: 0.85),
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _footer(BillingService billing, AiUsage? usage) {
    final link = GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.7));
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          if (BillingService.supported)
            TextButton(
              onPressed: billing.busy ? null : () => _restore(billing),
              child: Text('Restore purchases', style: link.copyWith(color: AppColors.goldLight)),
            ),
          if (usage != null && usage.isStoreSubscription)
            TextButton(onPressed: _manage, child: Text('Manage subscription', style: link)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(onPressed: () => context.push('/terms'), child: Text('Terms', style: link)),
              Text('·', style: link),
              TextButton(onPressed: () => context.push('/privacy'), child: Text('Privacy', style: link)),
            ],
          ),
        ],
      ),
    );
  }
}
