import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:grazia_stones/core/services/supabase_service.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';

/// One row of `admin_ai_usage(p_since)` (supabase/migrations/20261031000000_ai_usage_events.sql).
/// userId null = signed-out Aarna guests (and deleted accounts).
class AdminAiUsageRow {
  const AdminAiUsageRow({
    this.userId,
    this.email,
    this.fullName,
    this.plan,
    this.renders = 0,
    this.chats = 0,
    this.promptTokens = 0,
    this.outputTokens = 0,
    this.totalTokens = 0,
    this.failed = 0,
    this.lastUsed,
  });

  final String? userId;
  final String? email;
  final String? fullName;
  final String? plan;
  final int renders;
  final int chats;
  final int promptTokens;
  final int outputTokens;
  final int totalTokens;
  final int failed;
  final DateTime? lastUsed;

  bool get isGuest => userId == null;

  factory AdminAiUsageRow.fromRow(Map<String, dynamic> r) {
    int toInt(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
    String? str(Object? v) => v is String && v.trim().isNotEmpty ? v : null;
    return AdminAiUsageRow(
      userId: str(r['user_id']),
      email: str(r['email']),
      fullName: str(r['full_name']),
      plan: str(r['plan']),
      renders: toInt(r['renders']),
      chats: toInt(r['chats']),
      promptTokens: toInt(r['prompt_tokens']),
      outputTokens: toInt(r['output_tokens']),
      totalTokens: toInt(r['total_tokens']),
      failed: toInt(r['failed']),
      lastUsed: r['last_used'] is String ? DateTime.tryParse(r['last_used'] as String) : null,
    );
  }

  static List<AdminAiUsageRow> parse(Object? data) => [
        for (final r in data is List ? data : const [])
          if (r is Map) AdminAiUsageRow.fromRow(Map<String, dynamic>.from(r)),
      ];
}

/// Loads usage since [since] (null = all time). Tests pass a fake.
typedef AdminAiUsageLoader = Future<List<AdminAiUsageRow>> Function(DateTime? since);

Future<List<AdminAiUsageRow>> _loadFromSupabase(DateTime? since) async {
  final db = SupabaseService.instance.clientOrNull;
  if (db == null) throw StateError('Not connected to the server.');
  final data = await db.rpc('admin_ai_usage', params: {'p_since': since?.toUtc().toIso8601String()});
  return AdminAiUsageRow.parse(data);
}

/// True when the RPC is missing on the server (migration not applied yet).
bool isMissingRpcError(Object e) =>
    e is PostgrestException &&
    (e.code == 'PGRST202' || e.code == '42883' || e.message.contains('Could not find the function'));

/// Admin: AI usage per account (renders, Aarna chats, Gemini tokens), heaviest first.
class AdminAiUsageScreen extends ConsumerStatefulWidget {
  const AdminAiUsageScreen({super.key, this.load = _loadFromSupabase});

  final AdminAiUsageLoader load;

  @override
  ConsumerState<AdminAiUsageScreen> createState() => _AdminAiUsageScreenState();
}

class _AdminAiUsageScreenState extends ConsumerState<AdminAiUsageScreen> {
  static const _periods = {'today': 'Today', '7d': '7 days', '30d': '30 days', 'all': 'All time'};
  final _num = NumberFormat.decimalPattern('en_IN');

