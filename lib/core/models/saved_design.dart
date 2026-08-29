/// Model for saved AI visualization designs
/// 
/// Represents a user's saved room visualization with stone application
/// Stored in saved_designs table with images in ai-visualizations bucket
class SavedDesign {
  final String id;
  final String userId;
  final String? stoneId;
  final String stoneName;
  final String? roomImageUrl; // Original room image (Supabase Storage URL)
  final String generatedImageUrl; // AI-generated visualization (Supabase Storage URL)
  final String? color;
  final String? finish;
  final String? notes;
  final DateTime createdAt;

  const SavedDesign({
    required this.id,
    required this.userId,
    this.stoneId,
    required this.stoneName,
    this.roomImageUrl,
    required this.generatedImageUrl,
    this.color,
    this.finish,
    this.notes,
    required this.createdAt,
  });

  factory SavedDesign.fromJson(Map<String, dynamic> json) {
    return SavedDesign(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      stoneId: json['stone_id'] as String?,
      stoneName: json['stone_name'] as String,
      roomImageUrl: json['room_image_url'] as String?,
      generatedImageUrl: json['generated_image_url'] as String,
      color: json['color'] as String?,
      finish: json['finish'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'stone_id': stoneId,
      'stone_name': stoneName,
      'room_image_url': roomImageUrl,
      'generated_image_url': generatedImageUrl,
      'color': color,
      'finish': finish,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  SavedDesign copyWith({
    String? id,
    String? userId,
    String? stoneId,
    String? stoneName,
    String? roomImageUrl,
    String? generatedImageUrl,
    String? color,
    String? finish,
    String? notes,
    DateTime? createdAt,
  }) {
    return SavedDesign(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      stoneId: stoneId ?? this.stoneId,
      stoneName: stoneName ?? this.stoneName,
      roomImageUrl: roomImageUrl ?? this.roomImageUrl,
      generatedImageUrl: generatedImageUrl ?? this.generatedImageUrl,
      color: color ?? this.color,
      finish: finish ?? this.finish,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Get formatted creation date
  String getFormattedDate() {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }

  /// Check if this design has a room image
  bool get hasRoomImage => roomImageUrl != null && roomImageUrl!.isNotEmpty;

  /// Check if this design has stone association
  bool get hasStone => stoneId != null;

  /// Get display title
  String get displayTitle {
    if (notes != null && notes!.isNotEmpty) {
      return notes!;
    }
    return '$stoneName Visualization';
  }
}
