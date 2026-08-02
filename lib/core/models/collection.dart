class Collection {
  final String id;
  final String name;
  final String description;
  final int stoneCount;

  const Collection({
    required this.id,
    required this.name,
    required this.description,
    this.stoneCount = 0,
  });

  factory Collection.fromJson(Map<String, dynamic> json) => Collection.fromMap(json);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'stoneCount': stoneCount,
  };

  factory Collection.fromMap(Map<String, dynamic> map) => Collection(
    id: map['id'] ?? '',
    name: map['name'] ?? '',
    description: map['description'] ?? '',
    stoneCount: map['stoneCount'] ?? 0,
  );
}
