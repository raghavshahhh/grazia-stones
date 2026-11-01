import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:grazia_stones/core/providers/ai_usage_provider.dart';
import 'package:grazia_stones/core/services/supabase_service.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';

/// One row of `admin_find_user(p_email)`: id, email, created_at, usage (nested or flattened).
class AdminPlanUser {
  AdminPlanUser({required this.id, required this.email, this.createdAt, this.usage});

  final String id;
  final String email;
  final DateTime? createdAt;
  final AiUsage? usage;

  factory AdminPlanUser.fromRow(Map<String, dynamic> r) {
    final nested = r['usage'];
    final usageMap = nested is Map ? Map<String, dynamic>.from(nested) : (r['plan'] is String ? r : null);
    return AdminPlanUser(
      id: '${r['id'] ?? r['user_id']}',
      email: '${r['email'] ?? ''}',
      createdAt: r['created_at'] is String ? DateTime.tryParse(r['created_at'] as String) : null,
      usage: usageMap == null ? null : AiUsage.fromJson(usageMap),
    );
  }

  static List<AdminPlanUser> parse(Object? data) {
    final rows = data is List ? data : (data is Map ? [data] : const []);
    return [for (final r in rows) if (r is Map) AdminPlanUser.fromRow(Map<String, dynamic>.from(r))];
  }
}

/// Admin: find a user by email, see AI usage, grant Plus/Pro for N days, or revoke (admin_set_plan).
class AdminPlansScreen extends ConsumerStatefulWidget {
  const AdminPlansScreen({super.key});

  @override
  ConsumerState<AdminPlansScreen> createState() => _AdminPlansScreenState();
}

class _AdminPlansScreenState extends ConsumerState<AdminPlansScreen> {
  final _email = TextEditingController();
  bool _loading = false;
  String? _error;
  List<AdminPlanUser>? _results;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  SupabaseClient? get _db => SupabaseService.instance.clientOrNull;

  Future<void> _search() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'Enter the full email address.');
      return;
    }
    final db = _db;
    if (db == null) return setState(() => _error = 'Not connected to the server.');
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await db.rpc('admin_find_user', params: {'p_email': email});
      setState(() => _results = AdminPlanUser.parse(data));
    } on PostgrestException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Search failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setPlan(AdminPlanUser user, String plan, int days, String note) async {
    final db = _db;
    if (db == null) return;
    setState(() => _loading = true);
    try {
      await db.rpc('admin_set_plan', params: {
        'p_user': user.id,
        'p_plan': plan,
        'p_days': days,
        'p_note': note.isEmpty ? null : note,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(plan == 'free' ? 'Plan revoked for ${user.email}' : 'Granted ${plan == 'pro' ? 'Pro' : 'Plus'} for $days days to ${user.email}'),
      ));
      await _search();
    } on PostgrestException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Update failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _grantDialog(AdminPlanUser user, String plan) async {
    final palette = ref.read(themePaletteProvider);
    final note = TextEditingController();
    int days = 30;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: palette.surface,
          title: Text('Grant ${plan == 'pro' ? 'Pro' : 'Plus'}?', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.email, style: GoogleFonts.inter(fontSize: 13, color: palette.textSecondary)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                children: [
                  for (final d in const [7, 30, 90, 365])
                    ChoiceChip(label: Text('$d days'), selected: days == d, onSelected: (_) => setD(() => days = d)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Note (optional)', hintText: 'e.g. IHGF fair visitor'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Grant')),
          ],
        ),
      ),
    );
    final text = note.text.trim();
    note.dispose();
    if (ok == true) await _setPlan(user, plan, days, text);
  }

  Future<void> _revokeDialog(AdminPlanUser user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke plan?'),
        content: Text(
          '${user.email} goes back to the free plan now. A Google Play / App Store subscription keeps billing '
          'until the user cancels it in the store.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (ok == true) await _setPlan(user, 'free', 0, 'revoked');
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);
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
        title: Text('AI Studio Plans',
            style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.w700, color: palette.textPrimary)),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
            children: [
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  hintText: 'Find user by email',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward_rounded), onPressed: _loading ? null : _search),
                  filled: true,
                  fillColor: palette.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: palette.border)),
                ),
              ),
              if (_loading) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, style: GoogleFonts.inter(color: palette.error, fontSize: 13)),
                ),
              if (_results != null && _results!.isEmpty && !_loading)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Text('No user with that email.',
                      textAlign: TextAlign.center, style: GoogleFonts.inter(color: palette.textSecondary)),
                ),
              for (final u in _results ?? const <AdminPlanUser>[]) _userCard(u),
            ],
          ),
        ),
      ),
    );
  }

  Widget _userCard(AdminPlanUser u) {
    final palette = ref.watch(themePaletteProvider);
    final usage = u.usage;
    final fmt = DateFormat('d MMM y');
    final line = GoogleFonts.inter(fontSize: 13, color: palette.textSecondary, height: 1.5);
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(u.email, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: palette.textPrimary)),
          if (u.createdAt != null) Text('Joined ${fmt.format(u.createdAt!.toLocal())}', style: line),
          const SizedBox(height: 8),
          if (usage == null)
            Text('No usage data', style: line)
          else ...[
            Text('Plan: ${usage.planLabel}${usage.source != null ? ' (${usage.source})' : ''}', style: line),
            if (usage.periodEnd != null && usage.isPaid) Text('Until ${fmt.format(usage.periodEnd!.toLocal())}', style: line),
            if (usage.isTrial) Text('Trial: ${usage.trialDaysLeft() ?? 0} days left', style: line),
            Text(
              usage.monthlyLimit != null
                  ? 'This month: ${usage.monthlyUsed} of ${usage.monthlyLimit} · Today: ${usage.dailyUsed}/${usage.dailyLimit}'
                  : 'Today: ${usage.dailyUsed}/${usage.dailyLimit}',
              style: line,
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(onPressed: _loading ? null : () => _grantDialog(u, 'plus'), child: const Text('Grant Plus')),
              FilledButton.tonal(onPressed: _loading ? null : () => _grantDialog(u, 'pro'), child: const Text('Grant Pro')),
              if (usage?.isPaid ?? false)
                OutlinedButton(
                  onPressed: _loading ? null : () => _revokeDialog(u),
                  style: OutlinedButton.styleFrom(foregroundColor: palette.error),
                  child: const Text('Revoke'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
