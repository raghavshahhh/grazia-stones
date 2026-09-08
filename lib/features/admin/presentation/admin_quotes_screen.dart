import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/services/supabase_service.dart';
import 'package:grazia_stones/core/widgets/error_handler_widget.dart';
import 'package:grazia_stones/features/admin/presentation/widgets/admin_module_switcher.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/shared/widgets/luxury_toast.dart';

class AdminQuotesScreen extends ConsumerStatefulWidget {
  final String? initialStatus;
  const AdminQuotesScreen({super.key, this.initialStatus});

  @override
  ConsumerState<AdminQuotesScreen> createState() => _AdminQuotesScreenState();
}

class _AdminQuotesScreenState extends ConsumerState<AdminQuotesScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _quotes = [];
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _statusFilter = widget.initialStatus ?? 'all';
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
      await client.from('quote_requests').update({
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', quoteId);

      if (mounted) {
        LuxuryToast.show(context, message: 'Quote marked as ${status.toUpperCase()}');
        _loadQuotes();
      }
    } catch (e) {
      if (mounted) LuxuryToast.show(context, message: e.toString(), isError: true);
    }
  }

  Widget _buildFilterChip(String label, String value, LuxuryPalette palette) {
    final isSelected = _statusFilter == value;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _statusFilter = value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? palette.primary : palette.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? palette.primary : palette.border,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : palette.textSecondary,
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'quoted':
      case 'completed':
        return Colors.green;
      case 'contacted':
        return Colors.blue;
      case 'closed':
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);

    final filteredQuotes = _quotes.where((q) {
      if (_statusFilter == 'all') return true;
      return (q['status'] ?? '').toString().toLowerCase() == _statusFilter.toLowerCase();
    }).toList();

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/admin/dashboard');
            }
          },
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
        actions: [
          IconButton(
            tooltip: 'Refresh Quotes',
            onPressed: () {
              HapticFeedback.lightImpact();
              _loadQuotes();
            },
            icon: Icon(Icons.refresh_rounded, color: palette.primary),
          ),
          AdminQuickNavButton(
            currentRoute: '/admin/quotes',
            palette: palette,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _error != null
          ? ErrorHandlerWidget(error: Exception(_error), onRetry: _loadQuotes)
          : _isLoading
              ? Center(child: CircularProgressIndicator(color: palette.primary))
              : Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: Column(
                  children: [
                    // Horizontal status filter chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      child: Row(
                        children: [
                          _buildFilterChip('All (${_quotes.length})', 'all', palette),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'Pending (${_quotes.where((q) => (q['status'] ?? 'pending').toString().toLowerCase() == 'pending').length})',
                            'pending',
                            palette,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'Contacted (${_quotes.where((q) => (q['status'] ?? '').toString().toLowerCase() == 'contacted').length})',
                            'contacted',
                            palette,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'Quoted (${_quotes.where((q) => (q['status'] ?? '').toString().toLowerCase() == 'quoted').length})',
                            'quoted',
                            palette,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'Closed (${_quotes.where((q) => ['closed', 'cancelled'].contains((q['status'] ?? '').toString().toLowerCase())).length})',
                            'closed',
                            palette,
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: filteredQuotes.isEmpty
                          ? Center(
                              child: Text(
                                _statusFilter == 'all'
                                    ? 'No quote requests yet'
                                    : 'No quotes with status "$_statusFilter"',
                                style: GoogleFonts.inter(color: palette.textSecondary),
                              ),
                            )
                          : RefreshIndicator(
                              color: palette.primary,
                              backgroundColor: palette.surface,
                              onRefresh: _loadQuotes,
                              child: ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                itemCount: filteredQuotes.length,
                                itemBuilder: (context, i) {
                                  final q = filteredQuotes[i];
                                  final id = q['id']?.toString() ?? '';
                                  final name = q['customer_name'] ?? q['name'] ?? 'Architect Inquirer';
                                  final phone = q['customer_phone'] ?? q['phone'] ?? '';
                                  final email = q['customer_email'] ?? q['email'] ?? '';
                                  final area = q['area_sqft'] ?? q['sqft'] ?? '-';
                                  final status = q['status']?.toString().toLowerCase() ?? 'pending';
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
                                            Expanded(
                                              child: Text(
                                                name,
                                                style: GoogleFonts.playfairDisplay(
                                                  fontWeight: FontWeight.w700,
                                                  color: palette.textPrimary,
                                                  fontSize: 15,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: _statusColor(status).withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                status.toUpperCase(),
                                                style: GoogleFonts.inter(
                                                  color: _statusColor(status),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        if (phone.isNotEmpty || email.isNotEmpty)
                                          Text(
                                            [phone, email].where((s) => s.isNotEmpty).join(' • '),
                                            style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 12),
                                          ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Estimated Area: $area sq ft',
                                          style: GoogleFonts.inter(color: palette.primary, fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                        if (notes.isNotEmpty && notes != 'No notes provided.') ...[
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: palette.background,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: palette.border),
                                            ),
                                            child: Text(
                                              notes,
                                              style: GoogleFonts.inter(color: palette.textTertiary, fontSize: 11),
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 12),

                                        // Status update row
                                        Row(
                                          children: [
                                            Text(
                                              'Status: ',
                                              style: GoogleFonts.inter(fontSize: 12, color: palette.textSecondary),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8),
                                              decoration: BoxDecoration(
                                                color: palette.background,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: palette.border),
                                              ),
                                              child: DropdownButtonHideUnderline(
                                                child: DropdownButton<String>(
                                                  value: ['pending', 'contacted', 'quoted', 'closed'].contains(status)
                                                      ? status
                                                      : 'pending',
                                                  dropdownColor: palette.surface,
                                                  items: ['pending', 'contacted', 'quoted', 'closed']
                                                      .map((s) => DropdownMenuItem(
                                                            value: s,
                                                            child: Text(
                                                              s.toUpperCase(),
                                                              style: TextStyle(
                                                                color: palette.textPrimary,
                                                                fontSize: 11,
                                                                fontWeight: FontWeight.w600,
                                                              ),
                                                            ),
                                                          ))
                                                      .toList(),
                                                  onChanged: (newVal) {
                                                    if (newVal != null && newVal != status) {
                                                      _updateStatus(id, newVal);
                                                    }
                                                  },
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
