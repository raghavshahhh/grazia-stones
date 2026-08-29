import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/services/supabase_service.dart';
import 'package:grazia_stones/core/widgets/error_handler_widget.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';

class AdminSamplesScreen extends ConsumerStatefulWidget {
  const AdminSamplesScreen({super.key});

  @override
  ConsumerState<AdminSamplesScreen> createState() => _AdminSamplesScreenState();
}

class _AdminSamplesScreenState extends ConsumerState<AdminSamplesScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _samples = [];

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
      await client.from('sample_requests').update({'status': status}).eq('id', sampleId);

      if (mounted) {
        showSuccessSnackbar(context, 'Sample dispatch status updated');
        _loadSamples();
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
          'Sample Requests (${_samples.length})',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
      ),
      body: _error != null
          ? ErrorHandlerWidget(error: Exception(_error), onRetry: _loadSamples)
          : _isLoading
              ? Center(child: CircularProgressIndicator(color: palette.primary))
              : _samples.isEmpty
                  ? Center(
                      child: Text('No sample requests yet', style: GoogleFonts.inter(color: palette.textSecondary)),
                    )
                  : RefreshIndicator(
                      color: palette.primary,
                      backgroundColor: palette.surface,
                      onRefresh: _loadSamples,
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        itemCount: _samples.length,
                        itemBuilder: (context, i) {
                          final s = _samples[i];
                          final id = s['id']?.toString() ?? '';
                          final name = s['recipient_name'] ?? s['name'] ?? 'Architect';
                          final phone = s['phone'] ?? '';
                          final address = s['delivery_address'] ?? s['address'] ?? '';
                          final status = s['status'] ?? 'pending';

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
                                  'Phone: $phone',
                                  style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 12),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Delivery: $address',
                                  style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 12),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () => _updateStatus(id, 'dispatched'),
                                      child: const Text('Mark Dispatched', style: TextStyle(fontSize: 12)),
                                    ),
                                    TextButton(
                                      onPressed: () => _updateStatus(id, 'delivered'),
                                      child: const Text('Mark Delivered', style: TextStyle(fontSize: 12)),
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
