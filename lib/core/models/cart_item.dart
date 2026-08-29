class CartItem {
  final String? id; // Database ID for Supabase cart_items table
  final String stoneId;
  final String name;
  final String finish;
  final double pricePerSqFt;
  final int quantity;
  final String colorHex;

  const CartItem({
    this.id,
    required this.stoneId,
    required this.name,
    required this.finish,
    required this.pricePerSqFt,
    this.quantity = 1,
    this.colorHex = '#1C1C1E',
  });

  double get totalPrice => pricePerSqFt * quantity;

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
    id: json['id'],
    stoneId: json['stone_id'] ?? json['stoneId'] ?? '',
    name: json['stone_name'] ?? json['name'] ?? '',
    finish: json['finish'] ?? 'Polished',
    pricePerSqFt: ((json['price_per_unit'] ?? json['pricePerSqFt'] ?? 0) as num).toDouble(),
    quantity: (json['quantity'] ?? 1) as int,
    colorHex: json['color_hex'] ?? json['colorHex'] ?? '#1C1C1E',
  );

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'stone_id': stoneId,
    'stone_name': name,
    'finish': finish,
    'price_per_unit': pricePerSqFt,
    'quantity': quantity,
    'color_hex': colorHex,
  };

  CartItem copyWith({
    String? id,
    String? stoneId,
    String? name,
    String? finish,
    double? pricePerSqFt,
    int? quantity,
    String? colorHex,
  }) => CartItem(
    id: id ?? this.id,
    stoneId: stoneId ?? this.stoneId,
    name: name ?? this.name,
    finish: finish ?? this.finish,
    pricePerSqFt: pricePerSqFt ?? this.pricePerSqFt,
    quantity: quantity ?? this.quantity,
    colorHex: colorHex ?? this.colorHex,
  );
}
