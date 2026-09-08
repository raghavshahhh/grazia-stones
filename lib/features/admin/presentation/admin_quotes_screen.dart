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
import 'package:url_launcher/url_launcher.dart';

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
  String _searchQuery = '';

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

  Future<void> _deleteQuote(String quoteId) async {
    try {
      final client = SupabaseService.instance.client;
      await client.from('quote_requests').delete().eq('id', quoteId);

      if (mounted) {
        LuxuryToast.show(context, message: 'Quote request removed');
        _loadQuotes();
      }
    } catch (e) {
      if (mounted) LuxuryToast.show(context, message: e.toString(), isError: true);
    }
  }

  void _showDeleteDialog(String quoteId, String clientName, LuxuryPalette palette) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: palette.border),
        ),
        title: Text(
          'Delete Quote Request',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: palette.textPrimary),
        ),
        content: Text(
          'Are you sure you want to permanently delete the inquiry from "$clientName"?',
          style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: palette.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteQuote(quoteId);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAdminNotesDialog(Map<String, dynamic> quote, LuxuryPalette palette) {
    final quoteId = quote['id']?.toString() ?? '';
    final notesController = TextEditingController(text: quote['admin_notes']?.toString() ?? '');
    final name = quote['customer_name'] ?? quote['name'] ?? 'Client';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: palette.border),
        ),
        title: Text(
          'Admin Notes: $name',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: palette.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add internal follow-up remarks, customized price quotes, or site inspection notes:',
              style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              maxLines: 4,
              style: TextStyle(color: palette.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'e.g. Quoted ₹350/sqft for 1200 sqft on 10th Oct...',
                hintStyle: TextStyle(color: palette.textTertiary, fontSize: 12),
                filled: true,
                fillColor: palette.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: palette.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: palette.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: palette.primary, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: palette.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final client = SupabaseService.instance.client;
                await client.from('quote_requests').update({
                  'admin_notes': notesController.text.trim(),
                  'updated_at': DateTime.now().toIso8601String(),
                }).eq('id', quoteId);

                if (mounted) {
                  LuxuryToast.show(context, message: 'Notes saved successfully');
                  _loadQuotes();
                }
              } catch (e) {
                if (mounted) LuxuryToast.show(context, message: e.toString(), isError: true);
              }
            },
            child: const Text('Save Notes'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchWhatsApp(String phone, String name, String? stoneName) async {
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.length == 10) {
      cleanPhone = '91$cleanPhone';
    }
    final stoneText = stoneName != null && stoneName.isNotEmpty ? ' regarding $stoneName' : '';
    final message = 'Hello $name, thank you for reaching out to Grazia Stones$stoneText. We have reviewed your architectural inquiry and would love to assist you.';
    final url = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) LuxuryToast.show(context, message: 'Could not open WhatsApp for $phone', isError: true);
      }
    } catch (_) {
      if (mounted) LuxuryToast.show(context, message: 'Could not open WhatsApp', isError: true);
    }
  }

  Future<void> _launchCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final url = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        if (mounted) LuxuryToast.show(context, message: 'Could not place call to $phone', isError: true);
      }
    } catch (_) {
      if (mounted) LuxuryToast.show(context, message: 'Could not place call', isError: true);
    }
  }

  Future<void> _launchEmail(String email, String name) async {
    final url = Uri.parse('mailto:$email?subject=${Uri.encodeComponent("Grazia Stones — Architectural Quote Inquiry")}&body=${Uri.encodeComponent("Dear $name,\n\nThank you for contacting Grazia Stones.\n\nBest regards,\nGrazia Stones Team")}');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        if (mounted) LuxuryToast.show(context, message: 'Could not open email client', isError: true);
      }
    } catch (_) {
      if (mounted) LuxuryToast.show(context, message: 'Could not open email client', isError: true);
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
      if (_statusFilter != 'all') {
        final st = (q['status'] ?? '').toString().toLowerCase();
        if (_statusFilter == 'closed') {
          if (!['closed', 'cancelled'].contains(st)) return false;
        } else if (st != _statusFilter.toLowerCase()) {
          return false;
        }
      }

      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final name = (q['customer_name'] ?? q['name'] ?? '').toString().toLowerCase();
        final phone = (q['customer_phone'] ?? q['phone'] ?? '').toString().toLowerCase();
        final email = (q['customer_email'] ?? q['email'] ?? '').toString().toLowerCase();
        final stone = (q['stone_name'] ?? '').toString().toLowerCase();
        final company = (q['company'] ?? '').toString().toLowerCase();
        final message = (q['message'] ?? q['notes'] ?? '').toString().toLowerCase();

        return name.contains(query) ||
            phone.contains(query) ||
            email.contains(query) ||
            stone.contains(query) ||
            company.contains(query) ||
            message.contains(query);
      }
      return true;
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
                        // Search bar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          child: TextField(
                            onChanged: (v) => setState(() => _searchQuery = v.trim()),
                            style: GoogleFonts.inter(fontSize: 13, color: palette.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Search by client, stone, company, or phone...',
                              hintStyle: GoogleFonts.inter(fontSize: 12, color: palette.textTertiary),
                              prefixIcon: Icon(Icons.search, color: palette.primary, size: 20),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(Icons.clear, size: 16, color: palette.textSecondary),
                                      onPressed: () => setState(() => _searchQuery = ''),
                                    )
                                  : null,
                              filled: true,
                              fillColor: palette.surface,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: palette.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: palette.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: palette.primary, width: 1.5),
                              ),
                            ),
                          ),
                        ),

                        // Horizontal status filter chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
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

                        const SizedBox(height: 6),

                        Expanded(
                          child: filteredQuotes.isEmpty
                              ? Center(
                                  child: Text(
                                    _searchQuery.isNotEmpty
                                        ? 'No matching quotes found'
                                        : _statusFilter == 'all'
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
                                      final company = q['company']?.toString() ?? '';
                                      final stoneName = q['stone_name']?.toString() ?? '';
                                      final area = q['area_sqft'] ?? q['sqft'] ?? '-';
                                      final quantity = q['quantity'];
                                      final status = q['status']?.toString().toLowerCase() ?? 'pending';
                                      final userNotes = q['message'] ?? q['notes'] ?? '';
                                      final adminNotes = q['admin_notes']?.toString() ?? '';

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
                                            // Name + Status Header
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        name,
                                                        style: GoogleFonts.playfairDisplay(
                                                          fontWeight: FontWeight.w700,
                                                          color: palette.textPrimary,
                                                          fontSize: 15,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      if (company.isNotEmpty)
                                                        Text(
                                                          company,
                                                          style: GoogleFonts.inter(
                                                            color: palette.primary,
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                    ],
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

                                            // Requested Stone & Specs
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 4,
                                              children: [
                                                if (stoneName.isNotEmpty)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: palette.primary.withValues(alpha: 0.1),
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(color: palette.primary.withValues(alpha: 0.3)),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.diamond_outlined, size: 12, color: palette.primary),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          stoneName,
                                                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: palette.primary),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                if (area != '-' && area != null)
                                                  Text(
                                                    'Area: $area sq ft',
                                                    style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
                                                  ),
                                                if (quantity != null && quantity != 0)
                                                  Text(
                                                    'Qty: $quantity',
                                                    style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
                                                  ),
                                              ],
                                            ),

                                            if (phone.isNotEmpty || email.isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              Text(
                                                [phone, email].where((s) => s.isNotEmpty).join(' • '),
                                                style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 12),
                                              ),
                                            ],

                                            // Customer message if any
                                            if (userNotes.isNotEmpty && userNotes != 'No notes provided.') ...[
                                              const SizedBox(height: 8),
                                              Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: palette.background,
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: palette.border),
                                                ),
                                                child: Text(
                                                  '“$userNotes”',
                                                  style: GoogleFonts.inter(color: palette.textTertiary, fontSize: 11, fontStyle: FontStyle.italic),
                                                ),
                                              ),
                                            ],

                                            // Admin internal remarks if saved
                                            if (adminNotes.isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: palette.primary.withValues(alpha: 0.08),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: palette.primary.withValues(alpha: 0.2)),
                                                ),
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Icon(Icons.edit_note_rounded, size: 14, color: palette.primary),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        'Admin Note: $adminNotes',
                                                        style: GoogleFonts.inter(color: palette.primary, fontSize: 11, fontWeight: FontWeight.w600),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],

                                            const SizedBox(height: 12),

                                            // Action Buttons: Contact + Status Dropdown + Admin Notes + Delete
                                            Row(
                                              children: [
                                                // Status Dropdown
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                                  height: 34,
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
                                                                    fontSize: 10,
                                                                    fontWeight: FontWeight.w700,
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

                                                const Spacer(),

                                                // WhatsApp
                                                if (phone.isNotEmpty)
                                                  IconButton(
                                                    tooltip: 'Chat on WhatsApp',
                                                    icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.green, size: 18),
                                                    onPressed: () => _launchWhatsApp(phone, name, stoneName),
                                                    visualDensity: VisualDensity.compact,
                                                  ),

                                                // Call
                                                if (phone.isNotEmpty)
                                                  IconButton(
                                                    tooltip: 'Call Client',
                                                    icon: Icon(Icons.phone_outlined, color: palette.primary, size: 18),
                                                    onPressed: () => _launchCall(phone),
                                                    visualDensity: VisualDensity.compact,
                                                  ),

                                                // Email
                                                if (email.isNotEmpty)
                                                  IconButton(
                                                    tooltip: 'Send Email',
                                                    icon: Icon(Icons.email_outlined, color: palette.textSecondary, size: 18),
                                                    onPressed: () => _launchEmail(email, name),
                                                    visualDensity: VisualDensity.compact,
                                                  ),

                                                // Add / Edit Note
                                                IconButton(
                                                  tooltip: adminNotes.isEmpty ? 'Add Admin Note' : 'Edit Admin Note',
                                                  icon: Icon(adminNotes.isEmpty ? Icons.note_add_outlined : Icons.edit_note_rounded, color: palette.primary, size: 20),
                                                  onPressed: () => _showAdminNotesDialog(q, palette),
                                                  visualDensity: VisualDensity.compact,
                                                ),

                                                // Delete
                                                IconButton(
                                                  tooltip: 'Delete Request',
                                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                                                  onPressed: () => _showDeleteDialog(id, name, palette),
                                                  visualDensity: VisualDensity.compact,
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
