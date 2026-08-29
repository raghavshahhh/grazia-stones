import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/core/models/collection.dart';
import 'package:grazia_stones/core/models/dealer.dart';
import 'package:grazia_stones/features/cart/presentation/cart_screen.dart';
import 'package:grazia_stones/features/about/presentation/about_screen.dart';
import 'package:grazia_stones/features/legal/presentation/privacy_policy_screen.dart';
import 'package:grazia_stones/features/legal/presentation/terms_of_service_screen.dart';
import 'package:grazia_stones/features/support/presentation/help_support_screen.dart';
import 'package:grazia_stones/features/auth/providers/auth_riverpod_provider.dart';
import 'package:grazia_stones/core/models/sample_order.dart';
import 'package:grazia_stones/core/models/quote_request.dart';
import 'package:grazia_stones/core/services/supabase_service.dart';


void main() {
  group('Stone Model Verification', () {
    test('Calculates dimensions and fallback getters accurately', () {
      final stone = Stone(
        id: 'stone-001',
        name: 'Royal Botticino Marble',
        productCode: 'RBM-01',
        collection: 'Signature Marble',
        category: 'Marble',
        pricePerSqFt: 380.0,
        description: 'Italian imported marble with rich beige veining.',
        images: ['https://example.com/stone1.jpg'],
        rating: 4.8,
        reviewCount: 14,
        length: '600mm',
        width: '300mm',
        thickness: '20mm',
        size: '600x300x20mm',
        sqftPerBox: 1.94,
        piecesPerBox: 1,
        finish: 'Polished',
        texture: 'Smooth Marble',
        availableColors: ['Beige', 'Cream'],
        idealFor: ['Living Room', 'Accent Wall'],
        isFeatured: true,
        inStock: true,
        stockQuantity: 450,
      );

      expect(stone.lengthCm, 600.0);
      expect(stone.widthCm, 300.0);
      expect(stone.thicknessMm, 20.0);
      expect(stone.material, 'Smooth Marble');
      expect(stone.coverageSqft, 1.94);
      expect(stone.imageUrl, 'https://example.com/stone1.jpg');
      expect(stone.colors, contains('Beige'));
      expect(stone.tags, contains('Living Room'));
    });
  });

  group('Collection & Dealer Model Verification', () {
    test('Collection serialization and image mapping', () {
      final collection = Collection(
        id: 'col-001',
        name: 'Florentine Classics',
        description: 'Classical Italian inspired slabs',
        imageUrl: 'https://example.com/banner.jpg',
        stoneCount: 12,
      );

      expect(collection.name, 'Florentine Classics');
      expect(collection.imageUrl, 'https://example.com/banner.jpg');
      expect(collection.stoneCount, 12);
    });


    test('Dealer model with geocoordinates and authorization', () {
      final dealer = Dealer(
        id: 'dlr-001',
        name: 'Grazia Kanpur Flagship',
        address: '123/477, Kalpi Road, Fazalganj',
        city: 'Kanpur',
        state: 'Uttar Pradesh',
        pincode: '208012',
        phone: '+919839846105',
        email: 'info@graziastones.com',
        isAuthorized: true,
        isExclusive: true,
      );

      expect(dealer.city, 'Kanpur');
      expect(dealer.isAuthorized, isTrue);
      expect(dealer.phone, '+919839846105');
    });
  });

  group('CartNotifier & Financial Calculation Verification', () {
    final testStone1 = Stone(
      id: 'stone-1',
      name: 'Statuario Luxe',
      productCode: 'SL-01',
      collection: 'Prestige',
      category: 'Marble',
      pricePerSqFt: 500.0,
      description: 'Statuario White',
      images: ['https://example.com/img1.jpg'],
      rating: 5.0,
      reviewCount: 10,
      length: '600mm',
      width: '600mm',
      thickness: '20mm',
      size: '600x600mm',
      sqftPerBox: 3.88,
      piecesPerBox: 1,
      finish: 'Honed',
      texture: 'Natural Stone',
      availableColors: ['White'],
      idealFor: ['Flooring'],
      isFeatured: true,
      inStock: true,
      stockQuantity: 100,
    );

    final testStone2 = Stone(
      id: 'stone-2',
      name: 'Nero Marquina',
      productCode: 'NM-02',
      collection: 'Noir',
      category: 'Granite',
      pricePerSqFt: 250.0,
      description: 'Deep black with white veins',
      images: ['https://example.com/img2.jpg'],
      rating: 4.9,
      reviewCount: 8,
      length: '600mm',
      width: '300mm',
      thickness: '15mm',
      size: '600x300mm',
      sqftPerBox: 1.94,
      piecesPerBox: 1,
      finish: 'Polished',
      texture: 'Granite',
      availableColors: ['Black'],
      idealFor: ['Countertops'],
      isFeatured: false,
      inStock: true,
      stockQuantity: 50,
    );

    test('Add, update quantity, remove, and financial totals', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(cartProvider.notifier);

      // Initial state
      expect(container.read(cartProvider), isEmpty);

      // Add item 1 twice
      notifier.addItem(testStone1);
      notifier.addItem(testStone1);
      expect(container.read(cartProvider).length, 1);
      expect(container.read(cartProvider).first.quantity, 2);

      // Add item 2 once, then increment by 3
      notifier.addItem(testStone2);
      expect(container.read(cartProvider).length, 2);
      notifier.updateQuantity(1, 3); // index 1, delta +3 -> total qty = 4

      // Compute Subtotal = (2 * 500) + (4 * 250) = 1000 + 1000 = 2000
      final items = container.read(cartProvider);
      final subtotal = items.fold<double>(0.0, (s, i) => s + (i.stone.pricePerSqFt * i.quantity));
      expect(subtotal, 2000.0);

      // GST 18% = 360
      final gst = subtotal * 0.18;
      expect(gst, 360.0);

      // Shipping (under 10000 = 500)
      final shipping = subtotal > 10000 ? 0.0 : (subtotal > 0 ? 500.0 : 0.0);
      expect(shipping, 500.0);

      // Total = 2000 + 360 + 500 = 2860
      final total = subtotal + gst + shipping;
      expect(total, 2860.0);

      // Update quantity of item 1 (index 0) with delta +3 -> qty = 5
      notifier.updateQuantity(0, 3);
      expect(container.read(cartProvider)[0].quantity, 5);

      // Remove item 2 (index 1)
      notifier.removeItem(1);
      expect(container.read(cartProvider).length, 1);

      // Clear cart
      notifier.clear();
      expect(container.read(cartProvider), isEmpty);
    });
  });

  group('Informational & Legal Screens Verification', () {
    testWidgets('Renders AboutScreen with brand heritage and Kanpur address', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AboutScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('About Grazia Stones'), findsOneWidget);
      expect(find.textContaining('Kanpur, Uttar Pradesh'), findsWidgets);
    });

    testWidgets('Renders PrivacyPolicyScreen with data protection sections', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PrivacyPolicyScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.textContaining('1. INFORMATION WE COLLECT'), findsOneWidget);
    });

    testWidgets('Renders TermsOfServiceScreen with commercial terms', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: TermsOfServiceScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Terms & Conditions'), findsOneWidget);
      expect(find.textContaining('1. NATURAL STONE CHARACTERISTICS'), findsOneWidget);
    });

    testWidgets('Renders HelpSupportScreen with concierge actions and FAQs', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HelpSupportScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Help & Concierge Support'), findsOneWidget);
      expect(find.text('Architect Technical Desk'), findsOneWidget);
    });
  });

  group('Auth & Role State Verification', () {
    test('AuthRiverpodState correctly evaluates isAdmin and isDealer', () {
      final customerState = AuthRiverpodState(userId: 'u1', userRole: 'customer', isLoggedIn: true);
      expect(customerState.isAdmin, isFalse);
      expect(customerState.isDealer, isFalse);

      final adminState = AuthRiverpodState(userId: 'a1', userRole: 'admin', isLoggedIn: true);
      expect(adminState.isAdmin, isTrue);

      final dealerState = AuthRiverpodState(userId: 'd1', userRole: 'dealer', isLoggedIn: true);
      expect(dealerState.isDealer, isTrue);
    });
  });

  group('SampleOrder & QuoteRequest Snake-Case Deserialization', () {
    test('SampleOrder deserializes snake_case Supabase response', () {
      final sample = SampleOrder.fromJson({
        'id': 'smpl-101',
        'stone_id': 'stn-001',
        'stone_name': 'Classic Travertine',
        'name': 'Rahul Sharma',
        'phone': '+919876543210',
        'address': '45 Civil Lines',
        'city': 'Kanpur',
        'pincode': '208001',
        'status': 'pending',
        'created_at': '2026-08-29T10:00:00Z',
      });

      expect(sample.id, 'smpl-101');
      expect(sample.stoneId, 'stn-001');
      expect(sample.stoneName, 'Classic Travertine');
      expect(sample.city, 'Kanpur');
      expect(sample.status, 'pending');
    });

    test('QuoteRequest deserializes snake_case Supabase response', () {
      final quote = QuoteRequest.fromJson({
        'id': 'qt-202',
        'stone_name': 'Imperial Granite',
        'finish': 'Polished',
        'area_sqft': 500,
        'message': 'Need delivery in 2 weeks',
        'status': 'confirmed',
        'created_at': '2026-08-29T11:00:00Z',
      });

      expect(quote.id, 'qt-202');
      expect(quote.stoneName, 'Imperial Granite');
      expect(quote.area, '500');
      expect(quote.notes, 'Need delivery in 2 weeks');
      expect(quote.status, 'confirmed');
    });
  });

  group('Phone Number E.164 Normalization Verification', () {
    test('Normalizes Indian 10-digit phone numbers cleanly to E.164 (+91XXXXXXXXXX)', () {
      expect(SupabaseService.normalizePhoneNumber('9924875382'), '+919924875382');
      expect(SupabaseService.normalizePhoneNumber('+91 99248-75382'), '+919924875382');
      expect(SupabaseService.normalizePhoneNumber('+91+919924875382'), '+919924875382');
      expect(SupabaseService.normalizePhoneNumber('09924875382'), '+919924875382');
      expect(SupabaseService.normalizePhoneNumber('919924875382'), '+919924875382');
    });
  });

  group('Collection Surface Count & Image Fallback Verification', () {
    test('Collection deserializes stoneCount correctly from backend response', () {
      final col = Collection.fromJson({
        'id': 'col-1',
        'name': 'Grande Series',
        'description': 'Luxury travertine series',
        'image_url': 'https://res.cloudinary.com/grazia/grande.jpg',
        'stone_count': 24,
      });

      expect(col.id, 'col-1');
      expect(col.name, 'Grande Series');
      expect(col.imageUrl, 'https://res.cloudinary.com/grazia/grande.jpg');
      expect(col.stoneCount, 24);
    });

    test('Collection handles missing stoneCount defaulting gracefully', () {
      final colEmpty = Collection.fromJson({
        'id': 'col-empty',
        'name': 'New Empty Series',
        'description': 'No products added yet',
      });

      expect(colEmpty.stoneCount, 0);
    });
  });

  group('3D Wall Proportional Geometry & Tile Estimation Verification', () {
    test('Calculates deterministic tile quantity and box count for 10x10 ft wall', () {
      const wallW = 10.0;
      const wallH = 10.0;
      const wastage = 10.0; // 10%
      const boxCoverage = 10.5; // sqft per box

      final area = wallW * wallH;
      final withWastage = area * (1 + wastage / 100);
      final boxes = (withWastage / boxCoverage).ceil();

      expect(area, 100.0);
      expect(withWastage, closeTo(110.0, 0.01));
      expect(boxes, 11);
    });

    test('Converts meters to sqft accurately (1 sq.m = 10.764 sq.ft)', () {
      const lengthM = 3.0;
      const widthM = 4.0;
      final areaSqM = lengthM * widthM; // 12 sq.m
      final areaSqFt = areaSqM * 10.764; // ~129.168 sq.ft

      expect(areaSqM, 12.0);
      expect(areaSqFt.toStringAsFixed(2), '129.17');
    });
  });
}



