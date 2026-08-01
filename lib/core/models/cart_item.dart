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
