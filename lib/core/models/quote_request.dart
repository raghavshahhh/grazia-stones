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
