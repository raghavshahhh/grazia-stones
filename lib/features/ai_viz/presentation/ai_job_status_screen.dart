import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grazia_stones/core/models/ai_job.dart';
import 'package:grazia_stones/features/ai_viz/providers/ai_job_provider.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/core/widgets/error_handler_widget.dart';
import 'package:timeago/timeago.dart' as timeago;

/// Screen for viewing all AI jobs with status tracking
class AIJobStatusScreen extends ConsumerStatefulWidget {
  const AIJobStatusScreen({super.key});

  @override
  ConsumerState<AIJobStatusScreen> createState() => _AIJobStatusScreenState();
}

class _AIJobStatusScreenState extends ConsumerState<AIJobStatusScreen> {
  String _selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);
    final jobListState = ref.watch(aiJobListProvider);
    final activeJobsAsync = ref.watch(activeJobsStreamProvider);

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
          'AI Job Status',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
        actions: [
          // Active jobs badge
          activeJobsAsync.when(
            data: (activeJobs) {
              if (activeJobs.isEmpty) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: palette.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: palette.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${activeJobs.length} active',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: palette.primary,
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(aiJobListProvider.notifier).refresh();
        },
        child: Column(
          children: [
            // Filter chips
            _buildFilterChips(palette, jobListState),

            // Job list
            Expanded(
              child: _buildJobList(palette, jobListState),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(LuxuryPalette palette, AIJobListState state) {
    final filters = [
      {'id': 'all', 'label': 'All', 'count': state.jobs.length},
      {'id': 'queued', 'label': 'Queued', 'count': state.jobs.where((j) => j.status == 'queued').length},
      {'id': 'processing', 'label': 'Processing', 'count': state.jobs.where((j) => j.status == 'processing').length},
      {'id': 'completed', 'label': 'Completed', 'count': state.jobs.where((j) => j.status == 'completed').length},
      {'id': 'failed', 'label': 'Failed', 'count': state.jobs.where((j) => j.status == 'failed').length},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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

  Widget _buildJobList(LuxuryPalette palette, AIJobListState state) {
    if (state.isLoading && state.jobs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.jobs.isEmpty) {
      return Center(
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
                state.error!,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: palette.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => ref.read(aiJobListProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Filter jobs based on selected filter
    var filteredJobs = state.jobs;
    if (_selectedFilter != 'all') {
      filteredJobs = state.jobs.where((job) => job.status == _selectedFilter).toList();
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
                    ? 'Create your first AI visualization from the AI Studio'
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

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      physics: const BouncingScrollPhysics(),
      itemCount: filteredJobs.length,
      itemBuilder: (context, index) {
        final job = filteredJobs[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AIJobCard(
            job: job,
            palette: palette,
            onTap: () => _showJobDetails(context, job, palette),
            onCancel: job.isActive
                ? () => ref.read(aiJobListProvider.notifier).cancelJob(job.id)
                : null,
            onRetry: job.status == 'failed'
                ? () => ref.read(aiJobListProvider.notifier).retryJob(job.id)
                : null,
          ),
        );
      },
    );
  }

  void _showJobDetails(BuildContext context, AIJob job, LuxuryPalette palette) {
    showModalBottomSheet(
      context: context,
      backgroundColor: palette.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AIJobDetailsSheet(jobId: job.id),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// JOB CARD WIDGET
// ═══════════════════════════════════════════════════════════════════════════

class AIJobCard extends StatelessWidget {
  final AIJob job;
  final LuxuryPalette palette;
  final VoidCallback? onTap;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;

  const AIJobCard({
    super.key,
    required this.job,
    required this.palette,
    this.onTap,
    this.onCancel,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
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
              // Header row
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
                          '${job.readableStatus} • ${timeago.format(job.createdAt)}',
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

              // Processing time or error
              if (job.isTerminal) ...[
                const SizedBox(height: 12),
                if (job.status == 'completed')
                  Row(
                    children: [
                      Icon(Icons.timer_outlined, size: 14, color: palette.textTertiary),
                      const SizedBox(width: 6),
                      Text(
                        'Completed in ${job.formattedProcessingTime}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  )
                else if (job.status == 'failed' && job.errorMessage != null)
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

              // Action buttons
              if (onCancel != null || onRetry != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (onCancel != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onCancel,
                          icon: const Icon(Icons.close_rounded, size: 14),
                          label: const Text('Cancel'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: palette.textPrimary,
                            side: BorderSide(color: palette.border),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    if (onRetry != null)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh_rounded, size: 14),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: palette.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'queued':
        return const Color(0xFFF57C00); // Orange
      case 'processing':
        return const Color(0xFF1976D2); // Blue
      case 'completed':
        return const Color(0xFF2E7D32); // Green
      case 'failed':
        return const Color(0xFFD32F2F); // Red
      case 'cancelled':
        return const Color(0xFF616161); // Grey
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
// JOB DETAILS BOTTOM SHEET
// ═══════════════════════════════════════════════════════════════════════════

class AIJobDetailsSheet extends ConsumerWidget {
  final String jobId;

  const AIJobDetailsSheet({super.key, required this.jobId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(themePaletteProvider);
    final jobState = ref.watch(aiJobTrackingProvider(jobId));

    if (jobState.job == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final job = jobState.job!;

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

            // Header
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getStatusColor(job.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getStatusIcon(job.status),
                    color: _getStatusColor(job.status),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.stoneName ?? 'AI Visualization',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                      Text(
                        job.readableStatus,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: _getStatusColor(job.status),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Details
            _buildDetailRow(palette, 'Job ID', job.id.substring(0, 8)),
            _buildDetailRow(palette, 'Type', job.jobType),
            _buildDetailRow(palette, 'Created', timeago.format(job.createdAt)),
            if (job.startedAt != null)
              _buildDetailRow(palette, 'Started', timeago.format(job.startedAt!)),
            if (job.completedAt != null)
              _buildDetailRow(palette, 'Completed', timeago.format(job.completedAt!)),
            if (job.processingTimeMs != null)
              _buildDetailRow(palette, 'Processing Time', job.formattedProcessingTime),
            if (job.color != null)
              _buildDetailRow(palette, 'Color', job.color!),
            if (job.finish != null)
              _buildDetailRow(palette, 'Finish', job.finish!),

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

            // Actions
            const SizedBox(height: 24),
            Row(
              children: [
                if (job.isActive)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ref.read(aiJobListProvider.notifier).cancelJob(job.id);
                        context.pop();
                      },
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Cancel Job'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.textPrimary,
                        side: BorderSide(color: palette.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                if (job.status == 'failed')
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ref.read(aiJobListProvider.notifier).retryJob(job.id);
                        context.pop();
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
                if (job.status == 'completed')
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.check_circle_rounded, size: 16),
                      label: const Text('View Result'),
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
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(LuxuryPalette palette, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: palette.textSecondary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: palette.textPrimary,
            ),
          ),
        ],
      ),
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
