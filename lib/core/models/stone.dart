class Stone {
  final String id;
  final String name;
  final String productCode; // e.g., TA02, Classic 07, Opus 15
  final String collection; // e.g., Grande Ledge Series, Vantage Series
  final String category; // e.g., Ledge Stone, 3D Panels, Designer Blocks
  final double pricePerSqFt;
  final String description;
  final List<String> images; // Multiple images
  final String? mainImageUrl; // Primary display image
  final String? arTexture; // Cropped, logo-free texture used for AR wall overlay
  final double rating;
  final int reviewCount;
  
  // Dimensions
  final String length;
  final String width;
  final String thickness; // e.g., 18-20mm
  final String size; // Combined display
  
  // Box Information
  final double sqftPerBox;
  final int piecesPerBox;
  
  // Product Details
  final String finish; // Polished, Honed, Leathered, etc.
  final String texture; // Natural, Rough, Smooth
  final List<String> availableColors; // Multiple color variants
  final List<String> colorImages; // Images for each color
  
  // Applications
  final List<String> idealFor; // Living Room, Lobby, Hotel, Exterior, etc.
  final String installationGuide;
  
  // Status
  final bool isTrending;
  final bool isNewArrival;
  final bool isFeatured;
  final bool inStock;
  final int stockQuantity;
  
  // Related
  final List<String> relatedProductIds;
  final String? weight;
  final String? origin;

  const Stone({
    required this.id,
    required this.name,
    required this.productCode,
    required this.collection,
    required this.category,
    required this.pricePerSqFt,
    required this.description,
    this.images = const [],
    this.mainImageUrl,
    this.arTexture,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.length = '',
    this.width = '',
    this.thickness = '',
    this.size = '',
    this.sqftPerBox = 0.0,
    this.piecesPerBox = 0,
    this.finish = '',
    this.texture = '',
    this.availableColors = const [],
    this.colorImages = const [],
    this.idealFor = const [],
    this.installationGuide = '',
    this.isTrending = false,
    this.isNewArrival = false,
    this.isFeatured = false,
    this.inStock = true,
    this.stockQuantity = 0,
    this.relatedProductIds = const [],
    this.weight,
    this.origin,
  });


  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'productCode': productCode,
    'collection': collection,
    'category': category,
    'pricePerSqFt': pricePerSqFt,
    'description': description,
    'images': images,
    'mainImageUrl': mainImageUrl,
    'arTexture': arTexture,
    'rating': rating,
    'reviewCount': reviewCount,
    'length': length,
    'width': width,
    'thickness': thickness,
    'size': size,
    'sqftPerBox': sqftPerBox,
    'piecesPerBox': piecesPerBox,
    'finish': finish,
    'texture': texture,
    'availableColors': availableColors,
    'colorImages': colorImages,
    'idealFor': idealFor,
    'installationGuide': installationGuide,
    'isTrending': isTrending,
    'isNewArrival': isNewArrival,
    'isFeatured': isFeatured,
    'inStock': inStock,
    'stockQuantity': stockQuantity,
    'relatedProductIds': relatedProductIds,
    'weight': weight,
    'origin': origin,
  };
  
  // Backward compatibility - get first image as imageUrl
  String? get imageUrl => mainImageUrl ?? (images.isNotEmpty ? images.first : null);

  // Compatibility getters for admin and filters
  List<String> get colors => availableColors;
  List<String> get tags => idealFor;
  String? get collectionId => null;
  double? get lengthCm => double.tryParse(length.replaceAll(RegExp(r'[^0-9.]'), ''));
  double? get widthCm => double.tryParse(width.replaceAll(RegExp(r'[^0-9.]'), ''));
  double? get thicknessMm => double.tryParse(thickness.replaceAll(RegExp(r'[^0-9.]'), ''));
  double? get coverageSqft => sqftPerBox;
  String get material => texture;
  List<String> get patterns => const [];
  String? get shortDescription => description;
  String? get model3dUrl => null;
  String? get videoUrl => null;
  String? get cataloguePdfUrl => null;
  String get stockStatus => inStock ? 'in_stock' : 'out_of_stock';
  bool get active => inStock;
  double? get discountPercent => null;
  String get currency => 'INR';


  // AR overlay uses a cropped, logo-free texture when available, falling back to the main photo
  String? get arTextureUrl => arTexture ?? imageUrl;


  factory Stone.fromJson(Map<String, dynamic> json) => Stone.fromMap(json);

  Map<String, dynamic> toJson() => toMap();


  factory Stone.fromMap(Map<String, dynamic> map) {
    // Resolve collection name from nested collections object or string
    String collectionName = '';
    if (map['collections'] is Map) {
      collectionName = map['collections']['name'] ?? '';
    } else if (map['collection'] != null) {
      collectionName = map['collection'].toString();
    }

    // Resolve images
    List<String> imageList = [];
    if (map['images'] is List) {
      imageList = List<String>.from(map['images']);
    }

    // Resolve main image
    String? mainImg = map['thumbnail_url'] ?? map['mainImageUrl'] ?? map['imageUrl'];
    if (mainImg == null && imageList.isNotEmpty) {
      mainImg = imageList.first;
    }

    // Resolve dimensions
    String lengthStr = map['length'] ?? '';
    if (lengthStr.isEmpty && map['length_cm'] != null) {
      lengthStr = '${map['length_cm']} cm';
    }

    String widthStr = map['width'] ?? '';
    if (widthStr.isEmpty && map['width_cm'] != null) {
      widthStr = '${map['width_cm']} cm';
    }

    String thicknessStr = map['thickness'] ?? '';
    if (thicknessStr.isEmpty && map['thickness_mm'] != null) {
      thicknessStr = '${map['thickness_mm']} mm';
    }

    String sizeStr = map['size'] ?? '';
    if (sizeStr.isEmpty && lengthStr.isNotEmpty && widthStr.isNotEmpty) {
      sizeStr = '$lengthStr x $widthStr';
    }

    return Stone(
      id: map['id']?.toString() ?? '',
      name: map['name'] ?? '',
      productCode: map['product_code'] ?? map['productCode'] ?? '',
      collection: collectionName,
      category: map['category'] ?? '',
      pricePerSqFt: (map['price_per_sqft'] ?? map['pricePerSqFt'] ?? 0).toDouble(),
      description: map['description'] ?? map['short_description'] ?? '',
      images: imageList,
      mainImageUrl: mainImg,
      arTexture: map['ar_texture'] ?? map['arTexture'],
      rating: (map['rating'] ?? 0).toDouble(),
      reviewCount: (map['review_count'] ?? map['reviewCount'] ?? 0) is int
          ? (map['review_count'] ?? map['reviewCount'] ?? 0)
          : int.tryParse((map['review_count'] ?? map['reviewCount'] ?? 0).toString()) ?? 0,
      length: lengthStr,
      width: widthStr,
      thickness: thicknessStr,
      size: sizeStr,
      sqftPerBox: (map['coverage_sqft'] ?? map['sqftPerBox'] ?? 0).toDouble(),
      piecesPerBox: map['pieces_per_box'] ?? map['piecesPerBox'] ?? 0,
      finish: map['finish'] ?? '',
      texture: map['material'] ?? map['texture'] ?? '',
      availableColors: List<String>.from(map['colors'] ?? map['availableColors'] ?? []),
      colorImages: List<String>.from(map['color_images'] ?? map['colorImages'] ?? []),
      idealFor: List<String>.from(map['tags'] ?? map['idealFor'] ?? []),
      installationGuide: map['installation_guide'] ?? map['installationGuide'] ?? '',
      isTrending: (map['featured'] == true) || (map['isTrending'] == true),
      isNewArrival: (map['is_new_arrival'] == true) || (map['isNewArrival'] == true),
      isFeatured: (map['featured'] == true) || (map['isFeatured'] == true),
      inStock: map['stock_status'] == 'in_stock' || (map['inStock'] ?? true),
      stockQuantity: map['stock_quantity'] ?? map['stockQuantity'] ?? 0,
      relatedProductIds: List<String>.from(map['related_product_ids'] ?? map['relatedProductIds'] ?? []),
      weight: map['weight_kg']?.toString() ?? map['weight'],
      origin: map['origin'],
    );
  }

  Stone copyWith({
    String? id,
    String? name,
    String? productCode,
    String? collection,
    String? category,
    double? pricePerSqFt,
    String? description,
    List<String>? images,
    String? mainImageUrl,
    String? arTexture,
    double? rating,
    int? reviewCount,
    String? length,
    String? width,
    String? thickness,
    String? size,
    double? sqftPerBox,
    int? piecesPerBox,
    String? finish,
    String? texture,
    List<String>? availableColors,
    List<String>? colorImages,
    List<String>? idealFor,
    String? installationGuide,
    bool? isTrending,
    bool? isNewArrival,
    bool? isFeatured,
    bool? inStock,
    int? stockQuantity,
    List<String>? relatedProductIds,
    String? weight,
    String? origin,
  }) => Stone(
    id: id ?? this.id,
    name: name ?? this.name,
    productCode: productCode ?? this.productCode,
    collection: collection ?? this.collection,
    category: category ?? this.category,
    pricePerSqFt: pricePerSqFt ?? this.pricePerSqFt,
    description: description ?? this.description,
    images: images ?? this.images,
    mainImageUrl: mainImageUrl ?? this.mainImageUrl,
    arTexture: arTexture ?? this.arTexture,
    rating: rating ?? this.rating,
    reviewCount: reviewCount ?? this.reviewCount,
    length: length ?? this.length,
    width: width ?? this.width,
    thickness: thickness ?? this.thickness,
    size: size ?? this.size,
    sqftPerBox: sqftPerBox ?? this.sqftPerBox,
    piecesPerBox: piecesPerBox ?? this.piecesPerBox,
    finish: finish ?? this.finish,
    texture: texture ?? this.texture,
    availableColors: availableColors ?? this.availableColors,
    colorImages: colorImages ?? this.colorImages,
    idealFor: idealFor ?? this.idealFor,
    installationGuide: installationGuide ?? this.installationGuide,
    isTrending: isTrending ?? this.isTrending,
    isNewArrival: isNewArrival ?? this.isNewArrival,
    isFeatured: isFeatured ?? this.isFeatured,
    inStock: inStock ?? this.inStock,
    stockQuantity: stockQuantity ?? this.stockQuantity,
    relatedProductIds: relatedProductIds ?? this.relatedProductIds,
    weight: weight ?? this.weight,
    origin: origin ?? this.origin,
  );
}
