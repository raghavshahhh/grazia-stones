import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:grazia_stones/core/models/ai_job.dart';
import 'package:grazia_stones/core/services/ai_endpoint_client.dart';
import 'package:grazia_stones/core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for AI job queue management
/// 
/// Handles:
/// - Creating visualization jobs
/// - Fetching job status
/// - Real-time job updates via Supabase subscriptions
/// - Job polling for status changes
class AIJobRepository {
  final SupabaseClient _client;

  AIJobRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.instance.client;

  // ═══════════════════════════════════════════════════════════════════════════
  // JOB CREATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Create a new AI visualization job
  /// 
  /// Returns the created job with ID for tracking
  Future<AIJob> createVisualizationJob({
    required String inputImageUrl,
    String? stoneId,
    String? stoneName,
    String? color,
    String? finish,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      debugPrint('📤 Creating AI visualization job...');
      
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final data = {
        'user_id': userId,
        'job_type': AIJobType.visualization.value,
        'status': AIJobStatus.queued.value,
        'input_image_url': inputImageUrl,
        'stone_id': ?stoneId,
        'stone_name': ?stoneName,
        'color': ?color,
        'finish': ?finish,
        'metadata': ?metadata,
      };

      final response = await _client
          .from('ai_jobs')
          .insert(data)
          .select()
          .single();

      final job = AIJob.fromJson(response);
      debugPrint('✅ AI job created: ${job.id}');
      
      return job;
    } catch (e) {
      debugPrint('❌ Error creating AI job: $e');
      rethrow;
    }
  }

