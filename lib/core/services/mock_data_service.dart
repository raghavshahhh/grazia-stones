import '../models/stone.dart';
import '../models/collection.dart';
import '../models/dealer.dart';

class MockDataService {
  static final List<Stone> stones = [
    Stone(
      id: 'charcoal-black',
      name: 'Charcoal Black',
      collection: 'Royal Marble',
      pricePerSqFt: 180,
      description: 'Deep charcoal tones with subtle silver veining create a sophisticated backdrop for luxury interiors.',
      rating: 4.8,
      reviewCount: 124,
      thickness: '18-20mm',
      finish: 'Polished',
      size: '600x300',
      origin: 'Italy',
      availableColors: const ['#1C1C1E', '#2D2D2D', '#3A3A3A', '#4A4A4A'],
      isTrending: true,
      imageUrl: 'https://image.pollinations.ai/prompt/luxury%20charcoal%20black%20marble%20slab%20texture%20with%20silver%20veining%20polished%20surface%20studio%20lighting%20product%20photography?width=512&height=512',
    ),
    Stone(
      id: 'accent-gold',
      name: 'Accent Gold',
      collection: 'Royal Marble',
      pricePerSqFt: 320,
      description: 'Rich golden hues with dramatic veining patterns that exude opulence.',
      rating: 4.9,
      reviewCount: 89,
      thickness: '18-20mm',
      finish: 'Honed',
      size: '600x300',
      origin: 'Italy',
      availableColors: const ['#C9A84C', '#D4AF37', '#B8860B', '#DAA520'],
      isTrending: true,
      imageUrl: 'https://image.pollinations.ai/prompt/luxury%20golden%20marble%20slab%20with%20dramatic%20veining%20honed%20finish%20studio%20lighting%20product%20photography?width=512&height=512',
    ),
    Stone(
      id: 'imperial-travertine',
      name: 'Imperial Travertine',
      collection: 'Heritage',
      pricePerSqFt: 24,
      description: 'Timeless elegance with warm ivory tones and natural veining patterns. Perfect for luxury wall cladding.',
      rating: 4.7,
      reviewCount: 156,
      thickness: '18-20mm',
      finish: 'Honed',
      size: '600x300',
      origin: 'Italy',
      availableColors: const ['#F5F5DC', '#E8D5B7', '#D2B48C', '#C4A882'],
      isTrending: true,
      imageUrl: 'https://image.pollinations.ai/prompt/imperial%20travertine%20stone%20slab%20warm%20ivory%20tones%20natural%20veining%20honed%20finish%20luxury%20product%20photography?width=512&height=512',
    ),
    Stone(
      id: 'graphite-grey',
      name: 'Graphite Grey',
      collection: 'Contemporary',
      pricePerSqFt: 210,
      description: 'Sleek grey tones with minimal veining for modern architectural spaces.',
      rating: 4.6,
      reviewCount: 98,
      thickness: '18-20mm',
      finish: 'Polished',
      size: '600x300',
      origin: 'Spain',
      availableColors: const ['#36454F', '#696969', '#808080', '#A9A9A9'],
      isTrending: true,
      imageUrl: 'https://image.pollinations.ai/prompt/sleek%20graphite%20grey%20marble%20slab%20minimal%20veining%20polished%20modern%20architectural%20product%20photography?width=512&height=512',
    ),
    Stone(
      id: 'walnut-brown',
      name: 'Walnut Brown',
      collection: 'Heritage',
      pricePerSqFt: 195,
      description: 'Warm walnut tones with organic patterns inspired by nature.',
      rating: 4.5,
      reviewCount: 67,
      thickness: '18-20mm',
      finish: 'Leathered',
      size: '600x300',
      origin: 'India',
      availableColors: const ['#5C4033', '#6B4423', '#8B5A2B', '#A0522D'],
      isTrending: false,
      imageUrl: 'https://image.pollinations.ai/prompt/warm%20walnut%20brown%20stone%20slab%20organic%20patterns%20leathered%20finish%20natural%20beauty%20product%20photography?width=512&height=512',
    ),
    Stone(
      id: 'matte-white',
      name: 'Matte White',
      collection: 'Contemporary',
      pricePerSqFt: 165,
      description: 'Pure white with subtle texture for minimalist luxury.',
      rating: 4.4,
      reviewCount: 112,
      thickness: '18-20mm',
      finish: 'Matte',
      size: '600x300',
      origin: 'Greece',
      availableColors: const ['#FFFAFA', '#F5F5F5', '#DCDCDC', '#C0C0C0'],
      isTrending: false,
      imageUrl: 'https://image.pollinations.ai/prompt/pure%20white%20marble%20slab%20subtle%20texture%20matte%20finish%20minimalist%20luxury%20product%20photography?width=512&height=512',
    ),
    Stone(
      id: 'brushed-silver',
      name: 'Brushed Silver',
      collection: 'Contemporary',
      pricePerSqFt: 275,
      description: 'Metallic silver finish with industrial-chic appeal.',
      rating: 4.7,
      reviewCount: 54,
      thickness: '18-20mm',
      finish: 'Brushed',
      size: '600x300',
      origin: 'Italy',
      availableColors: const ['#C0C0C0', '#A8A8A8', '#B0B0B0', '#D3D3D3'],
      isTrending: false,
      imageUrl: 'https://image.pollinations.ai/prompt/brushed%20silver%20metallic%20stone%20slab%20industrial%20chic%20finish%20luxury%20product%20photography?width=512&height=512',
    ),
  ];

  static final List<Collection> collections = [
    const Collection(id: 'royal-marble', name: 'Royal Marble', description: 'Premium Italian marbles for luxury spaces', stoneCount: 2),
    const Collection(id: 'heritage', name: 'Heritage', description: 'Timeless stones with rich history', stoneCount: 2),
    const Collection(id: 'contemporary', name: 'Contemporary', description: 'Modern stones for modern spaces', stoneCount: 3),
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

  static List<Stone> getStonesByCollection(String collectionId) {
    return stones.where((s) => s.collection.toLowerCase().replaceAll(' ', '-') == collectionId).toList();
  }

  static List<Stone> getTrendingStones() {
    return stones.where((s) => s.isTrending).toList();
  }
}
