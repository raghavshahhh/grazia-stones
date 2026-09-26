class Collection {
  final String id;
  final String name;
  final String description;
  final String? imageUrl;
  final int stoneCount;

  const Collection({
    required this.id,
    required this.name,
    required this.description,
    this.imageUrl,
    this.stoneCount = 0,
  });

  factory Collection.fromJson(Map<String, dynamic> json) => Collection.fromMap(json);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'imageUrl': imageUrl,
    'stoneCount': stoneCount,
  };

  factory Collection.fromMap(Map<String, dynamic> map) => Collection(
    id: map['id']?.toString() ?? '',
    name: map['name'] ?? '',
    description: map['description'] ?? '',
    imageUrl: map['image_url'] ?? map['imageUrl'] ?? map['image'],
    stoneCount: (map['stone_count'] ?? map['stoneCount'] ?? 0) is int
        ? (map['stone_count'] ?? map['stoneCount'] ?? 0)
        : int.tryParse((map['stone_count'] ?? map['stoneCount'] ?? 0).toString()) ?? 0,
  );
}

extension CollectionBannerExtension on Collection {
  String get effectiveBannerImage {
    if (imageUrl != null && imageUrl!.startsWith('assets/') && imageUrl!.isNotEmpty) {
      return imageUrl!;
    }
    final n = name.toLowerCase();
    if (n.contains('grande')) return 'assets/images/collections/grande_ledge_series.jpeg';
    if (n.contains('country')) return 'assets/images/collections/country_ledge_series.jpeg';
    if (n.contains('mountain')) return 'assets/images/collections/mountain_ledge_series.jpeg';
    if (n.contains('classic')) return 'assets/images/collections/classic_ledge_series.jpeg';
    if (n.contains('opus')) return 'assets/images/collections/opus_ledge_series.jpeg';
    if (n.contains('vantage')) return 'assets/images/collections/vantage_series.jpeg';
    if (n.contains('rockface linear') || (n.contains('rockface') && n.contains('linear'))) return 'assets/images/collections/rockface_linear_series.jpeg';
    if (n.contains('rockface')) return 'assets/images/collections/rockface_series.jpeg';
    if (n.contains('castle')) return 'assets/images/collections/castle_ledge_series.jpeg';
    if (n.contains('cuarzo')) return 'assets/images/collections/cuarzo_series.jpeg';
    if (n.contains('venetian') || n.contains('venecia')) return 'assets/images/collections/venecia_series.jpeg';
    if (n.contains('andorra')) return 'assets/images/collections/andorra_series.jpeg';
    if (n.contains('european') || n.contains('europian')) return 'assets/images/collections/europian_stack_series.jpeg';
    if (n.contains('veines')) return 'assets/images/collections/veines_series.jpeg';
    if (n.contains('travertino') || n.contains('travertine')) return 'assets/images/collections/travertino_series.jpeg';
    if (n.contains('sleeper')) return 'assets/images/collections/sleeper_wood_series.jpeg';
    if (n.contains('rustic brick') || (n.contains('rustic') && n.contains('brick'))) return 'assets/images/collections/rustic_brick_series.jpeg';
    if (n.contains('tarnished')) return 'assets/images/collections/tarnished_brick_series.jpeg';
    if (n.contains('colonial')) return 'assets/images/collections/colonial_brick_series.jpeg';
    if (n.contains('lakhori')) return 'assets/images/collections/rustic_brick_series.jpeg';
    if (n.contains('florentine')) return 'assets/images/collections/florentine_series.jpeg';
    if (n.contains('foliage')) return 'assets/images/collections/foliage_series.jpeg';
    if (n.contains('flora')) return 'assets/images/collections/flora_series.jpeg';
    if (n.contains('vine')) return 'assets/images/collections/vine_series.jpeg';
    if (n.contains('hexa')) return 'assets/images/collections/hexa_series.jpeg';
    if (n.contains('modena')) return 'assets/images/collections/modena_series.jpeg';
    if (n.contains('cave')) return 'assets/images/collections/cave_series.jpeg';
    if (n.contains('egyptian') || n.contains('egyption')) return 'assets/images/collections/egyption_series.jpeg';
    if (n.contains('weave')) return 'assets/images/collections/weave_series.jpeg';
    if (n.contains('milano')) return 'assets/images/collections/milano_series.jpeg';
    if (n.contains('alpine')) return 'assets/images/collections/alpine_series.jpeg';
    if (n.contains('sierra')) return 'assets/images/collections/sierra_series.jpeg';
    if (n.contains('tivoli')) return 'assets/images/collections/tivoli_series.jpeg';
    if (n.contains('fossil')) return 'assets/images/collections/cultured_stone_fossil_rock_series.jpeg';
    if (n.contains('verona')) return 'assets/images/verona_3d.png';
    if (n.contains('athena')) return 'assets/images/athena_3d.png';
    if (imageUrl != null && imageUrl!.isNotEmpty) return imageUrl!;
    return 'assets/images/collections/grande_ledge_series.jpeg';
  }