  /// Create a room analysis job
  Future<AIJob> createRoomAnalysisJob({
    required String inputImageUrl,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      debugPrint('📤 Creating room analysis job...');
      
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final data = {
        'user_id': userId,
        'job_type': AIJobType.roomAnalysis.value,
        'status': AIJobStatus.queued.value,
        'input_image_url': inputImageUrl,
        'metadata': ?metadata,
      };

      final response = await _client
          .from('ai_jobs')
          .insert(data)
          .select()
          .single();

      final job = AIJob.fromJson(response);
      debugPrint('✅ Room analysis job created: ${job.id}');
      
      return job;
    } catch (e) {
      debugPrint('❌ Error creating room analysis job: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // JOB RETRIEVAL
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get all jobs for current user
  Future<List<AIJob>> getJobs({
    String? status,
    String? jobType,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      debugPrint('📥 Fetching AI jobs (status: $status, type: $jobType)...');
      
      var query = _client.from('ai_jobs').select();

      if (status != null) {
        query = query.eq('status', status);
      }

      if (jobType != null) {
        query = query.eq('job_type', jobType);
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final jobs = (response as List)
          .map((json) => AIJob.fromJson(json as Map<String, dynamic>))
          .toList();

      debugPrint('✅ Fetched ${jobs.length} AI jobs');
      return jobs;
    } catch (e) {
      debugPrint('❌ Error fetching AI jobs: $e');
      return [];
    }
  }

  /// Get active jobs (queued or processing)
  Future<List<AIJob>> getActiveJobs() async {
    return getJobs(status: null).then((jobs) => 
      jobs.where((job) => job.isActive).toList()
    );
  }

  /// Get job by ID
  Future<AIJob?> getJobById(String jobId) async {
    try {
      debugPrint('📥 Fetching AI job: $jobId');
      
      final response = await _client
          .from('ai_jobs')
          .select()
          .eq('id', jobId)
          .single();

      final job = AIJob.fromJson(response);
      debugPrint('✅ Fetched AI job: ${job.id} (status: ${job.status})');
      
      return job;
    } catch (e) {
      debugPrint('❌ Error fetching AI job: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // JOB STATUS UPDATES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Update job status
  Future<void> updateJobStatus({
    required String jobId,
    required String status,
    String? errorMessage,
    String? resultImageUrl,
    int? processingTimeMs,
  }) async {
    try {
      debugPrint('📤 Updating AI job status: $jobId -> $status');
      
      final data = <String, dynamic>{
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (status == AIJobStatus.processing.value) {
        data['started_at'] = DateTime.now().toIso8601String();
      }

      if (status == AIJobStatus.completed.value || 
          status == AIJobStatus.failed.value ||
          status == AIJobStatus.cancelled.value) {
        data['completed_at'] = DateTime.now().toIso8601String();
      }

      if (errorMessage != null) {
        data['error_message'] = errorMessage;
      }

      if (resultImageUrl != null) {
        data['result_image_url'] = resultImageUrl;
      }

      if (processingTimeMs != null) {
        data['processing_time_ms'] = processingTimeMs;
      }

      await _client
          .from('ai_jobs')
          .update(data)
          .eq('id', jobId);

      debugPrint('✅ AI job status updated');
    } catch (e) {
      debugPrint('❌ Error updating AI job status: $e');
      rethrow;
    }
  }

  /// Cancel a job
  Future<void> cancelJob(String jobId) async {
    await updateJobStatus(
      jobId: jobId,
      status: AIJobStatus.cancelled.value,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // JOB POLLING & REAL-TIME UPDATES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Poll job status until completion or timeout
  /// 
  /// Returns a stream of job updates
  Stream<AIJob> pollJobStatus({
    required String jobId,
    Duration interval = const Duration(seconds: 2),
    Duration timeout = const Duration(minutes: 5),
  }) async* {
    final startTime = DateTime.now();
    
    while (true) {
      // Check timeout
      if (DateTime.now().difference(startTime) > timeout) {
        debugPrint('⏰ Job polling timeout: $jobId');
        break;
      }

      // Fetch current status
      final job = await getJobById(jobId);
      if (job != null) {
        yield job;
        
        // Stop if terminal state
        if (job.isTerminal) {
          debugPrint('🏁 Job reached terminal state: ${job.status}');
          break;
        }
      }

      // Wait before next poll
      await Future.delayed(interval);
    }
  }

  /// Subscribe to job updates via Supabase real-time with automatic polling fallback
  Stream<AIJob> subscribeToJob(String jobId) {
    late StreamController<AIJob> controller;
    Timer? pollingTimer;
    StreamSubscription? subscription;
    bool isRealtimeActive = false;

    Future<void> fetchOnce() async {
      try {
        final job = await getJobById(jobId);
        if (job != null && !controller.isClosed) {
          controller.add(job);
          if (job.isTerminal) {
            pollingTimer?.cancel();
            pollingTimer = null;
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error fetching job $jobId: $e');
      }
    }

    void startPollingFallback() {
      if (pollingTimer != null) return;
      debugPrint('🔄 Using polling fallback for AI job $jobId');
      fetchOnce();
      pollingTimer = Timer.periodic(const Duration(milliseconds: 2000), (_) {
        if (!controller.isClosed) {
          fetchOnce();
        }
      });
    }

    controller = StreamController<AIJob>(
      onListen: () {
        fetchOnce();

        try {
          subscription = _client
              .from('ai_jobs')
              .stream(primaryKey: ['id'])
              .eq('id', jobId)
              .listen(
                (data) {
                  if (data.isNotEmpty) {
                    isRealtimeActive = true;
                    pollingTimer?.cancel();
                    pollingTimer = null;
                    if (!controller.isClosed) {
                      final job = AIJob.fromJson(data.first);
                      controller.add(job);
                    }
                  }
                },
                onError: (error) {
                  debugPrint('⚠️ Realtime error for job $jobId: $error. Falling back to polling.');
                  startPollingFallback();
                },
                cancelOnError: false,
              );
        } catch (e) {
          debugPrint('⚠️ Realtime stream setup error for job $jobId: $e');
          startPollingFallback();
        }

        Future.delayed(const Duration(seconds: 3), () {
          if (!isRealtimeActive && !controller.isClosed) {
            startPollingFallback();
          }
        });
      },
      onCancel: () {
        subscription?.cancel();
        pollingTimer?.cancel();
      },
    );

    return controller.stream;
  }

  /// Subscribe to all user jobs with automatic REST polling fallback if Realtime fails
  Stream<List<AIJob>> subscribeToUserJobs() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return Stream.value([]);
    }

    late StreamController<List<AIJob>> controller;
    Timer? pollingTimer;
    StreamSubscription? streamSub;
    bool isRealtimeActive = false;

    Future<void> fetchOnce() async {
      try {
        final jobs = await getJobs(limit: 50);
        if (!controller.isClosed) {
          controller.add(jobs);
        }
      } catch (e) {
        debugPrint('⚠️ Error in fetchOnce for AI jobs: $e');
      }
    }

    void startPollingFallback() {
      if (pollingTimer != null) return;
      debugPrint('🔄 Realtime unavailable for ai_jobs. Using REST polling fallback.');
      fetchOnce();
      pollingTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
        if (!controller.isClosed) {
          fetchOnce();
        }
      });
    }

    controller = StreamController<List<AIJob>>(
      onListen: () {
        // Immediate fetch so UI has data right away
        fetchOnce();

        try {
          streamSub = _client
              .from('ai_jobs')
              .stream(primaryKey: ['id'])
              .eq('user_id', userId)
              .order('created_at', ascending: false)
              .listen(
                (data) {
                  isRealtimeActive = true;
                  pollingTimer?.cancel();
                  pollingTimer = null;
                  if (!controller.isClosed) {
                    final jobs = (data as List)
                        .map((json) => AIJob.fromJson(json as Map<String, dynamic>))
                        .toList();
                    controller.add(jobs);
                  }
                },
                onError: (error) {
                  debugPrint('⚠️ Realtime subscription error on ai_jobs: $error. Falling back to REST polling.');
                  startPollingFallback();
                },
                cancelOnError: false,
              );
        } catch (e) {
          debugPrint('⚠️ Exception creating stream: $e. Falling back to REST polling.');
          startPollingFallback();
        }

        // Safety fallback: if realtime never emits within 3s, start polling
        Future.delayed(const Duration(seconds: 3), () {
          if (!isRealtimeActive && !controller.isClosed) {
            startPollingFallback();
          }
        });
      },
      onCancel: () {
        streamSub?.cancel();
        pollingTimer?.cancel();
      },
    );

    return controller.stream;
  }

  /// Subscribe specifically to all jobs belonging to a generation batch
  Stream<List<AIJob>> subscribeToBatchJobs(String batchId) {
    late StreamController<List<AIJob>> controller;
    Timer? pollingTimer;
    StreamSubscription? streamSub;

    Future<void> fetchBatch() async {
      try {
        final jobs = await getJobsByBatch(batchId);
        if (!controller.isClosed && jobs.isNotEmpty) {
          controller.add(jobs);
          // If all 4 are in terminal state (completed or failed), stop polling
          if (jobs.length >= 4 && jobs.every((j) => j.isTerminal)) {
            pollingTimer?.cancel();
            pollingTimer = null;
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error fetching batch $batchId: $e');
      }
    }

    controller = StreamController<List<AIJob>>(
      onListen: () {
        // Immediate fetch
        fetchBatch();

        // Poll every 2 seconds while jobs are processing
        pollingTimer = Timer.periodic(const Duration(milliseconds: 2000), (_) {
          if (!controller.isClosed) {
            fetchBatch();
          }
        });

        // Also listen to user jobs stream if possible
        try {
          streamSub = subscribeToUserJobs().listen((allJobs) {
            final batchJobs = allJobs.where((j) => j.batchId == batchId).toList();
            if (batchJobs.isNotEmpty && !controller.isClosed) {
              controller.add(batchJobs);
              if (batchJobs.length >= 4 && batchJobs.every((j) => j.isTerminal)) {
                pollingTimer?.cancel();
                pollingTimer = null;
              }
            }
          }, onError: (_) {});
        } catch (_) {}
      },
      onCancel: () {
        streamSub?.cancel();
        pollingTimer?.cancel();
      },
    );

    return controller.stream;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // JOB PROCESSING (api/generate-visualization — Gemini image generation)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Run AI generation for a queued job and persist the result.
  ///
  /// This calls api/generate-visualization directly (no Supabase Edge
  /// Function involved — none is deployed for this project). Every path,
  /// including a missing GEMINI_API_KEY, ends the job in 'completed' or
  /// 'failed' so the realtime job tracker never hangs on 'queued'.
  Future<void> processJob(String jobId) async {
    final startedAt = DateTime.now();
    try {
      debugPrint('🚀 Processing AI job: $jobId');

      final job = await getJobById(jobId);
      if (job == null) throw Exception('Job not found');

      await updateJobStatus(jobId: jobId, status: AIJobStatus.processing.value);

      final imageResponse = await Dio().get<List<int>>(
        job.inputImageUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      final inputBytes = imageResponse.data!;
      final inputDataUrl = 'data:image/jpeg;base64,${base64Encode(inputBytes)}';

      final data = await AIEndpointClient.post('/api/generate-visualization', {
        'image': inputDataUrl,
        'stoneName': job.stoneName ?? 'Architectural Stone',
        'color': job.color,
        'finish': job.finish,
        'variantIndex': job.variantIndex,
      });

      final resultDataUrl = data['resultImage'] as String?;
      if (resultDataUrl == null) {
        throw Exception(data['error'] ?? 'Generation did not return an image');
      }

      final resultBase64 = resultDataUrl.split(',').last;
      final resultBytes = base64Decode(resultBase64);
      final resultFileName = 'result_${jobId}_${DateTime.now().millisecondsSinceEpoch}.png';
      await _client.storage.from('ai-visualizations').uploadBinary(
            'results/$resultFileName',
            resultBytes,
            fileOptions: const FileOptions(contentType: 'image/png'),
          );
      final resultImageUrl = _client.storage
          .from('ai-visualizations')
          .getPublicUrl('results/$resultFileName');

      await updateJobStatus(
        jobId: jobId,
        status: AIJobStatus.completed.value,
        resultImageUrl: resultImageUrl,
        processingTimeMs: DateTime.now().difference(startedAt).inMilliseconds,
      );

      debugPrint('✅ AI job completed: $jobId');
    } catch (e) {
      debugPrint('❌ Error processing AI job: $e');
      await updateJobStatus(
        jobId: jobId,
        status: AIJobStatus.failed.value,
        errorMessage: e.toString(),
        processingTimeMs: DateTime.now().difference(startedAt).inMilliseconds,
      );
      rethrow;
    }
  }

  /// Create the 4 variant jobs for a single "Generate" tap, sharing a
  /// batch_id so the UI can group and track them together. Each variant
  /// gets a distinct prompt angle server-side (see VARIANT_PROMPTS in
  /// api/generate-visualization.js) — never the same image 4 times.
  Future<List<AIJob>> createVisualizationBatch({
    required String inputImageUrl,
    String? stoneId,
    String? stoneName,
    String? color,
    String? finish,
    Map<String, dynamic>? metadata,
  }) async {
    final batchId = DateTime.now().microsecondsSinceEpoch.toString();

    final jobs = await Future.wait(List.generate(4, (variantIndex) {
      return createVisualizationJob(
        inputImageUrl: inputImageUrl,
        stoneId: stoneId,
        stoneName: stoneName,
        color: color,
        finish: finish,
        metadata: {
          ...?metadata,
          'batch_id': batchId,
          'variant_index': variantIndex,
        },
      );
    }));

    // Process concurrently — each is an independent Gemini call.
    for (final job in jobs) {
      unawaited(processJob(job.id).catchError((_) {}));
    }

    return jobs;
  }

  /// All jobs belonging to one generation batch, for the result gallery.
  Future<List<AIJob>> getJobsByBatch(String batchId) async {
    try {
      final response = await _client
          .from('ai_jobs')
          .select()
          .contains('metadata', {'batch_id': batchId}).order('created_at');
      final jobs = (response as List)
          .map((json) => AIJob.fromJson(json as Map<String, dynamic>))
          .toList();
      if (jobs.isNotEmpty) return jobs;
    } catch (e) {
      debugPrint('⚠️ Error querying jobs by metadata contains: $e');
    }

    // Resilient fallback: fetch recent jobs and filter locally
    try {
      final allUserJobs = await getJobs(limit: 50);
      return allUserJobs.where((j) => j.batchId == batchId).toList();
    } catch (e) {
      debugPrint('⚠️ Fallback getJobsByBatch failed: $e');
      return [];
    }
  }

  /// Trigger room analysis via Edge Function
  Future<Map<String, dynamic>> analyzeRoom({
    required String imageUrl,
    String? imageBase64,
  }) async {
    try {
      debugPrint('🔍 Triggering room analysis...');
      
      final response = await _client.functions.invoke(
        'analyze-room',
        body: {
          'imageUrl': imageUrl,
          'imageBase64': ?imageBase64,
        },
      );

      if (response.status != 200) {
        final error = response.data?['error'] ?? 'Unknown error';
        throw Exception('Room analysis error: $error');
      }

      final data = response.data as Map<String, dynamic>;
      debugPrint('✅ Room analysis complete: ${data['message']}');
      
      return data;
    } catch (e) {
      debugPrint('❌ Error analyzing room: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ADMIN OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get all jobs (admin only)
  Future<List<AIJob>> getAllJobs({
    String? status,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      debugPrint('📥 Fetching all AI jobs (admin)...');
      
      var query = _client.from('ai_jobs').select();

      if (status != null) {
        query = query.eq('status', status);
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final jobs = (response as List)
          .map((json) => AIJob.fromJson(json as Map<String, dynamic>))
          .toList();

      debugPrint('✅ Fetched ${jobs.length} AI jobs (admin)');
      return jobs;
    } catch (e) {
      debugPrint('❌ Error fetching all AI jobs: $e');
      return [];
    }
  }

  /// Get job statistics (admin only)
  Future<Map<String, int>> getJobStatistics() async {
    try {
      final jobs = await getAllJobs(limit: 1000);
      
      final stats = <String, int>{
        'total': jobs.length,
        'queued': jobs.where((j) => j.status == 'queued').length,
        'processing': jobs.where((j) => j.status == 'processing').length,
        'completed': jobs.where((j) => j.status == 'completed').length,
        'failed': jobs.where((j) => j.status == 'failed').length,
        'cancelled': jobs.where((j) => j.status == 'cancelled').length,
      };

      return stats;
    } catch (e) {
      debugPrint('❌ Error getting job statistics: $e');
      return {};
    }
  }

  /// Retry a failed job
  Future<AIJob> retryJob(String jobId) async {
    try {
      debugPrint('🔄 Retrying failed job: $jobId');
      
      final oldJob = await getJobById(jobId);
      if (oldJob == null) {
        throw Exception('Job not found');
      }

      // Create new job with same parameters
      final newJob = await createVisualizationJob(
        inputImageUrl: oldJob.inputImageUrl,
        stoneId: oldJob.stoneId,
        stoneName: oldJob.stoneName,
        color: oldJob.color,
        finish: oldJob.finish,
        metadata: {
          ...?oldJob.metadata,
          'retried_from': jobId,
        },
      );

      debugPrint('✅ Job retried: ${newJob.id}');
      return newJob;
    } catch (e) {
      debugPrint('❌ Error retrying job: $e');
      rethrow;
    }
  }
}
