class Stone {
  final String id;
  final String name;
  final String collection;
  final double pricePerSqFt;
  final String description;
  final String? imageUrl;
  final double rating;
  final int reviewCount;
  final String thickness;
  final String finish;
  final String size;
  final String origin;
  final List<String> availableColors;
  final bool isTrending;

  const Stone({
    required this.id,
    required this.name,
    required this.collection,
    required this.pricePerSqFt,
    required this.description,
    this.imageUrl,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.thickness = '',
    this.finish = '',
    this.size = '',
    this.origin = '',
    this.availableColors = const [],
    this.isTrending = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'collection': collection,
    'pricePerSqFt': pricePerSqFt,
    'description': description,
    'imageUrl': imageUrl,
    'rating': rating,
    'reviewCount': reviewCount,
    'thickness': thickness,
    'finish': finish,
    'size': size,
    'origin': origin,
    'availableColors': availableColors,
    'isTrending': isTrending,
  };

  factory Stone.fromJson(Map<String, dynamic> json) => Stone.fromMap(json);

  Map<String, dynamic> toJson() => toMap();

  factory Stone.fromMap(Map<String, dynamic> map) => Stone(
    id: map['id'] ?? '',
    name: map['name'] ?? '',
    collection: map['collection'] ?? '',
    pricePerSqFt: (map['pricePerSqFt'] ?? 0).toDouble(),
    description: map['description'] ?? '',
    imageUrl: map['imageUrl'],
    rating: (map['rating'] ?? 0).toDouble(),
    reviewCount: map['reviewCount'] ?? 0,
    thickness: map['thickness'] ?? '',
    finish: map['finish'] ?? '',
    size: map['size'] ?? '',
    origin: map['origin'] ?? '',
    availableColors: List<String>.from(map['availableColors'] ?? []),
    isTrending: map['isTrending'] ?? false,
  );

  Stone copyWith({
    String? id,
    String? name,
    String? collection,
    double? pricePerSqFt,
    String? description,
    String? imageUrl,
    double? rating,
    int? reviewCount,
    String? thickness,
    String? finish,
    String? size,
    String? origin,
    List<String>? availableColors,
    bool? isTrending,
  }) => Stone(
    id: id ?? this.id,
    name: name ?? this.name,
    collection: collection ?? this.collection,
    pricePerSqFt: pricePerSqFt ?? this.pricePerSqFt,
    description: description ?? this.description,
    imageUrl: imageUrl ?? this.imageUrl,
    rating: rating ?? this.rating,
    reviewCount: reviewCount ?? this.reviewCount,
    thickness: thickness ?? this.thickness,
    finish: finish ?? this.finish,
    size: size ?? this.size,
    origin: origin ?? this.origin,
    availableColors: availableColors ?? this.availableColors,
    isTrending: isTrending ?? this.isTrending,
  );
}