  String get dimensionSpec {
    final n = name.toLowerCase();
    if (n.contains('grande')) return '490/290/195/100 × 100 × 35mm';
    if (n.contains('country')) return '500/300/200 × 100 × 30mm';
    if (n.contains('mountain')) return '500/300/200 × 100 × 30mm';
    if (n.contains('classic')) return '340/200 × 100 × 20mm';
    if (n.contains('opus')) return 'Set Pattern × 30mm';
    if (n.contains('vantage')) return '410 × 150 × 25mm';
    if (n.contains('rockface linear')) return '445 × 110 × 25mm';
    if (n.contains('rockface')) return '500/300/200 × 100 × 30mm';
    if (n.contains('castle')) return '305 × 165 × 25mm';
    if (n.contains('cuarzo')) return '500/300/200 × 125 × 25mm';
    if (n.contains('venetian') || n.contains('venecia')) return '500/300/200 × 120 × 20mm';
    if (n.contains('andorra')) return '500/300/200 × 130 × 45mm';
    if (n.contains('european') || n.contains('europian')) return 'Dry-Stack Multi-Tile × 35mm';
    if (n.contains('veines')) return '510 × 250 × 15mm';
    if (n.contains('travertino') || n.contains('travertine')) return '755 × 500 × 15mm';
    if (n.contains('sleeper')) return '580 × 130 × 25mm';
    if (n.contains('rustic brick') || (n.contains('rustic') && n.contains('brick'))) return '195 × 60 × 10mm';
    if (n.contains('tarnished')) return '190 × 65 × 15mm';
    if (n.contains('colonial')) return '235 × 65 × 15mm';
    if (n.contains('lakhori')) return '535 × 160 × 35mm';
    if (n.contains('florentine')) return '755 × 125 × 20mm';
    if (n.contains('foliage')) return '600 × 300/150 × 15mm';
    if (n.contains('flora')) return '600/450 × 300/150 × 20mm';
    if (n.contains('vine')) return '600 × 200 × 25mm';
    if (n.contains('hexa')) return '230 × 200 × 20mm';
    if (n.contains('modena')) return '600 × 150 × 15mm';
    if (n.contains('cave')) return '300 × 300 × 15mm';
    if (n.contains('egyptian') || n.contains('egyption')) return '600 × 100 × 20mm';
    if (n.contains('weave')) return '300 × 300 × 25mm';
    if (n.contains('milano')) return '895/595 × 595 × 25mm';
    if (n.contains('alpine')) return '640 × 290 × 20mm';
    if (n.contains('sierra')) return 'Multi-Piece × 35mm';
    if (n.contains('tivoli')) return '600 × 150 × 30mm';
    if (n.contains('fossil')) return 'Multi-Piece × 50mm';
    if (n.contains('verona') || n.contains('athena') || n.contains('designer')) return '600 × 600 × 25-30mm';
    return 'Architectural Custom Size';
  }

