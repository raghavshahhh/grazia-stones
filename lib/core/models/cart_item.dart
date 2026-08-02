class CartItem {
  final String stoneId;
  final String name;
  final String finish;
  final double pricePerSqFt;
  final int quantity;
  final String colorHex;

  const CartItem({
    required this.stoneId,
    required this.name,
    required this.finish,
    required this.pricePerSqFt,
    this.quantity = 1,
    this.colorHex = '#1C1C1E',
  });

  double get totalPrice => pricePerSqFt * quantity;

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
    stoneId: json['stoneId'] ?? '',
    name: json['name'] ?? '',
    finish: json['finish'] ?? '',
    pricePerSqFt: (json['pricePerSqFt'] ?? 0).toDouble(),
    quantity: json['quantity'] ?? 1,
    colorHex: json['colorHex'] ?? '#1C1C1E',
  );

  Map<String, dynamic> toJson() => {
    'stoneId': stoneId,
    'name': name,
    'finish': finish,
    'pricePerSqFt': pricePerSqFt,
    'quantity': quantity,
    'colorHex': colorHex,
  };

  CartItem copyWith({
    String? stoneId,
    String? name,
    String? finish,
    double? pricePerSqFt,
    int? quantity,
    String? colorHex,
  }) => CartItem(
    stoneId: stoneId ?? this.stoneId,
    name: name ?? this.name,
    finish: finish ?? this.finish,
    pricePerSqFt: pricePerSqFt ?? this.pricePerSqFt,
    quantity: quantity ?? this.quantity,
    colorHex: colorHex ?? this.colorHex,
  );
}
