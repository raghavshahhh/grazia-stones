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

class AdminSamplesScreen extends ConsumerStatefulWidget {
  final String? initialStatus;
  const AdminSamplesScreen({super.key, this.initialStatus});

  @override
  ConsumerState<AdminSamplesScreen> createState() => _AdminSamplesScreenState();
}

class _AdminSamplesScreenState extends ConsumerState<AdminSamplesScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _samples = [];
  String _statusFilter = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _statusFilter = widget.initialStatus ?? 'all';
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

  Future<void> _deleteSample(String sampleId) async {
    try {
      final client = SupabaseService.instance.client;
      await client.from('sample_requests').delete().eq('id', sampleId);

      if (mounted) {
        LuxuryToast.show(context, message: 'Sample request deleted');
        _loadSamples();
      }
    } catch (e) {
      if (mounted) LuxuryToast.show(context, message: e.toString(), isError: true);
    }
  }

  void _showDeleteDialog(String sampleId, String name, LuxuryPalette palette) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: palette.border),
        ),
        title: Text(
          'Delete Sample Request',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: palette.textPrimary),
        ),
        content: Text(
          'Are you sure you want to remove the sample request for "$name"?',
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
              _deleteSample(sampleId);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showTrackingDialog(Map<String, dynamic> sample, LuxuryPalette palette) {
    final sampleId = sample['id']?.toString() ?? '';
    final trackingController = TextEditingController(text: sample['tracking_number']?.toString() ?? '');
    final notesController = TextEditingController(text: sample['admin_notes']?.toString() ?? '');
    final name = sample['recipient_name'] ?? sample['name'] ?? 'Client';
    bool markAsShipped = (sample['status'] ?? '').toString().toLowerCase() != 'shipped' &&
        (sample['status'] ?? '').toString().toLowerCase() != 'delivered';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: palette.border),
          ),
          title: Text(
            'Courier & Tracking: $name',
            style: GoogleFonts.playfairDisplay(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: palette.textPrimary,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter consignment tracking / AWB number:',
                  style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: trackingController,
                  style: TextStyle(color: palette.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'e.g. BD-8921873192 (BlueDart) / DL-49210',
                    hintStyle: TextStyle(color: palette.textTertiary, fontSize: 12),
                    filled: true,
                    fillColor: palette.background,
                    prefixIcon: Icon(Icons.local_shipping_outlined, color: palette.primary, size: 18),
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
                const SizedBox(height: 12),
                Text(
                  'Internal dispatch notes:',
                  style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  style: TextStyle(color: palette.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'e.g. Sample box dispatched with 3 finishes + catalog booklet',
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
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: markAsShipped,
                  activeColor: palette.primary,
                  onChanged: (val) => setDlgState(() => markAsShipped = val ?? false),
                  title: Text(
                    'Update status to "SHIPPED"',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: palette.textPrimary),
                  ),
                ),
              ],
            ),
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
                  final updateData = <String, dynamic>{
                    'tracking_number': trackingController.text.trim(),
                    'admin_notes': notesController.text.trim(),
                    'updated_at': DateTime.now().toIso8601String(),
                  };
                  if (markAsShipped) {
                    updateData['status'] = 'shipped';
                  }
                  await client.from('sample_requests').update(updateData).eq('id', sampleId);

                  if (mounted) {
                    LuxuryToast.show(context, message: 'Courier tracking details updated');
                    _loadSamples();
                  }
                } catch (e) {
                  if (mounted) LuxuryToast.show(context, message: e.toString(), isError: true);
                }
              },
              child: const Text('Save Details'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchWhatsApp(String phone, String name, String stoneName, String? trackingNumber) async {
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.length == 10) {
      cleanPhone = '91$cleanPhone';
    }
    final trackingMsg = (trackingNumber != null && trackingNumber.isNotEmpty)
        ? ' Your consignment tracking number is $trackingNumber.'
        : '';
    final message = 'Hello $name, your Grazia Stones sample box ($stoneName) is currently being processed.$trackingMsg Let us know if you have any questions!';
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
      if (_statusFilter != 'all') {
        final st = (s['status'] ?? '').toString().toLowerCase();
        if (_statusFilter == 'pending' || _statusFilter == 'requested') {
          if (st != 'pending' && st != 'requested') return false;
        } else if (_statusFilter == 'dispatched') {
          if (st != 'dispatched' && st != 'shipped') return false;
        } else if (st != _statusFilter.toLowerCase()) {
          return false;
        }
      }

      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final name = (s['recipient_name'] ?? s['name'] ?? '').toString().toLowerCase();
        final phone = (s['phone'] ?? '').toString().toLowerCase();
        final stone = (s['stone_name'] ?? '').toString().toLowerCase();
        final city = (s['city'] ?? '').toString().toLowerCase();
        final address = (s['delivery_address'] ?? s['address'] ?? '').toString().toLowerCase();
        final tracking = (s['tracking_number'] ?? '').toString().toLowerCase();

        return name.contains(query) ||
            phone.contains(query) ||
            stone.contains(query) ||
            city.contains(query) ||
            address.contains(query) ||
            tracking.contains(query);
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
                              hintText: 'Search by client, stone, tracking ID, or city...',
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
                              _buildFilterChip('All (${_samples.length})', 'all', palette),
                              const SizedBox(width: 8),
                              _buildFilterChip(
                                'Pending (${_samples.where((s) => ['pending', 'requested'].contains((s['status'] ?? 'pending').toString().toLowerCase())).length})',
                                'pending',
                                palette,
                              ),
                              const SizedBox(width: 8),
                              _buildFilterChip(
                                'Dispatched (${_samples.where((s) => ['dispatched', 'shipped'].contains((s['status'] ?? '').toString().toLowerCase())).length})',
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

                        const SizedBox(height: 6),

                        Expanded(
                          child: filteredSamples.isEmpty
                              ? Center(
                                  child: Text(
                                    _searchQuery.isNotEmpty
                                        ? 'No matching sample requests'
                                        : _statusFilter == 'all'
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
                                      final company = s['company']?.toString() ?? '';
                                      final stoneName = s['stone_name']?.toString() ?? 'Natural Stone';
                                      final qty = s['quantity'] ?? 1;
                                      final address = s['delivery_address'] ?? s['address'] ?? '';
                                      final city = s['city']?.toString() ?? '';
                                      final state = s['state']?.toString() ?? '';
                                      final pincode = s['pincode']?.toString() ?? '';
                                      final fullAddress = [address, city, state, pincode].where((str) => str.isNotEmpty).join(', ');
                                      final status = s['status']?.toString().toLowerCase() ?? 'pending';
                                      final tracking = s['tracking_number']?.toString() ?? '';
                                      final adminNotes = s['admin_notes']?.toString() ?? '';
                                      final userMsg = s['message']?.toString() ?? '';

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
                                            // Recipient Name + Status Badge
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
                                                          style: GoogleFonts.inter(color: palette.primary, fontSize: 11, fontWeight: FontWeight.w600),
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

                                            const SizedBox(height: 8),

                                            // Requested Stone & Box Qty
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: palette.background,
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(color: palette.border),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(Icons.layers_outlined, size: 16, color: palette.primary),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      'Stone: $stoneName',
                                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: palette.textPrimary),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: palette.primary.withValues(alpha: 0.12),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      'Qty: $qty',
                                                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: palette.primary),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            if (phone.isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              Text(
                                                'Phone: $phone',
                                                style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 12),
                                              ),
                                            ],

                                            if (fullAddress.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                'Delivery: $fullAddress',
                                                style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 12),
                                              ),
                                            ],

                                            // Consignment tracking number badge
                                            if (tracking.isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.withValues(alpha: 0.08),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.local_shipping_outlined, size: 14, color: Colors.blue),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        'Consignment Tracking: $tracking',
                                                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.blue.shade800),
                                                      ),
                                                    ),
                                                    IconButton(
                                                      padding: EdgeInsets.zero,
                                                      constraints: const BoxConstraints(),
                                                      tooltip: 'Copy Tracking ID',
                                                      icon: const Icon(Icons.copy_rounded, size: 14, color: Colors.blue),
                                                      onPressed: () {
                                                        Clipboard.setData(ClipboardData(text: tracking));
                                                        LuxuryToast.show(context, message: 'Tracking number copied!');
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],

                                            // Client special message if present
                                            if (userMsg.isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              Text(
                                                'Client note: “$userMsg”',
                                                style: GoogleFonts.inter(color: palette.textTertiary, fontSize: 11, fontStyle: FontStyle.italic),
                                              ),
                                            ],

                                            // Admin internal notes
                                            if (adminNotes.isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              Text(
                                                'Internal note: $adminNotes',
                                                style: GoogleFonts.inter(color: palette.primary, fontSize: 11, fontWeight: FontWeight.w600),
                                              ),
                                            ],

                                            const SizedBox(height: 12),

                                            // Status update dropdown + action buttons
                                            Row(
                                              children: [
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
                                                      value: ['pending', 'requested', 'dispatched', 'shipped', 'delivered', 'cancelled'].contains(status)
                                                          ? (status == 'shipped' ? 'dispatched' : status)
                                                          : 'pending',
                                                      dropdownColor: palette.surface,
                                                      items: ['pending', 'dispatched', 'delivered', 'cancelled']
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
                                                    tooltip: 'WhatsApp Client',
                                                    icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.green, size: 18),
                                                    onPressed: () => _launchWhatsApp(phone, name, stoneName, tracking.isNotEmpty ? tracking : null),
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

                                                // Courier Tracking Entry
                                                IconButton(
                                                  tooltip: 'Update Courier & Tracking',
                                                  icon: Icon(tracking.isEmpty ? Icons.add_box_outlined : Icons.edit_location_alt_outlined, color: palette.primary, size: 20),
                                                  onPressed: () => _showTrackingDialog(s, palette),
                                                  visualDensity: VisualDensity.compact,
                                                ),

                                                // Delete
                                                IconButton(
                                                  tooltip: 'Delete Sample Request',
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
