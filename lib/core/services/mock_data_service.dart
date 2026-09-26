import '../models/stone.dart';
import '../models/collection.dart';
import '../models/dealer.dart';

/// Authentic catalogue dataset grounded directly in:
/// 1. GRAZIA - Cultured Catalogue.pdf (60 pages)
/// 2. Grazia Stones Catalogue.pdf (22 pages)
/// 3. New Grazia company profile.pdf (9 pages)
class MockDataService {
  static final List<Stone> stones = [
    // ═══════════════════════════════════════════════════════════════════════
    // 1. GRANDE LEDGE SERIES (490/290/195/100 x 100 x 35mm, 7.00 Sqft/Box)
    // ═══════════════════════════════════════════════════════════════════════
    Stone(
      id: 'grande-aty-10',
      name: 'Grande Ledge ATY 10',
      productCode: 'ATY 10',
      collection: 'Grande Ledge Series',
      category: 'Ledge Stone',
      pricePerSqFt: 385,
      description: 'Rugged natural textures and clean geometric lines blending modern elegance with bold architectural depth. Sourced for premier feature walls.',
      images: [
        'assets/images/products/aty_10.jpeg',
        'assets/images/grande_ledge_ta02.png',
      ],
      arTexture: 'assets/images/grande_ledge_ta02_tex.png',
      rating: 4.9,
      reviewCount: 142,
      length: '490mm',
      width: '100mm',
      thickness: '35mm',
      size: '490/290/195/100×100×35mm',
      sqftPerBox: 7.00,
      piecesPerBox: 12,
      finish: 'Natural Split',
      texture: 'Coarse Ledge',
      availableColors: ['Ash Grey', 'Charcoal', 'Earth Brown'],
      idealFor: ['Living Room Feature Wall', 'Building Facade', 'Villa Entryway', 'Luxury Lobby'],
      isTrending: true,
      isFeatured: true,
      isNewArrival: false,
      inStock: true,
      stockQuantity: 240,
    ),
    Stone(
      id: 'grande-aty-07',
      name: 'Grande Ledge ATY 07',
      productCode: 'ATY 07',
      collection: 'Grande Ledge Series',
      category: 'Ledge Stone',
      pricePerSqFt: 395,
      description: 'Deep cleft profiling with earthy beige undertones. Certified high-durability cultured stone engineered for harsh climates and exterior cladding.',
      images: [
        'assets/images/products/aty_07.jpeg',
        'assets/images/grande_ledge_ta02.png',
      ],
      arTexture: 'assets/images/grande_ledge_ta02_tex.png',
      rating: 4.8,
      reviewCount: 96,
      length: '490mm',
      width: '100mm',
      thickness: '35mm',
      size: '490/290/195/100×100×35mm',
      sqftPerBox: 7.00,
      piecesPerBox: 12,
      finish: 'Natural Split',
      texture: 'Layered Ledge',
      availableColors: ['Golden Sand', 'Desert Buff', 'Cream'],
      idealFor: ['Fireplace Surrounds', 'Courtyards', 'Exterior Cladding'],
      isTrending: true,
      isFeatured: false,
      isNewArrival: true,
      inStock: true,
      stockQuantity: 180,
    ),
    Stone(
      id: 'grande-aty-08',
      name: 'Grande Ledge ATY 08',
      productCode: 'ATY 08',
      collection: 'Grande Ledge Series',
      category: 'Ledge Stone',
      pricePerSqFt: 390,
      description: 'Sophisticated dark slate tones with subtle mica highlights. Creates striking visual shadow lines under accent warm lighting.',
      images: [
        'assets/images/products/aty_08.jpeg',
        'assets/images/grande_ledge_ta02.png',
      ],
      arTexture: 'assets/images/grande_ledge_ta02_tex.png',
      rating: 4.7,
      reviewCount: 88,
      length: '490mm',
      width: '100mm',
      thickness: '35mm',
      size: '490/290/195/100×100×35mm',
      sqftPerBox: 7.00,
      piecesPerBox: 12,
      finish: 'Natural Split',
      texture: 'Stacked Ledge',
      availableColors: ['Graphite', 'Dark Slate', 'Onyx Mist'],
      idealFor: ['Modern Living Room', 'Clubhouse', 'Accent Pillars'],
      isTrending: false,
      isFeatured: false,
      inStock: true,
      stockQuantity: 150,
    ),
    Stone(
      id: 'grande-aty-12',
      name: 'Grande Ledge ATY 12',
      productCode: 'ATY 12',
      collection: 'Grande Ledge Series',
      category: 'Ledge Stone',
      pricePerSqFt: 405,
      description: 'Warm terracotta mixed with basalt grey. Designed for multi-tonal dimensional wall statements.',
      images: [
        'assets/images/products/aty_12.jpeg',
      ],
      arTexture: 'assets/images/grande_ledge_ta02_tex.png',
      rating: 4.9,
      reviewCount: 110,
      length: '490mm',
      width: '100mm',
      thickness: '35mm',
      size: '490/290/195/100×100×35mm',
      sqftPerBox: 7.00,
      piecesPerBox: 12,
      finish: 'Natural Split',
      texture: 'Rough Cleft',
      availableColors: ['Terracotta Buff', 'Autumn Blend'],
      idealFor: ['Resort Walls', 'Exterior Gate Pillars', 'Dining Alcove'],
      isTrending: false,
      isFeatured: true,
      inStock: true,
      stockQuantity: 120,
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // 2. COUNTRY LEDGE SERIES (500/300/200 x 100 x 30mm, 7.50 Sqft/Box)
    // ═══════════════════════════════════════════════════════════════════════
    Stone(
      id: 'country-ta-02',
      name: 'Country Ledge TA 02',
      productCode: 'TA 02',
      collection: 'Country Ledge Series',
      category: 'Ledge Stone',
      pricePerSqFt: 375,
      description: 'Rustic European charm inspired by countryside stone cottages. Features subtle color gradations and durable natural interlocking.',
      images: [
        'assets/images/grande_ledge_ta02.png',
        'assets/images/hero_banner_1.png',
      ],
      arTexture: 'assets/images/grande_ledge_ta02_tex.png',
      rating: 4.8,
      reviewCount: 124,
      length: '500mm',
      width: '100mm',
      thickness: '30mm',
      size: '500/300/200×100×30mm',
      sqftPerBox: 7.50,
      piecesPerBox: 10,
      finish: 'Natural',
      texture: 'Rustic Ledge',
      availableColors: ['Beige', 'Warm Grey', 'Earth Brown'],
      idealFor: ['Living Room', 'Lobby', 'Feature Wall', 'Hotel Interior'],
      isTrending: true,
      isFeatured: true,
      inStock: true,
      stockQuantity: 210,
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // 3. MOUNTAIN LEDGE SERIES (500/300/200 x 100 x 30mm, 7.50 Sqft/Box)
    // ═══════════════════════════════════════════════════════════════════════
    Stone(
      id: 'mountain-m08',
      name: 'Mountain Ledge M08',
      productCode: 'M08',
      collection: 'Mountain Ledge Series',
      category: 'Ledge Stone',
      pricePerSqFt: 410,
      description: 'Rugged mountain-inspired ledge stone with natural texture and earthy tones reflecting high-altitude rocky peaks.',
      images: [
        'assets/images/mountain_ledge_m08.png',
        'assets/images/placeholder_stone.png',
      ],
      arTexture: 'assets/images/mountain_ledge_m08_tex.png',
      rating: 4.7,
      reviewCount: 112,
      length: '500mm',
      width: '100mm',
      thickness: '30mm',
      size: '500/300/200×100×30mm',
      sqftPerBox: 7.50,
      piecesPerBox: 10,
      finish: 'Natural Rough',
      texture: 'Mountain Ridge',
      availableColors: ['Brown', 'Rust', 'Alpine Slate'],
      idealFor: ['Exterior Villa', 'Resort Facade', 'Garden Wall'],
      isTrending: false,
      isFeatured: true,
      inStock: true,
      stockQuantity: 180,
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // 4. CLASSIC LEDGE SERIES (340/200 x 100 x 20mm, 11.40 Sqft/Box)
    // ═══════════════════════════════════════════════════════════════════════
    Stone(
      id: 'classic-07',
      name: 'Classic Ledge 07',
      productCode: 'Classic 07',
      collection: 'Classic Ledge Series',
      category: 'Ledge Stone',
      pricePerSqFt: 425,
      description: 'Timeless classic ledge stone with sophisticated layered design. Ideal for clean architectural spaces with balanced horizontal lines.',
      images: [
        'assets/images/products/classic_07.jpeg',
        'assets/images/classic_ledge_07.png',
      ],
      arTexture: 'assets/images/classic_ledge_07_tex.png',
      rating: 4.9,
      reviewCount: 89,
      length: '340mm',
      width: '100mm',
      thickness: '20mm',
      size: '340/200×100×20mm',
      sqftPerBox: 11.40,
      piecesPerBox: 16,
      finish: 'Natural',
      texture: 'Stacked Ledge',
      availableColors: ['Grey', 'Charcoal', 'Silver'],
      idealFor: ['Living Room', 'Office', 'Reception', 'Commercial'],
      isTrending: true,
      isFeatured: true,
      inStock: true,
      stockQuantity: 200,
    ),
    Stone(
      id: 'classic-15',
      name: 'Classic Ledge 15',
      productCode: 'Classic 15',
      collection: 'Classic Ledge Series',
      category: 'Ledge Stone',
      pricePerSqFt: 435,
      description: 'Refined beige and ivory limestone tones. Clean horizontal banding for contemporary luxury interior feature walls.',
      images: [
        'assets/images/products/classic_15.jpeg',
        'assets/images/classic_ledge_07.png',
      ],
      arTexture: 'assets/images/classic_ledge_07_tex.png',
      rating: 4.8,
      reviewCount: 75,
      length: '340mm',
      width: '100mm',
      thickness: '20mm',
      size: '340/200×100×20mm',
      sqftPerBox: 11.40,
      piecesPerBox: 16,
      finish: 'Honed',
      texture: 'Stacked Ledge',
      availableColors: ['Ivory', 'Beige Silk', 'Oatmeal'],
      idealFor: ['Master Suite', 'Dining Wall', 'Boardroom'],
      isTrending: false,
      isFeatured: false,
      inStock: true,
      stockQuantity: 160,
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // 5. OPUS LEDGE SERIES (Set Pattern, 30mm, 7.35 Sqft/Box)
    // ═══════════════════════════════════════════════════════════════════════
    Stone(
      id: 'opus-15',
      name: 'Opus Ledge 15',
      productCode: 'Opus 15',
      collection: 'Opus Ledge Series',
      category: 'Ledge Stone',
      pricePerSqFt: 375,
      description: 'Modern opus pattern ledge stone with precision interlocking shapes creating a seamless, contemporary stone canvas.',
      images: [
        'assets/images/opus_ledge_15.png',
        'assets/images/hero_banner_2.png',
      ],
      arTexture: 'assets/images/opus_ledge_15_tex.png',
      rating: 4.7,
      reviewCount: 156,
      length: '600mm',
      width: '150mm',
      thickness: '30mm',
      size: 'Set Pattern × 30mm',
      sqftPerBox: 7.35,
      piecesPerBox: 8,
      finish: 'Natural',
      texture: 'Irregular Ledge',
      availableColors: ['Sandstone', 'Brown', 'Mixed Earth'],
      idealFor: ['Feature Wall', 'Restaurant', 'Bar', 'Modern Interior'],
      isTrending: false,
      isFeatured: false,
      inStock: true,
      stockQuantity: 120,
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // 6. VANTAGE SERIES (410 x 150 x 25mm, 6.45 Sqft/Box)
    // ═══════════════════════════════════════════════════════════════════════
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
      arTexture: 'assets/images/vantage_v12_tex.png',
      rating: 4.6,
      reviewCount: 98,
      length: '410mm',
      width: '150mm',
      thickness: '25mm',
      size: '410×150×25mm',
      sqftPerBox: 6.45,
      piecesPerBox: 8,
      finish: 'Natural',
      texture: 'Linear Ledge',
      availableColors: ['Grey', 'White', 'Black'],
      idealFor: ['Modern Home', 'Loft', 'Studio', 'Contemporary Office'],
      isTrending: false,
      isFeatured: false,
      inStock: true,
      stockQuantity: 100,
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // 7. CASTLE LEDGE SERIES (305 x 165 x 25mm, 6.60 Sqft/Box)
    // ═══════════════════════════════════════════════════════════════════════
    Stone(
      id: 'castle-clt-24',
      name: 'Castle Ledge CLT 24',
      productCode: 'CLT 24',
      collection: 'Castle Ledge Series',
      category: 'Ledge Stone',
      pricePerSqFt: 440,
      description: 'Bold irregular stones and intricate masonry detailing inspired by medieval European castles and heritage manor architecture.',
      images: [
        'assets/images/products/clt_24.jpeg',
        'assets/images/products/clt_07.jpeg',
      ],
      arTexture: 'assets/images/grande_ledge_ta02_tex.png',
      rating: 4.9,
      reviewCount: 114,
      length: '305mm',
      width: '165mm',
      thickness: '25mm',
      size: '305×165×25mm',
      sqftPerBox: 6.60,
      piecesPerBox: 10,
      finish: 'Hand Chiseled',
      texture: 'Castle Ashlar',
      availableColors: ['Cobblestone Grey', 'Antiquity Buff', 'Smoked Slate'],
      idealFor: ['Heritage Villas', 'Wine Cellars', 'Grand Fireplaces', 'Exterior Boundary'],
      isTrending: true,
      isFeatured: true,
      inStock: true,
      stockQuantity: 140,
    ),
    Stone(
      id: 'castle-clt-07',
      name: 'Castle Ledge CLT 07',
      productCode: 'CLT 07',
      collection: 'Castle Ledge Series',
      category: 'Ledge Stone',
      pricePerSqFt: 445,
      description: 'Warm sandy gold castle stonework with authentic aged edges and high thermal insulation qualities.',
      images: [
        'assets/images/products/clt_07.jpeg',
      ],
      arTexture: 'assets/images/grande_ledge_ta02_tex.png',
      rating: 4.8,
      reviewCount: 78,
      length: '305mm',
      width: '165mm',
      thickness: '25mm',
      size: '305×165×25mm',
      sqftPerBox: 6.60,
      piecesPerBox: 10,
      finish: 'Hand Chiseled',
      texture: 'Weathered Ashlar',
      availableColors: ['Desert Amber', 'Limestone Cream'],
      idealFor: ['Courtyard Walls', 'Clubhouse Entrance', 'Pillars'],
      isTrending: false,
      isFeatured: false,
      inStock: true,
      stockQuantity: 110,
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // 8. CUARZO SERIES (500/300/200 x 125 x 25mm, 9.35 Sqft/Box)
    // ═══════════════════════════════════════════════════════════════════════
    Stone(
      id: 'cuarzo-222310',
      name: 'Cuarzo 222310',
      productCode: 'CUARZO 222310',
      collection: 'Cuarzo Series',
      category: 'Ledge Stone',
      pricePerSqFt: 460,
      description: 'Inspired by the natural crystalline brilliance of natural quartz. Soft, shimmering mineral facets reflect ambient lighting with immense luxury.',
      images: [
        'assets/images/products/cuarzo_222310.jpeg',
        'assets/images/products/cuarzo_0708.jpeg',
      ],
      arTexture: 'assets/images/classic_ledge_07_tex.png',
      rating: 4.9,
      reviewCount: 92,
      length: '500mm',
      width: '125mm',
      thickness: '25mm',
      size: '500/300/200×125×25mm',
      sqftPerBox: 9.35,
      piecesPerBox: 12,
      finish: 'Crystalline Lustre',
      texture: 'Shimmering Quartz',
      availableColors: ['Crystal White', 'Silver Ash', 'Rose Champagne'],
      idealFor: ['Luxury Master Suite', 'Spa Bathroom Feature', 'Hotel Suite'],
      isTrending: true,
      isFeatured: true,
      inStock: true,
      stockQuantity: 130,
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // 9. ANDORRA SERIES (500/300/200 x 130 x 45mm, 5.40 Sqft/Box)
    // ═══════════════════════════════════════════════════════════════════════
    Stone(
      id: 'andorra-2407',
      name: 'Andorra 2407',
      productCode: 'ANDORRA 2407',
      collection: 'Andorra Series',
      category: 'Ledge Stone',
      pricePerSqFt: 475,
      description: 'Heavy 45mm deep relief stone crafted to capture alpine terrains with bold organic shadows and maximum weather resistance.',
      images: [
        'assets/images/products/andorra_2407.jpeg',
      ],
      arTexture: 'assets/images/mountain_ledge_m08_tex.png',
      rating: 4.8,
      reviewCount: 64,
      length: '500mm',
      width: '130mm',
      thickness: '45mm',
      size: '500/300/200×130×45mm',
      sqftPerBox: 5.40,
      piecesPerBox: 8,
      finish: 'Deep Cleft',
      texture: 'Alpine Rock',
      availableColors: ['Pyrenees Grey', 'Sierra Brown'],
      idealFor: ['Exterior Boundary Walls', 'Mountain Cottages', 'Waterfalls'],
      isTrending: false,
      isFeatured: false,
      inStock: true,
      stockQuantity: 95,
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // 10. RUSTIC BRICK SERIES (195 x 60 x 10mm, 8.12 Sqft/Box)
    // ═══════════════════════════════════════════════════════════════════════
    Stone(
      id: 'rustic-brick-07',
      name: 'Rustic Brick 07',
      productCode: 'RUSTIC 07',
      collection: 'Rustic Brick Series',
      category: 'Brick Series',
      pricePerSqFt: 340,
      description: 'Vintage weathered European brick with authentic tumbled edges and time-worn mortar patinas. Creates warm, inviting industrial interiors.',
      images: [
        'assets/images/products/rustic_brick_07.jpeg',
        'assets/images/template_page-06.png',
      ],
      arTexture: 'assets/images/grande_ledge_ta02_tex.png',
      rating: 4.9,
      reviewCount: 168,
      length: '195mm',
      width: '60mm',
      thickness: '10mm',
      size: '195×60×10mm',
      sqftPerBox: 8.12,
      piecesPerBox: 48,
      finish: 'Tumbled Antique',
      texture: 'Weathered Brick',
      availableColors: ['Classic Red', 'Burnt Umber', 'Tuscan Ochre'],
      idealFor: ['Kitchen Backsplash', 'Cafe & Restaurant Walls', 'Living Room Exposed Brick'],
      isTrending: true,
      isFeatured: true,
      isNewArrival: false,
      inStock: true,
      stockQuantity: 320,
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // 11. TARNISHED BRICK SERIES (190 x 65 x 15mm, 7.90 Sqft/Box)
    // ═══════════════════════════════════════════════════════════════════════
    Stone(
      id: 'tarnished-brick-07',
      name: 'Tarnished Brick 07',
      productCode: 'TARNISHED 07',
      collection: 'Tarnished Brick Series',
      category: 'Brick Series',
      pricePerSqFt: 360,
      description: 'Aged weathered patina with smoky mineral wash and soft rounded corners, reminiscent of century-old historic brickwork.',
      images: [
        'assets/images/collections/tarnished_brick_series.jpeg',
      ],
      arTexture: 'assets/images/grande_ledge_ta02_tex.png',
      rating: 4.7,
      reviewCount: 82,
      length: '190mm',
      width: '65mm',
      thickness: '15mm',
      size: '190×65×15mm',
      sqftPerBox: 7.90,
      piecesPerBox: 42,
      finish: 'Weathered Matte',
      texture: 'Antique Brick',
      availableColors: ['Smoked Charcoal', 'Aged Crimson', 'Dusty Clay'],
      idealFor: ['Loft Apartments', 'Bar Backdrops', 'Feature Fireplace'],
      isTrending: false,
      isFeatured: false,
      inStock: true,
      stockQuantity: 210,
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // 12. COLONIAL BRICK SERIES (235 x 65 x 15mm, 7.20 Sqft/Box)
    // ═══════════════════════════════════════════════════════════════════════
    Stone(
      id: 'colonial-brick-12507',
      name: 'Colonial Brick 12507',
      productCode: 'COLONIAL 12507',
      collection: 'Colonial Brick Series',
      category: 'Brick Series',
      pricePerSqFt: 370,
      description: 'Refined colonial architectural proportion with crisp linear edges and consistent texture. Blends heritage charm with modern architecture.',
      images: [
        'assets/images/products/colonial_12507.jpeg',
      ],
      arTexture: 'assets/images/grande_ledge_ta02_tex.png',
      rating: 4.8,
      reviewCount: 91,
      length: '235mm',
      width: '65mm',
      thickness: '15mm',
      size: '235×65×15mm',
      sqftPerBox: 7.20,
      piecesPerBox: 38,
      finish: 'Smooth Colonial',
      texture: 'Refined Clay',
      availableColors: ['Victorian Buff', 'Colonial Red', 'Sand Dune'],
      idealFor: ['Exterior Residential Facade', 'Terrace Gardens', 'Patios'],
      isTrending: false,
      isFeatured: true,
      inStock: true,
      stockQuantity: 190,
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // 13. FLORENTINE SERIES (755 x 125 x 20mm, 8.32 Sqft/Box)
    // ═══════════════════════════════════════════════════════════════════════
    Stone(
      id: 'florentine-15',
      name: 'Florentine 15',
      productCode: 'FLORENTINE 15',
      collection: 'Florentine Series',
      category: 'Designer 3D',
      pricePerSqFt: 520,
      description: 'Inspired by Renaissance architecture in Florence. Exquisite 3D architectural reliefs with handcrafted fluting and carved ornamental motifs.',
      images: [
        'assets/images/collections/florentine_series.jpeg',
        'assets/images/verona_3d.png',
      ],
      arTexture: 'assets/images/verona_3d_tex.png',
      rating: 4.9,
      reviewCount: 104,
      length: '755mm',
      width: '125mm',
      thickness: '20mm',
      size: '755×125×20mm',
      sqftPerBox: 8.32,
      piecesPerBox: 8,
      finish: 'Honed Fluted',
      texture: '3D Renaissance Relief',
      availableColors: ['Palazzo White', 'Florentine Gold', 'Carrara Grey'],
      idealFor: ['Grand Foyers', 'Presidential Suites', 'Dining Room Focal Wall'],
      isTrending: true,
      isFeatured: true,
      isNewArrival: true,
      inStock: true,
      stockQuantity: 110,
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // 14. HEXA SERIES (230 x 200 x 20mm, 6.40 Sqft/Box)
    // ═══════════════════════════════════════════════════════════════════════
    Stone(
      id: 'hexa-207zb',
      name: 'Hexa 207ZB',
      productCode: 'HEXA 207ZB',
      collection: 'Hexa Series',
      category: 'Designer 3D',
      pricePerSqFt: 540,
      description: 'Precision engineered modern hexagonal stone tiles creating dynamic kaleidoscopic shadows and geometrical rhythm on feature walls.',
      images: [
        'assets/images/collections/hexa_series.jpeg',
        'assets/images/verona_3d.png',
      ],
      arTexture: 'assets/images/verona_3d_tex.png',
      rating: 4.9,
      reviewCount: 88,
      length: '230mm',
      width: '200mm',
      thickness: '20mm',
      size: '230×200×20mm',
      sqftPerBox: 6.40,
      piecesPerBox: 14,
      finish: 'Matte Precision',
      texture: 'Geometric Hexagon',
      availableColors: ['Gunmetal Grey', 'Onyx Black', 'Ivory Pearl'],
      idealFor: ['High-End Bar Counter', 'TV Backdrop', 'Executive Cabin'],
      isTrending: true,
      isFeatured: true,
      inStock: true,
      stockQuantity: 140,
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // 15. CAVE SERIES (300 x 300 x 15mm, 7.00 Sqft/Box)
    // ═══════════════════════════════════════════════════════════════════════
    Stone(
      id: 'cave-07',
      name: 'Cave 07',
      productCode: 'CAVE 07',
      collection: 'Cave Series',
      category: 'Designer 3D',
      pricePerSqFt: 490,
      description: 'Evokes the mystical subterranean beauty of ancient cave formations. Deeply gouged organic stone surfaces that play with dramatic lighting.',
      images: [
        'assets/images/products/cave_07.jpeg',
        'assets/images/products/cave_15.jpeg',
      ],
      arTexture: 'assets/images/mountain_ledge_m08_tex.png',
      rating: 4.8,
      reviewCount: 72,
      length: '300mm',
      width: '300mm',
      thickness: '15mm',
      size: '300×300×15mm',
      sqftPerBox: 7.00,
      piecesPerBox: 8,
      finish: 'Cavern Textured',
      texture: 'Subterranean Cleft',
      availableColors: ['Stalagmite Dark', 'Grotto Sand', 'Basalt Shadow'],
      idealFor: ['Lounge Areas', 'Wine Cellars', 'Powder Room Accent'],
      isTrending: false,
      isFeatured: true,
      inStock: true,
      stockQuantity: 95,
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // 16. ALPINE SERIES (640 x 290 x 20mm, 8.52 Sqft/Box)
    // ═══════════════════════════════════════════════════════════════════════
    Stone(
      id: 'alpine-10',
      name: 'Alpine 10',
      productCode: 'ALPINE 10',
      collection: 'Alpine Series',
      category: 'Designer 3D',
      pricePerSqFt: 510,
      description: 'Serene beauty of alpine landscapes with sweeping gentle relief patterns and tranquil earthy color tones.',
      images: [
        'assets/images/products/alpine_10.jpeg',
        'assets/images/products/alpine_203.jpeg',
      ],
      arTexture: 'assets/images/classic_ledge_07_tex.png',
      rating: 4.8,
      reviewCount: 94,
      length: '640mm',
      width: '290mm',
      thickness: '20mm',
      size: '640×290×20mm',
      sqftPerBox: 8.52,
      piecesPerBox: 6,
      finish: 'Alpine Honed',
      texture: 'Smooth Wave Relief',
      availableColors: ['Glacier White', 'Alpine Frost', 'Mont Blanc Stone'],
      idealFor: ['Master Bedroom Bedhead', 'Living Room Alcove', 'Wellness Spa'],
      isTrending: false,
      isFeatured: true,
      inStock: true,
      stockQuantity: 130,
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // 17. VERONA 3D PANEL (600 x 600 x 25mm, 12.0 Sqft/Box)
    // ═══════════════════════════════════════════════════════════════════════
    Stone(
      id: 'verona-3d',
      name: 'Verona 3D Panel',
      productCode: 'VERONA',
      collection: 'Designer 3D Collection',
      category: '3D Wall Panels',
      pricePerSqFt: 550,
      description: 'Sculptural Italian 3D decorative wall panel with architectural relief geometries. Premium focal point for luxury estates and boutique lobbies.',
      images: [
        'assets/images/verona_3d.png',
        'assets/images/onboarding_2.png',
      ],
      arTexture: 'assets/images/verona_3d_tex.png',
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

    // ═══════════════════════════════════════════════════════════════════════
    // 18. ATHENA 3D PANEL (600 x 600 x 30mm, 12.0 Sqft/Box)
    // ═══════════════════════════════════════════════════════════════════════
    Stone(
      id: 'athena-3d',
      name: 'Athena 3D Panel',
      productCode: 'ATHENA',
      collection: 'Designer 3D Collection',
      category: '3D Wall Panels',
      pricePerSqFt: 580,
      description: 'Sculptural 3D panel inspired by classical Greek Parthenon architecture. Creates stunning shadow lines under accent lighting.',
      images: [
        'assets/images/athena_3d.png',
        'assets/images/onboarding_3.png',
      ],
      arTexture: 'assets/images/athena_3d_tex.png',
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
  ];

  static final List<Collection> collections = [
    // --- STONE SERIES (Ledge & Natural Formations) ---
    const Collection(
      id: 'grande-ledge-series',
      name: 'Grande Ledge Series',
      description: 'Rugged textures and clean lines blending modern elegance with natural charm (Size: 490/290/195/100 x 100 x 35mm, 7.00 Sqft/Box)',
      imageUrl: 'assets/images/collections/grande_ledge_series.jpeg',
      stoneCount: 10,
    ),
    const Collection(
      id: 'country-ledge-series',
      name: 'Country Ledge Series',
      description: 'Captures the essence of rustic charm with natural stone textures and earthy tones (Size: 500/300/200 x 100 x 30mm, 7.50 Sqft/Box)',
      imageUrl: 'assets/images/collections/country_ledge_series.jpeg',
      stoneCount: 6,
    ),
    const Collection(
      id: 'mountain-ledge-series',
      name: 'Mountain Ledge Series',
      description: 'Inspired by rugged mountain ranges with coarse unpolished textures (Size: 500/300/200 x 100 x 30mm, 7.50 Sqft/Box)',
      imageUrl: 'assets/images/collections/mountain_ledge_series.jpeg',
      stoneCount: 9,
    ),
    const Collection(
      id: 'classic-ledge-series',
      name: 'Classic Ledge Series',
      description: 'Timeless sophistication with clean horizontal lines and refined textures (Size: 340/200 x 100 x 20mm, 11.40 Sqft/Box)',
      imageUrl: 'assets/images/collections/classic_ledge_series.jpeg',
      stoneCount: 8,
    ),
    const Collection(
      id: 'opus-ledge-series',
      name: 'Opus Ledge Series',
      description: 'Precision set patterns offering seamless installation and insulation (Set Pattern x 30mm, 7.35 Sqft/Box)',
      imageUrl: 'assets/images/collections/opus_ledge_series.jpeg',
      stoneCount: 5,
    ),
    const Collection(
      id: 'vantage-series',
      name: 'Vantage Series',
      description: 'Combines classic aesthetics with modern lightweight functionality (Size: 410 x 150 x 25mm, 6.45 Sqft/Box)',
      imageUrl: 'assets/images/collections/vantage_series.jpeg',
      stoneCount: 3,
    ),
    const Collection(
      id: 'rockface-linear-series',
      name: 'Rockface Linear Series',
      description: 'Sleek linear designs blending natural textures with modern aesthetics (Size: 445 x 110 x 25mm, 6.38 Sqft/Box)',
      imageUrl: 'assets/images/collections/rockface_linear_series.jpeg',
      stoneCount: 6,
    ),
    const Collection(
      id: 'castle-ledge-series',
      name: 'Castle Ledge Series',
      description: 'Bold irregular stones and intricate details inspired by medieval architecture (Size: 305 x 165 x 25mm, 6.60 Sqft/Box)',
      imageUrl: 'assets/images/collections/castle_ledge_series.jpeg',
      stoneCount: 7,
    ),
    const Collection(
      id: 'cuarzo-series',
      name: 'Cuarzo Series',
      description: 'Inspired by the brilliance of quartz with shimmering refined textures (Size: 500/300/200 x 125 x 25mm, 9.35 Sqft/Box)',
      imageUrl: 'assets/images/collections/cuarzo_series.jpeg',
      stoneCount: 3,
    ),
    const Collection(
      id: 'venetian-series',
      name: 'Venetian Series',
      description: 'Italian architectural charm with lightweight durability (Size: 500/300/200 x 120 x 20mm, 8.10 Sqft/Box)',
      imageUrl: 'assets/images/collections/venecia_series.jpeg',
      stoneCount: 3,
    ),
    const Collection(
      id: 'andorra-series',
      name: 'Andorra Series',
      description: 'Alpine terrain textures with deep 45mm clefts (Size: 500/300/200 x 130 x 45mm, 5.40 Sqft/Box)',
      imageUrl: 'assets/images/collections/andorra_series.jpeg',
      stoneCount: 4,
    ),
    const Collection(
      id: 'european-stack-series',
      name: 'European Stack Series',
      description: 'Layered dry-stack architectural masonry for exterior facades (Thickness: 35mm, 5.75 Sqft/Box)',
      imageUrl: 'assets/images/collections/europian_stack_series.jpeg',
      stoneCount: 4,
    ),
    const Collection(
      id: 'veines-series',
      name: 'Veines Series',
      description: 'Replicates natural stone veins found in marble (Size: 510 x 250 x 15mm, 15.12 Sqft/Box)',
      imageUrl: 'assets/images/collections/veines_series.jpeg',
      stoneCount: 3,
    ),
    const Collection(
      id: 'travertine-series',
      name: 'Travertino Series',
      description: 'Soft porous texture and earthy organic variations (Size: 755 x 500 x 15mm, 8.16 Sqft/Box)',
      imageUrl: 'assets/images/collections/travertino_series.jpeg',
      stoneCount: 3,
    ),
    const Collection(
      id: 'sleeper-wood-series',
      name: 'Sleeper Wood Series',
      description: 'Organic wood grain petrified stone textures (Size: 580 x 130 x 25mm, 6.25 Sqft/Box)',
      imageUrl: 'assets/images/collections/sleeper_wood_series.jpeg',
      stoneCount: 3,
    ),
    const Collection(
      id: 'sierra-series',
      name: 'Sierra Series',
      description: 'Untouched mountain charm with bold irregular shapes (Thickness: 35mm, 6.50 Sqft/Box)',
      imageUrl: 'assets/images/collections/sierra_series.jpeg',
      stoneCount: 4,
    ),
    const Collection(
      id: 'fossil-rock-series',
      name: 'Fossil Rock Series',
      description: 'Deep mineralized ancient rock formations (Thickness: 50mm, 5.50 Sqft/Box)',
      imageUrl: 'assets/images/collections/cultured_stone_fossil_rock_series.jpeg',
      stoneCount: 4,
    ),
    const Collection(
      id: 'tivoli-series',
      name: 'Tivoli Series',
      description: 'Hand-carved polished stone aesthetics with smooth surfaces (Size: 600 x 150 x 30mm, 7.42 Sqft/Box)',
      imageUrl: 'assets/images/collections/tivoli_series.jpeg',
      stoneCount: 3,
    ),

    // --- BRICK SERIES ---
    const Collection(
      id: 'rustic-brick-series',
      name: 'Rustic Brick Series',
      description: 'Vintage charm and weathered brickwork inspired by old-world European villages (Size: 195 x 60 x 10mm, 8.12 Sqft/Box)',
      imageUrl: 'assets/images/collections/rustic_brick_series.jpeg',
      stoneCount: 8,
    ),
    const Collection(
      id: 'tarnished-brick-series',
      name: 'Tarnished Brick Series',
      description: 'Antique patina and soft weathered edges for rustic and vintage spaces (Size: 190 x 65 x 15mm, 7.90 Sqft/Box)',
      imageUrl: 'assets/images/collections/tarnished_brick_series.jpeg',
      stoneCount: 6,
    ),
    const Collection(
      id: 'colonial-brick-series',
      name: 'Colonial Brick Series',
      description: 'Inspired by colonial architecture with clean lines and smooth uniform textures (Size: 235 x 65 x 15mm, 7.20 Sqft/Box)',
      imageUrl: 'assets/images/collections/colonial_brick_series.jpeg',
      stoneCount: 6,
    ),
    const Collection(
      id: 'lakhori-brick-series',
      name: 'Lakhori Brick Series',
      description: 'Heritage Mughal-era and colonial architectural charm (Size: 535 x 160 x 35mm, 6.40 Sqft/Box)',
      imageUrl: 'assets/images/collections/rustic_brick_series.jpeg',
      stoneCount: 4,
    ),

    // --- DESIGNER STONES & 3D RELIEF ---
    const Collection(
      id: 'florentine-series',
      name: 'Florentine Series',
      description: 'Intricate detailing and refined textures inspired by Florentine architecture (Size: 755 x 125 x 20mm, 8.32 Sqft/Box)',
      imageUrl: 'assets/images/collections/florentine_series.jpeg',
      stoneCount: 7,
    ),
    const Collection(
      id: 'foliage-series',
      name: 'Foliage Series',
      description: 'Botanical leaf patterns and organic textures reflecting nature harmony (Size: 600 x 300/150 x 15mm, 11.55 Sqft/Box)',
      imageUrl: 'assets/images/collections/foliage_series.jpeg',
      stoneCount: 3,
    ),
    const Collection(
      id: 'flora-series',
      name: 'Flora Series',
      description: 'Botanical elegance with intricate floral-inspired textures (Size: 600/450 x 300/150 x 20mm, 10.65 Sqft/Box)',
      imageUrl: 'assets/images/collections/flora_series.jpeg',
      stoneCount: 3,
    ),
    const Collection(
      id: 'vine-series',
      name: 'Vine Series',
      description: 'Climbing vine natural movement for artistic luxury interiors (Size: 600 x 200 x 25mm, 7.74 Sqft/Box)',
      imageUrl: 'assets/images/collections/vine_series.jpeg',
      stoneCount: 3,
    ),
    const Collection(
      id: 'hexa-series',
      name: 'Hexa Series',
      description: 'Striking modern geometric hexagonal designs with precision natural stone (Size: 230 x 200 x 20mm, 6.40 Sqft/Box)',
      imageUrl: 'assets/images/collections/hexa_series.jpeg',
      stoneCount: 4,
    ),
    const Collection(
      id: 'modena-series',
      name: 'Modena Series',
      description: 'Italian minimalist design with smooth surfaces and neutral palettes (Size: 600 x 150 x 15mm, 11.55 Sqft/Box)',
      imageUrl: 'assets/images/collections/modena_series.jpeg',
      stoneCount: 3,
    ),
    const Collection(
      id: 'cave-series',
      name: 'Cave Series',
      description: 'Rugged untouched ancient cave formations and irregular patterns (Size: 300 x 300 x 15mm, 7.00 Sqft/Box)',
      imageUrl: 'assets/images/collections/cave_series.jpeg',
      stoneCount: 3,
    ),
    const Collection(
      id: 'egyptian-series',
      name: 'Egyptian Series',
      description: 'Grandeur of ancient Egyptian linear geometry and timeless luxury (Size: 600 x 100 x 20mm, 6.45 Sqft/Box)',
      imageUrl: 'assets/images/collections/egyption_series.jpeg',
      stoneCount: 3,
    ),
    const Collection(
      id: 'weave-series',
      name: 'Weave Series',
      description: 'Tactile woven textile elegance cast in durable natural stone (Size: 300 x 300 x 25mm, 7.00 Sqft/Box)',
      imageUrl: 'assets/images/collections/weave_series.jpeg',
      stoneCount: 3,
    ),
    const Collection(
      id: 'milano-series',
      name: 'Milano Series',
      description: 'Milanese elegance with clean lines and contemporary tones (Size: 895/595 x 595 x 25mm, 5.81 Sqft/Box)',
      imageUrl: 'assets/images/collections/milano_series.jpeg',
      stoneCount: 3,
    ),
    const Collection(
      id: 'alpine-series',
      name: 'Alpine Series',
      description: 'Serene beauty of alpine landscapes with soft textures and tranquil tones (Size: 640 x 290 x 20mm, 8.52 Sqft/Box)',
      imageUrl: 'assets/images/collections/alpine_series.jpeg',
      stoneCount: 5,
    ),
    const Collection(
      id: 'designer-3d-collection',
      name: 'Designer 3D Collection',
      description: 'Hand-sculpted Italian 3D relief panels creating monumental shadow lines and luxury focal statements',
      imageUrl: 'assets/images/verona_3d.png',
      stoneCount: 6,
    ),
  ];

  static final List<Dealer> dealers = [
    const Dealer(
      id: 'dealer-0',
      name: 'Grazia Stones Flagship Experience Center',
      address: '123/477, Kalpi Road, Fazalganj, Kanpur',
      phone: '+91 9839846105',
      distance: '0.8 km',
      rating: 5.0,
      isAuthorized: true,
    ),
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
    if (stones.isEmpty) return null;
    final target = id.toLowerCase().trim();
    try {
      return stones.firstWhere(
        (s) => s.id.toLowerCase() == target || s.productCode.toLowerCase() == target,
        orElse: () => stones.firstWhere(
          (s) => s.id.toLowerCase().contains(target) || target.contains(s.id.toLowerCase()),
          orElse: () => stones.first,
        ),
      );
    } catch (_) {
      return stones.first;
    }
  }

  static List<Stone> getAllStones() {
    return stones;
  }

  static List<Stone> getStonesByCollection(String collectionId) {
    final target = collectionId.toLowerCase().trim();
    final matched = stones.where((s) {
      final slug = s.collection.toLowerCase().replaceAll(' ', '-');
      final name = s.collection.toLowerCase();
      return slug == target ||
             name == target ||
             slug.contains(target) ||
             target.contains(slug) ||
             name.contains(target) ||
             target.contains(name) ||
             (target.length > 4 && (name.contains(target.split('-').first) || slug.contains(target.split('-').first)));
    }).toList();

    if (matched.isNotEmpty) return matched;

    final col = collections.where((c) =>
      c.id.toLowerCase() == target ||
      c.name.toLowerCase().replaceAll(' ', '-') == target ||
      c.name.toLowerCase().contains(target) ||
      target.contains(c.id.toLowerCase())
    ).firstOrNull;

    if (col != null) {
      final codePrefix = col.name.split(' ').first.toUpperCase();
      return [
        Stone(
          id: '${col.id}-01',
          name: '${col.name} Prime',
          productCode: '$codePrefix 01',
          collection: col.name,
          category: col.categoryType,
          pricePerSqFt: 395,
          description: '${col.description}. Certified authentic architectural cultured stone surface.',
          images: [col.effectiveBannerImage],
          rating: 4.9,
          reviewCount: 112,
          size: col.dimensionSpec,
          thickness: col.thicknessSpec,
          sqftPerBox: double.tryParse(col.coverageSpec.split(' ').first) ?? 7.5,
          finish: 'Natural Architectural',
          texture: col.categoryType,
          availableColors: ['Ash Grey', 'Natural Earth', 'Oatmeal Buff'],
          idealFor: ['Luxury Feature Wall', 'Facade Cladding', 'Interior Focal Point'],
          isFeatured: true,
          inStock: true,
          stockQuantity: 150,
        ),
        Stone(
          id: '${col.id}-02',
          name: '${col.name} Heritage',
          productCode: '$codePrefix 02',
          collection: col.name,
          category: col.categoryType,
          pricePerSqFt: 420,
          description: 'Aged mineral patina with deeper shade contrasts, capturing timeless architectural aesthetics.',
          images: [col.effectiveBannerImage],
          rating: 4.8,
          reviewCount: 78,
          size: col.dimensionSpec,
          thickness: col.thicknessSpec,
          sqftPerBox: double.tryParse(col.coverageSpec.split(' ').first) ?? 7.5,
          finish: 'Textured Relief',
          texture: col.categoryType,
          availableColors: ['Desert Amber', 'Smoked Slate', 'Golden Sand'],
          idealFor: ['Living Room Accent', 'Exterior Pillars', 'Courtyard'],
          isFeatured: false,
          inStock: true,
          stockQuantity: 120,
        ),
        Stone(
          id: '${col.id}-03',
          name: '${col.name} Modern',
          productCode: '$codePrefix 03',
          collection: col.name,
          category: col.categoryType,
          pricePerSqFt: 440,
          description: 'Contemporary balanced clefting with subtle tonal gradations under architectural lighting.',
          images: [col.effectiveBannerImage],
          rating: 4.8,
          reviewCount: 64,
          size: col.dimensionSpec,
          thickness: col.thicknessSpec,
          sqftPerBox: double.tryParse(col.coverageSpec.split(' ').first) ?? 7.5,
          finish: 'Split Honed',
          texture: col.categoryType,
          availableColors: ['Graphite Mist', 'Charcoal', 'Ivory'],
          idealFor: ['Hotel Suite', 'Dining Alcove', 'Patio Wall'],
          isFeatured: false,
          inStock: true,
          stockQuantity: 95,
        ),
      ];
    }

    return stones;
  }

  static List<Stone> getTrendingStones() {
    final trending = stones.where((s) => s.isTrending).toList();
    return trending.isNotEmpty ? trending : stones;
  }

  static List<Dealer> getAllDealers() {
    return dealers;
  }

  static List<Stone> searchStones(String query) {
    if (query.isEmpty) return stones;
    final q = query.toLowerCase();
    return stones.where((s) =>
      s.name.toLowerCase().contains(q) ||
      s.productCode.toLowerCase().contains(q) ||
      s.collection.toLowerCase().contains(q) ||
      s.category.toLowerCase().contains(q) ||
      s.description.toLowerCase().contains(q)
    ).toList();
  }

  static List<Collection> getAllCollections() {
    return collections;
  }
}
