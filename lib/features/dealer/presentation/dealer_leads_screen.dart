import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grazia_stones/core/services/supabase_service.dart';
import 'package:grazia_stones/core/widgets/error_handler_widget.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/shared/widgets/luxury_toast.dart';
import 'package:url_launcher/url_launcher.dart';

/// The dealer note embedded as `quote_dealer_notes(notes)`: PostgREST returns it as an object (one-to-one) or,
/// on older versions, a one-item list.
String dealerNotesOf(Map<String, dynamic> quote) {
  final embedded = quote['quote_dealer_notes'];
  final row = embedded is List ? (embedded.isEmpty ? null : embedded.first) : embedded;
  return row is Map ? (row['notes']?.toString() ?? '') : '';
}

/// Dealer panel: the quote requests an admin assigned to this dealer. RLS returns only those rows and a
/// trigger lets the dealer change just the status and their own notes (migration 20261107000000).
class DealerLeadsScreen extends ConsumerStatefulWidget {
  const DealerLeadsScreen({super.key});

  @override
  ConsumerState<DealerLeadsScreen> createState() => _DealerLeadsScreenState();
}

class _DealerLeadsScreenState extends ConsumerState<DealerLeadsScreen> {
  static const _statuses = ['pending', 'contacted', 'quoted', 'closed'];

  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _leads = [];
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = ref.read(authRiverpodProvider).userId;
    if (uid == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await SupabaseService.instance.client
          .from('quote_requests')
          .select('*, quote_dealer_notes(notes)')
          .eq('assigned_dealer', uid)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _leads = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _update(String id, Map<String, dynamic> fields, String done) async {
    try {
      await SupabaseService.instance.client.from('quote_requests').update(fields).eq('id', id);
      if (mounted) {
        LuxuryToast.show(context, message: done);
        _load();
      }
    } catch (e) {
      if (mounted) LuxuryToast.show(context, message: e.toString(), isError: true);
    }
  }

  // Notes live in quote_dealer_notes so the customer, who can read their own quote row, never sees them.
  static String _notesOf(Map<String, dynamic> lead) => dealerNotesOf(lead);

  Future<void> _saveNotes(String quoteId, String notes) async {
    try {
      await SupabaseService.instance.client.from('quote_dealer_notes').upsert({
        'quote_id': quoteId,
        'dealer_id': ref.read(authRiverpodProvider).userId,
        'notes': notes,
        'updated_at': DateTime.now().toIso8601String(),
      });
      if (mounted) {
        LuxuryToast.show(context, message: 'Notes saved');
        _load();
      }
    } catch (e) {
      if (mounted) LuxuryToast.show(context, message: e.toString(), isError: true);
    }
  }

  void _editNotes(Map<String, dynamic> lead, LuxuryPalette palette) {
    final controller = TextEditingController(text: _notesOf(lead));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        title: Text('My notes (only you and Grazia see these)', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700, color: palette.textPrimary)),
        content: TextField(
          controller: controller,
          maxLines: 4,
          maxLength: 5000,
          style: TextStyle(color: palette.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'e.g. Site visit on Monday, quoted 1200 sqft',
            hintStyle: TextStyle(color: palette.textTertiary, fontSize: 12),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: palette.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: palette.primary, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _saveNotes(lead['id'].toString(), controller.text.trim());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _open(Uri url) async {
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication) && mounted) {
        LuxuryToast.show(context, message: 'Could not open ${url.scheme == 'tel' ? 'the dialer' : 'WhatsApp'}', isError: true);
      }
    } catch (_) {
      if (mounted) LuxuryToast.show(context, message: 'Could not open the app', isError: true);
    }
  }