  String _period = '7d';
  bool _loading = true;
  String? _error;
  bool _notEnabled = false;
  List<AdminAiUsageRow> _rows = const [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  DateTime? _since() {
    final now = DateTime.now();
    return switch (_period) {
      'today' => DateTime(now.year, now.month, now.day),
      '7d' => now.subtract(const Duration(days: 7)),
      '30d' => now.subtract(const Duration(days: 30)),
      _ => null,
    };
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
      _notEnabled = false;
    });
    try {
      final rows = await widget.load(_since());
      if (mounted) setState(() => _rows = rows);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _rows = const [];
        if (isMissingRpcError(e)) {
          _notEnabled = true;
        } else {
          _error = e is PostgrestException ? e.message : (e is StateError ? e.message : 'Could not load usage: $e');
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);
    final muted = GoogleFonts.inter(color: palette.textSecondary, fontSize: 14, height: 1.5);
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/admin/dashboard'),
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: palette.textPrimary, size: 18),
        ),
        title: Text('AI Usage',
            style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.w700, color: palette.textPrimary)),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh_rounded, color: palette.textPrimary),
            onPressed: _loading ? null : _fetch,
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: RefreshIndicator(
            onRefresh: _fetch,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in _periods.entries)
                      ChoiceChip(
                        label: Text(p.value),
                        selected: _period == p.key,
                        onSelected: _loading
                            ? null
                            : (_) {
                                setState(() => _period = p.key);
                                _fetch();
                              },
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                if (_loading) const LinearProgressIndicator(),
                if (_notEnabled)
                  _message(palette, Icons.cloud_off_rounded, 'Usage tracking is not enabled on the server yet.',
                      'The ai_usage_events migration has not been applied, so there is no usage to show.')
                else if (_error != null)
                  _message(palette, Icons.error_outline_rounded, 'Could not load AI usage', _error!, isError: true)
                else if (!_loading) ...[
                  _totals(palette),
                  const SizedBox(height: 16),
                  if (_rows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Text('No AI usage in this period.', textAlign: TextAlign.center, style: muted),
                    ),
                  for (final r in _rows) _userTile(palette, r),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _message(LuxuryPalette palette, IconData icon, String title, String body, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        children: [
          Icon(icon, size: 40, color: isError ? palette.error : palette.textSecondary),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: palette.textPrimary)),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, color: palette.textSecondary)),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: _fetch, child: const Text('Try again')),
        ],
      ),
    );
  }

  Widget _totals(LuxuryPalette palette) {
    int sum(int Function(AdminAiUsageRow) f) => _rows.fold(0, (a, r) => a + f(r));
    final stats = [
      ('Renders', sum((r) => r.renders)),
      ('Aarna chats', sum((r) => r.chats)),
      ('Tokens', sum((r) => r.totalTokens)),
      ('Active users', _rows.where((r) => !r.isGuest).length),
    ];
    return Row(
      children: [
        for (final (label, value) in stats)
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                children: [
                  FittedBox(
                    child: Text(_num.format(value),
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: palette.textPrimary)),
                  ),
                  const SizedBox(height: 2),
                  Text(label,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 11, color: palette.textSecondary)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _userTile(LuxuryPalette palette, AdminAiUsageRow r) {
    final title = r.isGuest ? 'Guests (signed out)' : (r.fullName ?? r.email ?? r.userId!);
    final subtitle = r.isGuest ? null : (r.fullName != null ? r.email : null);
    final line = GoogleFonts.inter(fontSize: 13, color: palette.textSecondary, height: 1.5);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: palette.textPrimary)),
              ),
              if (r.plan != null) _planBadge(palette, r.plan!),
            ],
          ),
          if (subtitle != null) Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: line),
          const SizedBox(height: 6),
          Text(
            '${_num.format(r.renders)} renders · ${_num.format(r.chats)} chats · ${_num.format(r.totalTokens)} tokens'
            '${r.failed > 0 ? ' · ${_num.format(r.failed)} failed' : ''}',
            style: line,
          ),
          Text(
            'Prompt ${_num.format(r.promptTokens)} / output ${_num.format(r.outputTokens)}'
            '${r.lastUsed != null ? ' · last used ${timeago.format(r.lastUsed!)}' : ''}',
            style: line,
          ),
        ],
      ),
    );
  }

  Widget _planBadge(LuxuryPalette palette, String plan) {
    final label = switch (plan) { 'trial' => 'Trial', 'plus' => 'Plus', 'pro' => 'Pro', _ => 'Free' };
    final paid = plan == 'plus' || plan == 'pro';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: paid ? palette.primary.withValues(alpha: 0.15) : palette.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: paid ? palette.primary : palette.border),
      ),
      child: Text(label,
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: paid ? palette.primary : palette.textSecondary)),
    );
  }
}
