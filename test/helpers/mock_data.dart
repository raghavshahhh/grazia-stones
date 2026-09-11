/// Mock data for testing
library;

/// Mock stone product data
class MockData {
  static const Map<String, dynamic> mockStone = {
    'id': '550e8400-e29b-41d4-a716-446655440000',
    'name': 'Italian Carrara Marble',
    'category': 'natural-stones',
    'finish': 'polished',
    'price': 8500.00,
    'currency': 'INR',
    'dimensions': '600x600mm',
    'thickness': '20mm',
    'description': 'Premium Italian marble with distinctive grey veining',
    'imageUrl': 'https://placeholder.com/marble.jpg',
    'inStock': true,
    'rating': 4.8,
    'reviewCount': 127,
  };
  
  static const Map<String, dynamic> mockCollection = {
    'id': '550e8400-e29b-41d4-a716-446655440001',
    'name': 'Premium Marble Collection',
    'description': 'Finest marble selections from Italy',
    'imageUrl': 'https://placeholder.com/collection.jpg',
    'stoneCount': 24,
  };
  
  static const Map<String, dynamic> mockUser = {
    'id': 'user-123',
    'email': 'test@graziastones.com',
    'name': 'Test User',
    'role': 'customer',
    'phone': '+91 9876543210',
  };
  
  static const Map<String, dynamic> mockAdmin = {
    'id': 'admin-123',
    'email': 'admin@graziastones.com',
    'name': 'Admin User',
    'role': 'admin',
    'permissions': ['all'],
  };
  
  static const Map<String, dynamic> mockAddress = {
    'id': 'addr-123',
    'name': 'Home',
    'line1': '123 Test Street',
    'line2': 'Apartment 4B',
    'city': 'Mumbai',
    'state': 'Maharashtra',
    'pincode': '400001',
    'phone': '+91 9876543210',
  };
  
  static const Map<String, dynamic> mockOrder = {
    'id': 'order-123',
    'orderNumber': 'GS2026091100001',
    'status': 'pending',
    'totalAmount': 8500.00,
    'currency': 'INR',
    'createdAt': '2026-09-11T00:00:00Z',
    'items': [
      {
        'stoneId': '550e8400-e29b-41d4-a716-446655440000',
        'quantity': 1,
        'price': 8500.00,
      }
    ],
  };
  
  static const List<Map<String, String>> mockRoutes = [
    {'name': 'Home', 'path': '/'},
    {'name': 'Catalogue', 'path': '/catalogue'},
    {'name': 'Collections', 'path': '/collections'},
    {'name': 'Cart', 'path': '/cart'},
    {'name': 'Wishlist', 'path': '/wishlist'},
    {'name': 'Profile', 'path': '/profile'},
    {'name': 'Orders', 'path': '/orders'},
    {'name': 'Addresses', 'path': '/addresses'},
    {'name': 'Dealers', 'path': '/dealers'},
    {'name': 'About', 'path': '/about'},
    {'name': 'Contact', 'path': '/contact'},
    {'name': 'Privacy', 'path': '/privacy'},
    {'name': 'Terms', 'path': '/terms'},
    {'name': 'AR Studio', 'path': '/tools/ar-studio'},
    {'name': 'Wall Visualizer', 'path': '/tools/wall-visualizer'},
    {'name': 'Measure Tool', 'path': '/tools/measure'},
    {'name': 'Admin Dashboard', 'path': '/admin'},
    {'name': 'Admin Products', 'path': '/admin/products'},
    {'name': 'Admin Orders', 'path': '/admin/orders'},
    {'name': 'Admin Users', 'path': '/admin/users'},
  ];
  
  /// Generate list of mock stones
  static List<Map<String, dynamic>> generateMockStones(int count) {
    return List.generate(count, (index) => {
      ...mockStone,
      'id': 'stone-$index',
      'name': 'Stone $index',
    });
  }
}
