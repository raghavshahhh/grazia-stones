import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/models/sample_order.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';

/// User-side sample request history — real rows from
/// `sample_requests` (the same table the admin dashboard reads).
class SampleHistoryScreen extends ConsumerStatefulWidget {
  const SampleHistoryScreen({super.key});

  @override
  ConsumerState<SampleHistoryScreen> createState() =>
      _SampleHistoryScreenState();
}

class _SampleHistoryScreenState extends ConsumerState<SampleHistoryScreen> {
  bool _isLoading = true;
  String? _error;
  List<SampleOrder> _samples = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final repo = ref.read(sampleOrderRepositoryProvider);
      final samples = await repo.getSampleOrders();
      if (mounted) {
        setState(() {
          _samples = samples;
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

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
      case 'completed':
      case 'approved':
        return Colors.green.shade600;
      case 'shipped':
      case 'processing':
        return Colors.blue.shade600;
      case 'rejected':
      case 'cancelled':
        return Colors.red.shade600;
      default:
        return Colors.orange.shade700;
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
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: palette.textPrimary, size: 18),
        ),
        title: Text(
          'My Sample Requests',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _load,
            icon: Icon(Icons.refresh_rounded, color: palette.primary, size: 20),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_off_outlined,
                          size: 44, color: palette.textTertiary),
                      const SizedBox(height: 12),
                      Text('Could not load your samples',
                          style:
                              GoogleFonts.inter(color: palette.textPrimary)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _samples.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_outlined,
                              size: 44, color: palette.textTertiary),
                          const SizedBox(height: 12),
                          Text('No sample requests yet',
                              style: GoogleFonts.playfairDisplay(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: palette.textPrimary)),
                          const SizedBox(height: 6),
                          Text(
                            'Order swatches from any product page —\nthey\'ll be tracked here.',
                            style: GoogleFonts.inter(
                                fontSize: 12.5, color: palette.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: () => context.go('/collections'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: palette.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Browse Stones'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: palette.primary,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: _samples.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final s = _samples[i];
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: palette.surface,
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: palette.border, width: 0.8),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: palette.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(Icons.inventory_outlined,
                                      color: palette.primary, size: 20),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.stoneName,
                                        style: GoogleFonts.playfairDisplay(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: palette.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${s.city} • ${_formatDate(s.createdAt)}',
                                        style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: palette.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: _statusColor(s.status)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    s.status[0].toUpperCase() +
                                        s.status.substring(1).toLowerCase(),
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: _statusColor(s.status),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year}';
}
