class QuoteRequest {
  final String id;
  final String stoneName;
  final String finish;
  final String area;
  final String notes;
  final String status;
  final DateTime createdAt;

  const QuoteRequest({
    required this.id,
    required this.stoneName,
    required this.finish,
    required this.area,
    this.notes = '',
    this.status = 'Pending',
    required this.createdAt,
  });

  factory QuoteRequest.fromJson(Map<String, dynamic> json) => QuoteRequest(
    id: json['id']?.toString() ?? '',
    stoneName: (json['stone_name'] ?? json['stoneName'])?.toString() ?? 'Architectural Stone',
    finish: json['finish']?.toString() ?? 'Natural',
    area: (json['area_sqft'] ?? json['area'])?.toString() ?? '150 sq.ft.',
    notes: (json['message'] ?? json['notes'])?.toString() ?? '',
    status: json['status']?.toString() ?? 'Pending',
    createdAt: DateTime.tryParse((json['created_at'] ?? json['createdAt'])?.toString() ?? '') ?? DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'stoneName': stoneName,
    'finish': finish,
    'area': area,
    'notes': notes,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
  };

  QuoteRequest copyWith({
    String? id,
    String? stoneName,
    String? finish,
    String? area,
    String? notes,
    String? status,
    DateTime? createdAt,
  }) => QuoteRequest(
    id: id ?? this.id,
    stoneName: stoneName ?? this.stoneName,
    finish: finish ?? this.finish,
    area: area ?? this.area,
    notes: notes ?? this.notes,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
  );
}
