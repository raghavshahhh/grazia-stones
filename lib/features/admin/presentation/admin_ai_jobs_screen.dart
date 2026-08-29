import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/models/ai_job.dart';
import 'package:grazia_stones/features/ai_viz/providers/ai_job_provider.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:timeago/timeago.dart' as timeago;

/// Admin screen for managing all AI jobs
class AdminAIJobsScreen extends ConsumerStatefulWidget {
  const AdminAIJobsScreen({super.key});

  @override
  ConsumerState<AdminAIJobsScreen> createState() => _AdminAIJobsScreenState();
}

class _AdminAIJobsScreenState extends ConsumerState<AdminAIJobsScreen> {
  String _selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);
    final allJobsAsync = ref.watch(adminAllJobsProvider);
    final statsAsync = ref.watch(adminJobStatisticsProvider);

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
          'AI Jobs Management',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: palette.textPrimary),
            onPressed: () {
              ref.invalidate(adminAllJobsProvider);
              ref.invalidate(adminJobStatisticsProvider);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Statistics cards
          statsAsync.when(
            data: (stats) => _buildStatisticsCards(palette, stats),
            loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
            error: (_, __) => const SizedBox.shrink(),
          ),

          const SizedBox(height: 16),

          // Filter chips
          allJobsAsync.when(
            data: (jobs) => _buildFilterChips(palette, jobs),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Jobs list
          Expanded(
            child: allJobsAsync.when(
              data: (jobs) => _buildJobsList(palette, jobs),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline_rounded, size: 48, color: palette.textTertiary),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load jobs',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: palette.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          ref.invalidate(adminAllJobsProvider);
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCards(LuxuryPalette palette, Map<String, int> stats) {
    final cards = [
      {'label': 'Total', 'count': stats['total'] ?? 0, 'color': palette.primary},
      {'label': 'Queued', 'count': stats['queued'] ?? 0, 'color': const Color(0xFFF57C00)},
      {'label': 'Processing', 'count': stats['processing'] ?? 0, 'color': const Color(0xFF1976D2)},
      {'label': 'Completed', 'count': stats['completed'] ?? 0, 'color': const Color(0xFF2E7D32)},
      {'label': 'Failed', 'count': stats['failed'] ?? 0, 'color': const Color(0xFFD32F2F)},
    ];

    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: cards.length,
        itemBuilder: (context, index) {
          final card = cards[index];
          return Container(
            width: 120,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: (card['color'] as Color).withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  card['label'] as String,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: palette.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${card['count']}',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: card['color'] as Color,
                    height: 1,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChips(LuxuryPalette palette, List<AIJob> allJobs) {
    final filters = [
      {'id': 'all', 'label': 'All', 'count': allJobs.length},
      {'id': 'queued', 'label': 'Queued', 'count': allJobs.where((j) => j.status == 'queued').length},
      {'id': 'processing', 'label': 'Processing', 'count': allJobs.where((j) => j.status == 'processing').length},
      {'id': 'completed', 'label': 'Completed', 'count': allJobs.where((j) => j.status == 'completed').length},
      {'id': 'failed', 'label': 'Failed', 'count': allJobs.where((j) => j.status == 'failed').length},
      {'id': 'cancelled', 'label': 'Cancelled', 'count': allJobs.where((j) => j.status == 'cancelled').length},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: filters.map((filter) {
            final isSelected = _selectedFilter == filter['id'];
            final count = filter['count'] as int;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text('${filter['label']} ($count)'),
                selected: isSelected,
                selectedColor: palette.primary,
                backgroundColor: palette.surface,
                labelStyle: GoogleFonts.inter(
                  color: isSelected ? Colors.white : palette.textPrimary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12,
                ),
                onSelected: (_) {
                  setState(() => _selectedFilter = filter['id'] as String);
                  HapticFeedback.selectionClick();
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildJobsList(LuxuryPalette palette, List<AIJob> allJobs) {
    // Filter jobs
    var filteredJobs = allJobs;
    if (_selectedFilter != 'all') {
      filteredJobs = allJobs.where((job) => job.status == _selectedFilter).toList();
    }

    if (filteredJobs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox_outlined, size: 48, color: palette.textTertiary),
              const SizedBox(height: 16),
              Text(
                'No jobs found',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _selectedFilter == 'all'
                    ? 'No AI jobs have been created yet'
                    : 'No jobs with $_selectedFilter status',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: palette.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminAllJobsProvider);
        ref.invalidate(adminJobStatisticsProvider);
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        physics: const BouncingScrollPhysics(),
        itemCount: filteredJobs.length,
        itemBuilder: (context, index) {
          final job = filteredJobs[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _AdminJobCard(job: job, palette: palette),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ADMIN JOB CARD
// ═══════════════════════════════════════════════════════════════════════════

class _AdminJobCard extends ConsumerWidget {
  final AIJob job;
  final LuxuryPalette palette;

  const _AdminJobCard({required this.job, required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showJobDetails(context, job),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _getStatusColor(job.status).withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  // Status icon
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _getStatusColor(job.status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _getStatusIcon(job.status),
                      color: _getStatusColor(job.status),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Job info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.stoneName ?? 'AI Visualization',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: palette.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ID: ${job.id.substring(0, 8)} • ${timeago.format(job.createdAt)}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(job.status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      job.readableStatus,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _getStatusColor(job.status),
                      ),
                    ),
                  ),
                ],
              ),

              // User info
              if (job.userId != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: palette.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: palette.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person_outline_rounded, size: 14, color: palette.textTertiary),
                      const SizedBox(width: 8),
                      Text(
                        'User: ${job.userId!.substring(0, 8)}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: palette.textSecondary,
                        ),
                      ),
                      if (job.processingTimeMs != null) ...[
                        const SizedBox(width: 16),
                        Icon(Icons.timer_outlined, size: 14, color: palette.textTertiary),
                        const SizedBox(width: 6),
                        Text(
                          job.formattedProcessingTime,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: palette.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              // Progress bar for active jobs
              if (job.isActive) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: job.status == 'processing' ? null : 0.1,
                    backgroundColor: palette.border,
                    valueColor: AlwaysStoppedAnimation(_getStatusColor(job.status)),
                    minHeight: 4,
                  ),
                ),
              ],

              // Error message
              if (job.status == 'failed' && job.errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD32F2F).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFD32F2F).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, size: 14, color: Color(0xFFD32F2F)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          job.errorMessage!,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFFD32F2F),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Admin actions
              if (job.status == 'failed') ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final repo = ref.read(aiJobRepositoryProvider);
                      await repo.retryJob(job.id);
                      ref.invalidate(adminAllJobsProvider);
                      ref.invalidate(adminJobStatisticsProvider);
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 14),
                    label: const Text('Retry Job'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.primary,
                      side: BorderSide(color: palette.primary),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showJobDetails(BuildContext context, AIJob job) {
    showModalBottomSheet(
      context: context,
      backgroundColor: palette.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AdminJobDetailsSheet(job: job, palette: palette),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'queued':
        return const Color(0xFFF57C00);
      case 'processing':
        return const Color(0xFF1976D2);
      case 'completed':
        return const Color(0xFF2E7D32);
      case 'failed':
        return const Color(0xFFD32F2F);
      case 'cancelled':
        return const Color(0xFF616161);
      default:
        return const Color(0xFF616161);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'queued':
        return Icons.schedule_rounded;
      case 'processing':
        return Icons.sync_rounded;
      case 'completed':
        return Icons.check_circle_rounded;
      case 'failed':
        return Icons.error_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ADMIN JOB DETAILS SHEET
// ═══════════════════════════════════════════════════════════════════════════

class _AdminJobDetailsSheet extends ConsumerWidget {
  final AIJob job;
  final LuxuryPalette palette;

  const _AdminJobDetailsSheet({required this.job, required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              'Job Details',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 20),

            // Details
            _buildDetailRow('Job ID', job.id),
            _buildDetailRow('Status', job.readableStatus),
            _buildDetailRow('Type', job.jobType),
            _buildDetailRow('Stone', job.stoneName ?? '--'),
            if (job.userId != null) _buildDetailRow('User ID', job.userId!.substring(0, 12)),
            if (job.color != null) _buildDetailRow('Color', job.color!),
            if (job.finish != null) _buildDetailRow('Finish', job.finish!),
            _buildDetailRow('Created', timeago.format(job.createdAt)),
            if (job.startedAt != null)
              _buildDetailRow('Started', timeago.format(job.startedAt!)),
            if (job.completedAt != null)
              _buildDetailRow('Completed', timeago.format(job.completedAt!)),
            if (job.processingTimeMs != null)
              _buildDetailRow('Processing Time', job.formattedProcessingTime),

            // Metadata
            if (job.metadata != null && job.metadata!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Metadata',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: palette.border),
                ),
                child: Text(
                  job.metadata.toString(),
                  style: GoogleFonts.sourceCodePro(
                    fontSize: 11,
                    color: palette.textSecondary,
                  ),
                ),
              ),
            ],

            // Error message
            if (job.errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFD32F2F).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFD32F2F).withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Error Message',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFD32F2F),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      job.errorMessage!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFFD32F2F),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Result image
            if (job.resultImageUrl != null) ...[
              const SizedBox(height: 20),
              Text(
                'Result Image',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  job.resultImageUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 200,
                    color: palette.border,
                    child: const Center(
                      child: Icon(Icons.broken_image_outlined, size: 48),
                    ),
                  ),
                ),
              ),
            ],

            // Admin actions
            const SizedBox(height: 24),
            if (job.status == 'failed')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final repo = ref.read(aiJobRepositoryProvider);
                    await repo.retryJob(job.id);
                    ref.invalidate(adminAllJobsProvider);
                    ref.invalidate(adminJobStatisticsProvider);
                    if (context.mounted) context.pop();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry Job'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: palette.textPrimary,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
