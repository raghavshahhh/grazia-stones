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
        if (stoneId != null) 'stone_id': stoneId,
        if (stoneName != null) 'stone_name': stoneName,
        if (color != null) 'color': color,
        if (finish != null) 'finish': finish,
        if (metadata != null) 'metadata': metadata,
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
        if (metadata != null) 'metadata': metadata,
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

  /// Subscribe to job updates via Supabase real-time
  /// 
  /// Returns a stream of job updates for real-time UI
  Stream<AIJob> subscribeToJob(String jobId) {
    final controller = StreamController<AIJob>();

    // Initial fetch
    getJobById(jobId).then((job) {
      if (job != null) {
        controller.add(job);
      }
    });

    // Subscribe to changes
    final subscription = _client
        .from('ai_jobs')
        .stream(primaryKey: ['id'])
        .eq('id', jobId)
        .listen((data) {
          if (data.isNotEmpty) {
            final job = AIJob.fromJson(data.first as Map<String, dynamic>);
            controller.add(job);
          }
        });

    controller.onCancel = () {
      subscription.cancel();
    };

    return controller.stream;
  }

  /// Subscribe to all user jobs for real-time updates
  Stream<List<AIJob>> subscribeToUserJobs() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return Stream.value([]);
    }

    return _client
        .from('ai_jobs')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((data) => 
          (data as List)
              .map((json) => AIJob.fromJson(json as Map<String, dynamic>))
              .toList()
        );
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
        'variantIndex': 0,
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
          if (imageBase64 != null) 'imageBase64': imageBase64,
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