  String get coverageSpec {
    final n = name.toLowerCase();
    if (n.contains('grande')) return '7.00 Sqft / Box';
    if (n.contains('country')) return '7.50 Sqft / Box';
    if (n.contains('mountain')) return '7.50 Sqft / Box';
    if (n.contains('classic')) return '11.40 Sqft / Box';
    if (n.contains('opus')) return '7.35 Sqft / Box';
    if (n.contains('vantage')) return '6.45 Sqft / Box';
    if (n.contains('rockface linear')) return '6.38 Sqft / Box';
    if (n.contains('rockface')) return '7.50 Sqft / Box';
    if (n.contains('castle')) return '6.60 Sqft / Box';
    if (n.contains('cuarzo')) return '9.35 Sqft / Box';
    if (n.contains('venetian') || n.contains('venecia')) return '8.10 Sqft / Box';
    if (n.contains('andorra')) return '5.40 Sqft / Box';
    if (n.contains('european') || n.contains('europian')) return '5.75 Sqft / Box';
    if (n.contains('veines')) return '15.12 Sqft / Box';
    if (n.contains('travertino') || n.contains('travertine')) return '8.16 Sqft / Box';
    if (n.contains('sleeper')) return '6.25 Sqft / Box';
    if (n.contains('rustic brick') || (n.contains('rustic') && n.contains('brick'))) return '8.12 Sqft / Box';
    if (n.contains('tarnished')) return '7.90 Sqft / Box';
    if (n.contains('colonial')) return '7.20 Sqft / Box';
    if (n.contains('lakhori')) return '6.40 Sqft / Box';
    if (n.contains('florentine')) return '8.32 Sqft / Box';
    if (n.contains('foliage')) return '11.55 Sqft / Box';
    if (n.contains('flora')) return '10.65 Sqft / Box';
    if (n.contains('vine')) return '7.74 Sqft / Box';
    if (n.contains('hexa')) return '6.40 Sqft / Box';
    if (n.contains('modena')) return '11.55 Sqft / Box';
    if (n.contains('cave')) return '7.00 Sqft / Box';
    if (n.contains('egyptian') || n.contains('egyption')) return '6.45 Sqft / Box';
    if (n.contains('weave')) return '7.00 Sqft / Box';
    if (n.contains('milano')) return '5.81 Sqft / Box';
    if (n.contains('alpine')) return '8.52 Sqft / Box';
    if (n.contains('sierra')) return '6.50 Sqft / Box';
    if (n.contains('tivoli')) return '7.42 Sqft / Box';
    if (n.contains('fossil')) return '5.50 Sqft / Box';
    if (n.contains('verona') || n.contains('athena') || n.contains('designer')) return '12.00 Sqft / Box';
    return '8.00 Sqft / Box';
  }

  String get thicknessSpec {
    final n = name.toLowerCase();
    if (n.contains('andorra')) return '45 mm';
    if (n.contains('fossil')) return '50 mm';
    if (n.contains('grande') || n.contains('european') || n.contains('sierra') || n.contains('lakhori')) return '35 mm';
    if (n.contains('country') || n.contains('mountain') || n.contains('opus') || n.contains('tivoli')) return '30 mm';
    if (n.contains('castle') || n.contains('cuarzo') || n.contains('vantage') || n.contains('rockface') || n.contains('sleeper') || n.contains('vine') || n.contains('weave') || n.contains('milano') || n.contains('verona')) return '25 mm';
    if (n.contains('classic') || n.contains('venetian') || n.contains('venecia') || n.contains('florentine') || n.contains('flora') || n.contains('hexa') || n.contains('egyptian') || n.contains('alpine')) return '20 mm';
    if (n.contains('veines') || n.contains('travertino') || n.contains('tarnished') || n.contains('colonial') || n.contains('foliage') || n.contains('modena') || n.contains('cave')) return '15 mm';
    if (n.contains('rustic')) return '10 mm';
    return '20-30 mm';
  }

  String get categoryType {
    final n = name.toLowerCase();
    if (n.contains('brick')) return 'Authentic Brick Series';
    if (n.contains('3d') || n.contains('florentine') || n.contains('hexa') || n.contains('cave') || n.contains('flora') || n.contains('foliage') || n.contains('vine') || n.contains('weave') || n.contains('alpine') || n.contains('modena') || n.contains('verona') || n.contains('athena')) return 'Designer 3D Stones';
    return 'Cultured Stone Series';
  }
}


