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

class AdminSamplesScreen extends ConsumerStatefulWidget {
  const AdminSamplesScreen({super.key});

  @override
  ConsumerState<AdminSamplesScreen> createState() => _AdminSamplesScreenState();
}

class _AdminSamplesScreenState extends ConsumerState<AdminSamplesScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _samples = [];
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadSamples();
  }

  Future<void> _loadSamples() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final client = SupabaseService.instance.client;
      final data = await client
          .from('sample_requests')
          .select()
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _samples = List<Map<String, dynamic>>.from(data);
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

  Future<void> _updateStatus(String sampleId, String status) async {
    try {
      final client = SupabaseService.instance.client;
      await client.from('sample_requests').update({
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', sampleId);

      if (mounted) {
        LuxuryToast.show(context, message: 'Sample status updated to ${status.toUpperCase()}');
        _loadSamples();
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
      case 'delivered':
        return Colors.green;
      case 'dispatched':
      case 'shipped':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      case 'requested':
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);

    final filteredSamples = _samples.where((s) {
      if (_statusFilter == 'all') return true;
      final st = (s['status'] ?? '').toString().toLowerCase();
      if (_statusFilter == 'pending' || _statusFilter == 'requested') {
        return st == 'pending' || st == 'requested';
      }
      return st == _statusFilter.toLowerCase();
    }).toList();

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
          'Sample Requests (${_samples.length})',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Samples',
            onPressed: () {
              HapticFeedback.lightImpact();
              _loadSamples();
            },
            icon: Icon(Icons.refresh_rounded, color: palette.primary),
          ),
          AdminQuickNavButton(
            currentRoute: '/admin/samples',
            palette: palette,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _error != null
          ? ErrorHandlerWidget(error: Exception(_error), onRetry: _loadSamples)
          : _isLoading
              ? Center(child: CircularProgressIndicator(color: palette.primary))
              : Column(
                  children: [
                    // Horizontal status filter chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      child: Row(
                        children: [
                          _buildFilterChip('All (${_samples.length})', 'all', palette),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'Pending (${_samples.where((s) => (s['status'] ?? 'pending').toString().toLowerCase() == 'pending').length})',
                            'pending',
                            palette,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'Dispatched (${_samples.where((s) => (s['status'] ?? '').toString().toLowerCase() == 'dispatched').length})',
                            'dispatched',
                            palette,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'Delivered (${_samples.where((s) => (s['status'] ?? '').toString().toLowerCase() == 'delivered').length})',
                            'delivered',
                            palette,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'Cancelled (${_samples.where((s) => (s['status'] ?? '').toString().toLowerCase() == 'cancelled').length})',
                            'cancelled',
                            palette,
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: filteredSamples.isEmpty
                          ? Center(
                              child: Text(
                                _statusFilter == 'all'
                                    ? 'No sample requests yet'
                                    : 'No sample requests with status "$_statusFilter"',
                                style: GoogleFonts.inter(color: palette.textSecondary),
                              ),
                            )
                          : RefreshIndicator(
                              color: palette.primary,
                              backgroundColor: palette.surface,
                              onRefresh: _loadSamples,
                              child: ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                itemCount: filteredSamples.length,
                                itemBuilder: (context, i) {
                                  final s = filteredSamples[i];
                                  final id = s['id']?.toString() ?? '';
                                  final name = s['recipient_name'] ?? s['name'] ?? 'Architect Client';
                                  final phone = s['phone'] ?? '';
                                  final address = s['delivery_address'] ?? s['address'] ?? '';
                                  final status = s['status']?.toString().toLowerCase() ?? 'pending';

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
                                        if (phone.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'Phone: $phone',
                                            style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 12),
                                          ),
                                        ],
                                        if (address.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'Delivery: $address',
                                            style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 12),
                                          ),
                                        ],
                                        const SizedBox(height: 12),

                                        // Status update dropdown
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
                                                  value: ['pending', 'requested', 'dispatched', 'delivered', 'cancelled'].contains(status)
                                                      ? status
                                                      : 'pending',
                                                  dropdownColor: palette.surface,
                                                  items: ['pending', 'requested', 'dispatched', 'delivered', 'cancelled']
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
    );
  }
}
