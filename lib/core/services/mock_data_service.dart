import '../models/stone.dart';
import '../models/collection.dart';
import '../models/dealer.dart';

class MockDataService {
  static final List<Stone> stones = [
    // GRANDE LEDGE SERIES
    Stone(
      id: 'grande-ta02',
      name: 'Grande Ledge TA02',
      productCode: 'TA02',
      collection: 'Grande Ledge Series',
      category: 'Ledge Stone',
      pricePerSqFt: 375,
      description: 'Premium natural stone cladding with deep texture and rustic charm. Perfect for exterior and interior feature walls.',
      images: [
        'assets/images/grande_ledge_ta02.png',
        'assets/images/hero_banner_1.png',
      ],
      rating: 4.8,
      reviewCount: 124,
      length: '600mm',
      width: '150mm',
      thickness: '18-20mm',
      size: '600×150×18-20mm',
      sqftPerBox: 10.5,
      piecesPerBox: 8,
      finish: 'Natural',
      texture: 'Rough Ledge',
      availableColors: ['Beige', 'Grey', 'Brown'],
      idealFor: ['Living Room', 'Lobby', 'Feature Wall', 'Hotel Interior'],
      isTrending: true,
      isFeatured: true,
      inStock: true,
      stockQuantity: 150,
    ),
    
    // CLASSIC LEDGE SERIES
    Stone(
      id: 'classic-07',
      name: 'Classic Ledge 07',
      productCode: 'Classic 07',
      collection: 'Classic Ledge Series',
      category: 'Ledge Stone',
      pricePerSqFt: 425,
      description: 'Timeless classic ledge stone with sophisticated layered design. Ideal for elegant architectural spaces.',
      images: [
        'assets/images/classic_ledge_07.png',
        'assets/images/placeholder_stone.png',
      ],
      rating: 4.9,
      reviewCount: 89,
      length: '600mm',
      width: '150mm',
      thickness: '18-20mm',
      size: '600×150×18-20mm',
      sqftPerBox: 10.5,
      piecesPerBox: 8,
      finish: 'Natural',
      texture: 'Stacked Ledge',
      availableColors: ['Grey', 'Charcoal', 'Silver'],
      idealFor: ['Living Room', 'Office', 'Reception', 'Commercial'],
      isTrending: true,
      inStock: true,
      stockQuantity: 200,
    ),
    
    // OPUS LEDGE SERIES
    Stone(
      id: 'opus-15',
      name: 'Opus Ledge 15',
      productCode: 'Opus 15',
      collection: 'Opus Ledge Series',
      category: 'Ledge Stone',
      pricePerSqFt: 375,
      description: 'Modern opus pattern ledge stone with irregular shapes creating a contemporary aesthetic.',
      images: [
        'assets/images/opus_ledge_15.png',
      ],
      rating: 4.7,
      reviewCount: 156,
      length: '600mm',
      width: '150mm',
      thickness: '18-20mm',
      size: '600×150×18-20mm',
      sqftPerBox: 10.5,
      piecesPerBox: 8,
      finish: 'Natural',
      texture: 'Irregular Ledge',
      availableColors: ['Sandstone', 'Brown', 'Mixed'],
      idealFor: ['Feature Wall', 'Restaurant', 'Bar', 'Modern Interior'],
      isTrending: false,
      inStock: true,
      stockQuantity: 120,
    ),
    
    // DESIGNER 3D PANELS - VERONA
    Stone(
      id: 'verona-3d',
      name: 'Verona 3D Panel',
      productCode: 'VERONA',
      collection: 'Designer 3D Collection',
      category: '3D Wall Panels',
      pricePerSqFt: 550,
      description: 'Elegant 3D decorative wall panel with geometric patterns. Premium architectural element for luxury spaces.',
      images: [
        'assets/images/verona_3d.png',
        'assets/images/onboarding_2.png',
      ],
      rating: 4.9,
      reviewCount: 67,
      length: '600mm',
      width: '600mm',
      thickness: '25mm',
      size: '600×600×25mm',
      sqftPerBox: 12.0,
      piecesPerBox: 4,
      finish: 'Polished',
      texture: '3D Geometric',
      availableColors: ['White', 'Grey', 'Black', 'Beige'],
      idealFor: ['Living Room', 'Bedroom', 'Hotel Lobby', 'Office'],
      isTrending: true,
      isFeatured: true,
      isNewArrival: true,
      inStock: true,
      stockQuantity: 80,
    ),
    
    // DESIGNER 3D PANELS - ATHENA
    Stone(
      id: 'athena-3d',
      name: 'Athena 3D Panel',
      productCode: 'ATHENA',
      collection: 'Designer 3D Collection',
      category: '3D Wall Panels',
      pricePerSqFt: 580,
      description: 'Sculptural 3D panel inspired by classical Greek architecture. Creates stunning shadow lines under accent lighting.',
      images: [
        'assets/images/athena_3d.png',
        'assets/images/onboarding_3.png',
      ],
      rating: 5.0,
      reviewCount: 42,
      length: '600mm',
      width: '600mm',
      thickness: '30mm',
      size: '600×600×30mm',
      sqftPerBox: 12.0,
      piecesPerBox: 4,
      finish: 'Honed',
      texture: 'Sculptural Wave',
      availableColors: ['Snow White', 'Cream', 'Charcoal'],
      idealFor: ['Living Room', 'Master Suite', 'Villa Lobby', 'Exterior Accent'],
      isTrending: true,
      isFeatured: true,
      inStock: true,
      stockQuantity: 65,
    ),
    
    // VANTAGE SERIES
    Stone(
      id: 'vantage-v12',
      name: 'Vantage V12',
      productCode: 'V12',
      collection: 'Vantage Series',
      category: 'Linear Stone',
      pricePerSqFt: 395,
      description: 'Sleek linear stone design with narrow striping for modern architectural facades and feature walls.',
      images: [
        'assets/images/vantage_v12.png',
      ],
      rating: 4.6,
      reviewCount: 98,
      length: '600mm',
      width: '150mm',
      thickness: '18-20mm',
      size: '600×150×18-20mm',
      sqftPerBox: 10.5,
      piecesPerBox: 8,
      finish: 'Natural',
      texture: 'Linear Ledge',
      availableColors: ['Grey', 'White', 'Black'],
      idealFor: ['Modern Home', 'Loft', 'Studio', 'Contemporary Office'],
      isTrending: false,
      inStock: true,
      stockQuantity: 100,
    ),
    
    // MOUNTAIN LEDGE SERIES
    Stone(
      id: 'mountain-m08',
      name: 'Mountain Ledge M08',
      productCode: 'M08',
      collection: 'Mountain Ledge Series',
      category: 'Ledge Stone',
      pricePerSqFt: 410,
      description: 'Rugged mountain-inspired ledge stone with natural texture and earthy tones.',
      images: [
        'assets/images/mountain_ledge_m08.png',
      ],
      rating: 4.7,
      reviewCount: 112,
      length: '600mm',
      width: '150mm',
      thickness: '20-25mm',
      size: '600×150×20-25mm',
      sqftPerBox: 10.5,
      piecesPerBox: 8,
      finish: 'Natural',
      texture: 'Rough Mountain',
      availableColors: ['Brown', 'Rust', 'Mixed Earth Tones'],
      idealFor: ['Exterior', 'Villa', 'Resort', 'Garden Wall'],
      isTrending: false,
      inStock: true,
      stockQuantity: 180,
    ),
  ];

