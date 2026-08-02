import 'stone.dart';

class WishlistItem {
  final String id;
  final Stone stone;
  final DateTime addedAt;

  const WishlistItem({
    required this.id,
    required this.stone,
    required this.addedAt,
  });

  factory WishlistItem.fromJson(Map<String, dynamic> json) => WishlistItem(
    id: json['id'] ?? '',
    stone: Stone.fromJson(json['stone'] ?? {}),
    addedAt: DateTime.parse(json['addedAt'] ?? DateTime.now().toIso8601String()),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'stone': stone.toJson(),
    'addedAt': addedAt.toIso8601String(),
  };
}
