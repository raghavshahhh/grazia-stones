import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grazia_stones/core/models/ai_job.dart';
import 'package:grazia_stones/core/repositories/ai_job_repository.dart';
import 'package:grazia_stones/core/di.dart';

// ═══════════════════════════════════════════════════════════════════════════
// STATE CLASSES
// ═══════════════════════════════════════════════════════════════════════════

/// State for AI job list
class AIJobListState {
  final List<AIJob> jobs;
  final bool isLoading;
  final String? error;
  final bool hasMore;

  const AIJobListState({
    this.jobs = const [],
    this.isLoading = false,
    this.error,
    this.hasMore = true,
  });

  AIJobListState copyWith({
    List<AIJob>? jobs,
    bool? isLoading,
    String? error,
    bool? hasMore,
  }) {
    return AIJobListState(
      jobs: jobs ?? this.jobs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

/// State for single AI job tracking
class AIJobTrackingState {
  final AIJob? job;
  final bool isPolling;
  final String? error;
  final double progress;

  const AIJobTrackingState({
    this.job,
    this.isPolling = false,
    this.error,
    this.progress = 0.0,
  });

  AIJobTrackingState copyWith({
    AIJob? job,
    bool? isPolling,
    String? error,
    double? progress,
  }) {
    return AIJobTrackingState(
      job: job ?? this.job,
      isPolling: isPolling ?? this.isPolling,
      error: error,
      progress: progress ?? this.progress,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// JOB LIST PROVIDER
// ═══════════════════════════════════════════════════════════════════════════

/// Provider for AI job list management
class AIJobListNotifier extends StateNotifier<AIJobListState> {
  final AIJobRepository _repository;
  StreamSubscription? _subscription;

  AIJobListNotifier(this._repository) : super(const AIJobListState()) {
    _init();
  }

  void _init() {
    loadJobs();
    _subscribeToRealTimeUpdates();
  }

  /// Load jobs from database
  Future<void> loadJobs({
    String? status,
    bool refresh = false,
  }) async {
    if (state.isLoading) return;

    state = state.copyWith(
      isLoading: true,
      error: null,
    );

    try {
      final jobs = await _repository.getJobs(
        status: status,
        limit: 50,
        offset: refresh ? 0 : state.jobs.length,
      );

      state = state.copyWith(
        jobs: refresh ? jobs : [...state.jobs, ...jobs],
        isLoading: false,
        hasMore: jobs.length >= 50,
      );

      debugPrint('✅ Loaded ${jobs.length} AI jobs');
    } catch (e) {
      debugPrint('❌ Error loading AI jobs: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Refresh job list
  Future<void> refresh() async {
    await loadJobs(refresh: true);
  }

  /// Load more jobs (pagination)
  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading) return;
    await loadJobs();
  }

  /// Subscribe to real-time job updates
  void _subscribeToRealTimeUpdates() {
    _subscription?.cancel();
    _subscription = _repository.subscribeToUserJobs().listen(
      (jobs) {
        state = state.copyWith(jobs: jobs);
        debugPrint('🔄 Real-time update: ${jobs.length} jobs');
      },
      onError: (e) {
        debugPrint('❌ Real-time subscription error: $e');
      },
    );
  }

  /// Create new visualization job
  Future<AIJob?> createVisualizationJob({
    required String inputImageUrl,
    String? stoneId,
    String? stoneName,
    String? color,
    String? finish,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final job = await _repository.createVisualizationJob(
        inputImageUrl: inputImageUrl,
        stoneId: stoneId,
        stoneName: stoneName,
        color: color,
        finish: finish,
        metadata: metadata,
      );

      // Refresh list to show new job
      await refresh();

      // Trigger processing
      await _repository.processJob(job.id);

      return job;
    } catch (e) {
      debugPrint('❌ Error creating visualization job: $e');
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// Cancel a job
  Future<void> cancelJob(String jobId) async {
    try {
      await _repository.cancelJob(jobId);
      await refresh();
    } catch (e) {
      debugPrint('❌ Error cancelling job: $e');
      state = state.copyWith(error: e.toString());
    }
  }

  /// Retry a failed job
  Future<AIJob?> retryJob(String jobId) async {
    try {
      final newJob = await _repository.retryJob(jobId);
      await refresh();
      
      // Trigger processing for new job
      await _repository.processJob(newJob.id);
      
      return newJob;
    } catch (e) {
      debugPrint('❌ Error retrying job: $e');
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// Get active jobs count
  int get activeJobsCount {
    return state.jobs.where((job) => job.isActive).length;
  }

  /// Get completed jobs count
  int get completedJobsCount {
    return state.jobs.where((job) => job.status == 'completed').length;
  }

  /// Get failed jobs count
  int get failedJobsCount {
    return state.jobs.where((job) => job.status == 'failed').length;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Provider for AI job list
final aiJobListProvider = StateNotifierProvider<AIJobListNotifier, AIJobListState>((ref) {
  final repository = ref.watch(aiJobRepositoryProvider);
  return AIJobListNotifier(repository);
});

// ═══════════════════════════════════════════════════════════════════════════
// SINGLE JOB TRACKING PROVIDER
// ═══════════════════════════════════════════════════════════════════════════

/// Provider for tracking a single AI job
class AIJobTrackingNotifier extends StateNotifier<AIJobTrackingState> {
  final AIJobRepository _repository;
  final String jobId;
  StreamSubscription? _subscription;
  Timer? _pollingTimer;

  AIJobTrackingNotifier(this._repository, this.jobId) : super(const AIJobTrackingState()) {
    _init();
  }

  void _init() {
    _loadJob();
    _startPolling();
  }

  /// Load job from database
  Future<void> _loadJob() async {
    try {
      final job = await _repository.getJobById(jobId);
      if (job != null) {
        state = state.copyWith(
          job: job,
          progress: job.progressPercentage,
        );

        // Stop polling if terminal state
        if (job.isTerminal) {
          _stopPolling();
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading job: $e');
      state = state.copyWith(error: e.toString());
    }
  }

  /// Start polling for job updates
  void _startPolling() {
    _subscription?.cancel();
    _subscription = _repository.subscribeToJob(jobId).listen(
      (job) {
        state = state.copyWith(
          job: job,
          progress: job.progressPercentage,
          isPolling: true,
        );

        debugPrint('🔄 Job update: ${job.status} (${job.progressPercentage}%)');

        // Stop polling if terminal state
        if (job.isTerminal) {
          _stopPolling();
        }
      },
      onError: (e) {
        debugPrint('❌ Job polling error: $e');
        state = state.copyWith(
          error: e.toString(),
          isPolling: false,
        );
      },
    );
  }

  /// Stop polling
  void _stopPolling() {
    _subscription?.cancel();
    _pollingTimer?.cancel();
    state = state.copyWith(isPolling: false);
    debugPrint('🛑 Stopped polling job: $jobId');
  }

  /// Manually refresh job
  Future<void> refresh() async {
    await _loadJob();
  }

  /// Cancel job
  Future<void> cancel() async {
    try {
      await _repository.cancelJob(jobId);
      await _loadJob();
    } catch (e) {
      debugPrint('❌ Error cancelling job: $e');
      state = state.copyWith(error: e.toString());
    }
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }
}

/// Provider family for tracking individual jobs
final aiJobTrackingProvider = StateNotifierProvider.family<AIJobTrackingNotifier, AIJobTrackingState, String>(
  (ref, jobId) {
    final repository = ref.watch(aiJobRepositoryProvider);
    return AIJobTrackingNotifier(repository, jobId);
  },
);

// ═══════════════════════════════════════════════════════════════════════════
// ACTIVE JOBS STREAM PROVIDER
// ═══════════════════════════════════════════════════════════════════════════

/// Stream provider for active jobs (queued or processing)
final activeJobsStreamProvider = StreamProvider<List<AIJob>>((ref) {
  final repository = ref.watch(aiJobRepositoryProvider);
  return repository.subscribeToUserJobs().map(
    (jobs) => jobs.where((job) => job.isActive).toList(),
  );
});

// ═══════════════════════════════════════════════════════════════════════════
// GENERATION BATCH (4-VARIANT GALLERY) PROVIDER
// ═══════════════════════════════════════════════════════════════════════════

/// Kicks off a 4-variant generation batch and returns its id for tracking.
final createBatchProvider = Provider<
    Future<String> Function({
      required String inputImageUrl,
      String? stoneId,
      String? stoneName,
      String? color,
      String? finish,
      Map<String, dynamic>? metadata,
    })>((ref) {
  final repository = ref.watch(aiJobRepositoryProvider);
  return ({
    required inputImageUrl,
    stoneId,
    stoneName,
    color,
    finish,
    metadata,
  }) async {
    final jobs = await repository.createVisualizationBatch(
      inputImageUrl: inputImageUrl,
      stoneId: stoneId,
      stoneName: stoneName,
      color: color,
      finish: finish,
      metadata: metadata,
    );
    return jobs.first.batchId!;
  };
});

/// Live view of the 4 jobs in a batch, reusing the same realtime
/// subscription as [activeJobsStreamProvider] rather than opening a new one.
/// Keeps only the newest job per variant slot, so retrying a variant
/// replaces its tile instead of adding a duplicate.
final batchTrackingProvider =
    StreamProvider.family<List<AIJob>, String>((ref, batchId) {
  final repository = ref.watch(aiJobRepositoryProvider);
  return repository.subscribeToUserJobs().map((jobs) {
    final byVariant = <int, AIJob>{};
    for (final job in jobs.where((j) => j.batchId == batchId)) {
      final existing = byVariant[job.variantIndex];
      if (existing == null || job.createdAt.isAfter(existing.createdAt)) {
        byVariant[job.variantIndex] = job;
      }
    }
    return byVariant.values.toList()
      ..sort((a, b) => a.variantIndex.compareTo(b.variantIndex));
  });
});

/// Provider for active jobs count
final activeJobsCountProvider = Provider<int>((ref) {
  final activeJobsAsync = ref.watch(activeJobsStreamProvider);
  return activeJobsAsync.when(
    data: (jobs) => jobs.length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

// ═══════════════════════════════════════════════════════════════════════════
// ROOM ANALYSIS PROVIDER
// ═══════════════════════════════════════════════════════════════════════════

/// Provider for room analysis
final roomAnalysisProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, imageUrl) async {
  final repository = ref.watch(aiJobRepositoryProvider);
  return repository.analyzeRoom(imageUrl: imageUrl);
});

// ═══════════════════════════════════════════════════════════════════════════
// ADMIN JOB STATISTICS PROVIDER
// ═══════════════════════════════════════════════════════════════════════════

/// Provider for admin job statistics
final adminJobStatisticsProvider = FutureProvider<Map<String, int>>((ref) async {
  final repository = ref.watch(aiJobRepositoryProvider);
  return repository.getJobStatistics();
});

/// Provider for all jobs (admin)
final adminAllJobsProvider = FutureProvider<List<AIJob>>((ref) async {
  final repository = ref.watch(aiJobRepositoryProvider);
  return repository.getAllJobs(limit: 200);
});