  static final List<Collection> collections = [
    const Collection(
      id: 'grande-ledge-series',
      name: 'Grande Ledge Series',
      description: 'Premium natural stone ledge collection with elegant texture and timeless appeal',
      stoneCount: 1,
    ),
    const Collection(
      id: 'classic-ledge-series',
      name: 'Classic Ledge Series',
      description: 'Sophisticated layered ledge stones for elegant architectural spaces',
      stoneCount: 1,
    ),
    const Collection(
      id: 'opus-ledge-series',
      name: 'Opus Ledge Series',
      description: 'Modern irregular pattern ledge stones with contemporary aesthetic',
      stoneCount: 1,
    ),
    const Collection(
      id: 'designer-3d-collection',
      name: 'Designer 3D Collection',
      description: 'Premium 3D decorative wall panels for luxury interiors',
      stoneCount: 2,
    ),
    const Collection(
      id: 'vantage-series',
      name: 'Vantage Series',
      description: 'Contemporary ledge series with clean lines and modern appeal',
      stoneCount: 1,
    ),
    const Collection(
      id: 'mountain-ledge-series',
      name: 'Mountain Ledge Series',
      description: 'Rugged mountain-inspired ledge stones with natural texture',
      stoneCount: 1,
    ),
  ];

  static final List<Dealer> dealers = [
    const Dealer(
      id: 'dealer-1',
      name: 'Grazia Premium Showroom',
      address: '42 Design District, MG Road, Mumbai',
      phone: '+91 98765 43210',
      distance: '2.3 km',
      rating: 4.9,
      isAuthorized: true,
    ),
    const Dealer(
      id: 'dealer-2',
      name: 'StoneWorld Architects Hub',
      address: '15 Connaught Place, New Delhi',
      phone: '+91 11 2345 6789',
      distance: '5.1 km',
      rating: 4.7,
      isAuthorized: true,
    ),
    const Dealer(
      id: 'dealer-3',
      name: 'LuxStone Gallery',
      address: '88 Jubilee Hills, Hyderabad',
      phone: '+91 40 9876 5432',
      distance: '8.7 km',
      rating: 4.5,
      isAuthorized: false,
    ),
  ];

  static Stone? getStoneById(String id) {
    try {
      return stones.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  static List<Stone> getAllStones() {
    return stones;
  }

  static List<Stone> getStonesByCollection(String collectionId) {
    return stones.where((s) => s.collection.toLowerCase().replaceAll(' ', '-') == collectionId).toList();
  }

  static List<Stone> getTrendingStones() {
    return stones.where((s) => s.isTrending).toList();
  }

  static List<Dealer> getAllDealers() {
    return dealers;
  }

  static List<Stone> searchStones(String query) {
    if (query.isEmpty) return stones;
    final q = query.toLowerCase();
    return stones.where((s) =>
      s.name.toLowerCase().contains(q) ||
      s.collection.toLowerCase().contains(q) ||
      s.category.toLowerCase().contains(q) ||
      s.description.toLowerCase().contains(q)
    ).toList();
  }

  static List<Collection> getAllCollections() {
    return collections;
  }
}
