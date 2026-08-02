class Order {
  final String id;
  final List<String> stoneNames;
  final double totalAmount;
  final String status;
  final DateTime createdAt;

  const Order({
    required this.id,
    required this.stoneNames,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
  });

  factory Order.fromMap(Map<String, dynamic> map) => Order(
    id: map['id'] ?? '',
    stoneNames: List<String>.from(map['stoneNames'] ?? []),
    totalAmount: (map['totalAmount'] ?? 0).toDouble(),
    status: map['status'] ?? 'Pending',
    createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
  );

  factory Order.fromJson(Map<String, dynamic> json) => Order.fromMap(json);

  Map<String, dynamic> toJson() => {
    'id': id,
    'stoneNames': stoneNames,
    'totalAmount': totalAmount,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
  };
}
