import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/services/supabase_service.dart';
import 'package:grazia_stones/core/widgets/error_handler_widget.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';

class AdminQuotesScreen extends ConsumerStatefulWidget {
  const AdminQuotesScreen({super.key});

  @override
  ConsumerState<AdminQuotesScreen> createState() => _AdminQuotesScreenState();
}

class _AdminQuotesScreenState extends ConsumerState<AdminQuotesScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _quotes = [];

  @override
  void initState() {
    super.initState();
    _loadQuotes();
  }

  Future<void> _loadQuotes() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final client = SupabaseService.instance.client;
      final data = await client
          .from('quote_requests')
          .select()
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _quotes = List<Map<String, dynamic>>.from(data);
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

  Future<void> _updateStatus(String quoteId, String status) async {
    try {
      final client = SupabaseService.instance.client;
      await client.from('quote_requests').update({'status': status}).eq('id', quoteId);

      if (mounted) {
        showSuccessSnackbar(context, 'Quote status updated');
        _loadQuotes();
      }
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    }
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
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: palette.textPrimary, size: 18),
        ),
        title: Text(
          'Architectural Quotes (${_quotes.length})',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
      ),
      body: _error != null
          ? ErrorHandlerWidget(error: Exception(_error), onRetry: _loadQuotes)
          : _isLoading
              ? Center(child: CircularProgressIndicator(color: palette.primary))
              : _quotes.isEmpty
                  ? Center(
                      child: Text('No quote requests yet', style: GoogleFonts.inter(color: palette.textSecondary)),
                    )
                  : RefreshIndicator(
                      color: palette.primary,
                      backgroundColor: palette.surface,
                      onRefresh: _loadQuotes,
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        itemCount: _quotes.length,
                        itemBuilder: (context, i) {
                          final q = _quotes[i];
                          final id = q['id']?.toString() ?? '';
                          final name = q['customer_name'] ?? q['name'] ?? 'Architect Inquirer';
                          final phone = q['customer_phone'] ?? q['phone'] ?? '';
                          final email = q['customer_email'] ?? q['email'] ?? '';
                          final area = q['area_sqft'] ?? q['sqft'] ?? '-';
                          final status = q['status'] ?? 'pending';
                          final notes = q['notes'] ?? q['message'] ?? 'No notes provided.';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: palette.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: palette.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      name,
                                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: palette.textPrimary, fontSize: 14),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: palette.primary.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        status.toString().toUpperCase(),
                                        style: TextStyle(color: palette.primary, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$phone • $email',
                                  style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 12),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Estimated Area: $area sq ft',
                                  style: GoogleFonts.inter(color: palette.primary, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Notes: $notes',
                                  style: GoogleFonts.inter(color: palette.textTertiary, fontSize: 11),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () => _updateStatus(id, 'contacted'),
                                      child: const Text('Mark Contacted', style: TextStyle(fontSize: 12)),
                                    ),
                                    TextButton(
                                      onPressed: () => _updateStatus(id, 'quoted'),
                                      child: const Text('Mark Quoted', style: TextStyle(fontSize: 12)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
