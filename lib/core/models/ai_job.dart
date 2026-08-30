/// AI Job model for job queue system
class AIJob {
  final String id;
  final String? userId;
  final String jobType;
  final String status;
  final String inputImageUrl;
  final String? stoneId;
  final String? stoneName;
  final String? color;
  final String? finish;
  final String? resultImageUrl;
  final String? errorMessage;
  final Map<String, dynamic>? metadata;
  final int? processingTimeMs;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime updatedAt;

  const AIJob({
    required this.id,
    this.userId,
    required this.jobType,
    required this.status,
    required this.inputImageUrl,
    this.stoneId,
    this.stoneName,
    this.color,
    this.finish,
    this.resultImageUrl,
    this.errorMessage,
    this.metadata,
    this.processingTimeMs,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    required this.updatedAt,
  });

  factory AIJob.fromJson(Map<String, dynamic> json) {
    return AIJob(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      jobType: json['job_type'] as String,
      status: json['status'] as String,
      inputImageUrl: json['input_image_url'] as String,
      stoneId: json['stone_id'] as String?,
      stoneName: json['stone_name'] as String?,
      color: json['color'] as String?,
      finish: json['finish'] as String?,
      resultImageUrl: json['result_image_url'] as String?,
      errorMessage: json['error_message'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      processingTimeMs: json['processing_time_ms'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      startedAt: json['started_at'] != null 
          ? DateTime.parse(json['started_at'] as String) 
          : null,
      completedAt: json['completed_at'] != null 
          ? DateTime.parse(json['completed_at'] as String) 
          : null,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'job_type': jobType,
      'status': status,
      'input_image_url': inputImageUrl,
      'stone_id': stoneId,
      'stone_name': stoneName,
      'color': color,
      'finish': finish,
      'result_image_url': resultImageUrl,
      'error_message': errorMessage,
      'metadata': metadata,
      'processing_time_ms': processingTimeMs,
      'created_at': createdAt.toIso8601String(),
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  AIJob copyWith({
    String? id,
    String? userId,
    String? jobType,
    String? status,
    String? inputImageUrl,
    String? stoneId,
    String? stoneName,
    String? color,
    String? finish,
    String? resultImageUrl,
    String? errorMessage,
    Map<String, dynamic>? metadata,
    int? processingTimeMs,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? updatedAt,
  }) {
    return AIJob(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      jobType: jobType ?? this.jobType,
      status: status ?? this.status,
      inputImageUrl: inputImageUrl ?? this.inputImageUrl,
      stoneId: stoneId ?? this.stoneId,
      stoneName: stoneName ?? this.stoneName,
      color: color ?? this.color,
      finish: finish ?? this.finish,
      resultImageUrl: resultImageUrl ?? this.resultImageUrl,
      errorMessage: errorMessage ?? this.errorMessage,
      metadata: metadata ?? this.metadata,
      processingTimeMs: processingTimeMs ?? this.processingTimeMs,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

extension AIJobX on AIJob {
  /// Groups the 4 variants of a single "Generate" tap together.
  /// Stored in `metadata` rather than a new column — a job either belongs
  /// to a batch or it doesn't, no need to widen the schema for it.
  String? get batchId => metadata?['batch_id'] as String?;

  /// Which of the 4 variants (0-3) this job is.
  int get variantIndex => (metadata?['variant_index'] as num?)?.toInt() ?? 0;

  /// Check if job is in a terminal state
  bool get isTerminal => status == 'completed' || status == 'failed' || status == 'cancelled';
  
  /// Check if job is active (queued or processing)
  bool get isActive => status == 'queued' || status == 'processing';
  
  /// Check if job was successful
  bool get isSuccessful => status == 'completed' && resultImageUrl != null;
  
  /// Get human-readable status
  String get readableStatus {
    switch (status) {
      case 'queued':
        return 'Queued';
      case 'processing':
        return 'Processing';
      case 'completed':
        return 'Completed';
      case 'failed':
        return 'Failed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }
  
  /// Get status icon
  String get statusIcon {
    switch (status) {
      case 'queued':
        return '⏳';
      case 'processing':
        return '⚙️';
      case 'completed':
        return '✅';
      case 'failed':
        return '❌';
      case 'cancelled':
        return '🚫';
      default:
        return '❓';
    }
  }
  
  /// Get formatted processing time
  String get formattedProcessingTime {
    if (processingTimeMs == null) return '--';
    final seconds = processingTimeMs! / 1000;
    if (seconds < 60) {
      return '${seconds.toStringAsFixed(1)}s';
    }
    final minutes = seconds / 60;
    return '${minutes.toStringAsFixed(1)}m';
  }
  
  /// Get progress percentage (0-100)
  double get progressPercentage {
    switch (status) {
      case 'queued':
        return 10.0;
      case 'processing':
        return 50.0;
      case 'completed':
        return 100.0;
      case 'failed':
      case 'cancelled':
        return 0.0;
      default:
        return 0.0;
    }
  }
  
  /// Get time elapsed since creation
  Duration get elapsedTime {
    final endTime = completedAt ?? DateTime.now();
    return endTime.difference(createdAt);
  }
  
  /// Get formatted elapsed time
  String get formattedElapsedTime {
    final elapsed = elapsedTime;
    if (elapsed.inSeconds < 60) {
      return '${elapsed.inSeconds}s';
    } else if (elapsed.inMinutes < 60) {
      return '${elapsed.inMinutes}m ${elapsed.inSeconds % 60}s';
    } else {
      return '${elapsed.inHours}h ${elapsed.inMinutes % 60}m';
    }
  }
}

/// AI Job Type enum
enum AIJobType {
  visualization('visualization'),
  roomAnalysis('room_analysis'),
  materialDetection('material_detection');

  final String value;
  const AIJobType(this.value);
}

/// AI Job Status enum
enum AIJobStatus {
  queued('queued'),
  processing('processing'),
  completed('completed'),
  failed('failed'),
  cancelled('cancelled');

  final String value;
  const AIJobStatus(this.value);
}