  void _whatsApp(String phone, String name, String stone) {
    var digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 10) digits = '91$digits';
    final about = stone.isEmpty ? '' : ' about $stone';
    final text = 'Hello $name, this is your Grazia Stones dealer following up on your enquiry$about.';
    _open(Uri.parse('https://wa.me/$digits?text=${Uri.encodeComponent(text)}'));
  }

  Color _statusColor(String status) => switch (status) {
        'quoted' => Colors.green,
        'contacted' => Colors.blue,
        'closed' => Colors.red,
        _ => Colors.orange,
      };

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);
    final isDealer = ref.watch(authRiverpodProvider.select((s) => s.isDealer || s.isAdmin));
    final shown = _statusFilter == 'all' ? _leads : _leads.where((l) => l['status'] == _statusFilter).toList();

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/profile'),
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: palette.textPrimary, size: 18),
        ),
        title: Text('Dealer Panel', style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.w700, color: palette.textPrimary)),
        actions: [
          IconButton(onPressed: _load, icon: Icon(Icons.refresh_rounded, color: palette.primary), tooltip: 'Refresh'),
        ],
      ),
      body: !isDealer
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'This panel is for Grazia Stones dealers. Ask the Grazia team to enable dealer access on your account.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: palette.textSecondary),
                ),
              ),
            )
          : _error != null
              ? ErrorHandlerWidget(error: Exception(_error), onRetry: _load)
              : _isLoading
                  ? Center(child: CircularProgressIndicator(color: palette.primary))
                  : Column(
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          child: Row(
                            children: ['all', ..._statuses].map((s) {
                              final count = s == 'all' ? _leads.length : _leads.where((l) => l['status'] == s).length;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text('${s[0].toUpperCase()}${s.substring(1)} ($count)'),
                                  selected: _statusFilter == s,
                                  onSelected: (_) {
                                    HapticFeedback.selectionClick();
                                    setState(() => _statusFilter = s);
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        Expanded(
                          child: RefreshIndicator(
                            color: palette.primary,
                            onRefresh: _load,
                            child: shown.isEmpty
                                ? ListView(
                                    children: [
                                      const SizedBox(height: 120),
                                      Text(
                                        _leads.isEmpty
                                            ? 'No leads assigned to you yet.\nNew enquiries appear here when the Grazia team assigns them.'
                                            : 'No leads with this status.',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.inter(color: palette.textSecondary),
                                      ),
                                    ],
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                    itemCount: shown.length,
                                    itemBuilder: (context, i) => _leadCard(shown[i], palette),
                                  ),
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _leadCard(Map<String, dynamic> lead, LuxuryPalette palette) {
    final id = lead['id'].toString();
    final name = lead['name']?.toString() ?? 'Customer';
    final phone = lead['phone']?.toString() ?? '';
    final stone = lead['stone_name']?.toString() ?? '';
    final status = _statuses.contains(lead['status']) ? lead['status'] as String : 'pending';
    final area = lead['area_sqft'];
    final message = lead['message']?.toString() ?? '';
    final notes = _notesOf(lead);
    final created = DateTime.tryParse(lead['created_at']?.toString() ?? '')?.toLocal();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
                child: Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700, fontSize: 15, color: palette.textPrimary)),
              ),
              if (created != null)
                Text('${created.day}/${created.month}/${created.year}', style: GoogleFonts.inter(fontSize: 11, color: palette.textTertiary)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [if (stone.isNotEmpty) stone, if (area != null) '$area sq ft'].join(' • '),
            style: GoogleFonts.inter(fontSize: 12, color: palette.primary, fontWeight: FontWeight.w600),
          ),
          if (phone.isNotEmpty) Text(phone, style: GoogleFonts.inter(fontSize: 12, color: palette.textSecondary)),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('“$message”', style: GoogleFonts.inter(fontSize: 11, fontStyle: FontStyle.italic, color: palette.textTertiary)),
          ],
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('My notes: $notes', style: GoogleFonts.inter(fontSize: 11, color: palette.primary, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: status,
                    dropdownColor: palette.surface,
                    items: _statuses
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(s.toUpperCase(),
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _statusColor(s))),
                            ))
                        .toList(),
                    onChanged: (s) {
                      if (s != null && s != status) _update(id, {'status': s}, 'Marked as ${s.toUpperCase()}');
                    },
                  ),
                ),
              ),
              const Spacer(),
              if (phone.isNotEmpty) ...[
                IconButton(
                  tooltip: 'WhatsApp',
                  icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.green, size: 19),
                  onPressed: () => _whatsApp(phone, name, stone),
                ),
                IconButton(
                  tooltip: 'Call',
                  icon: Icon(Icons.phone_outlined, color: palette.primary, size: 19),
                  onPressed: () => _open(Uri.parse('tel:${phone.replaceAll(RegExp(r'[^0-9+]'), '')}')),
                ),
              ],
              IconButton(
                tooltip: 'My notes',
                icon: Icon(notes.isEmpty ? Icons.note_add_outlined : Icons.edit_note_rounded, color: palette.primary, size: 20),
                onPressed: () => _editNotes(lead, palette),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
