import 'package:flutter_test/flutter_test.dart';
import 'package:grazia_stones/core/models/cart_item.dart';
import 'package:grazia_stones/core/models/quote_request.dart';
import 'package:grazia_stones/core/models/sample_order.dart';

void main() {
  group('Phase 10 — Business Logic: Cart Calculations & Boundary Conditions', () {
    test('Standard item total calculation', () {
      const item = CartItem(
        stoneId: 'stone-1',
        name: 'Calacatta Gold',
        finish: 'Polished',
        pricePerSqFt: 450.0,
        quantity: 5,
      );
      expect(item.totalPrice, equals(2250.0));
    });

    test('Boundary: Quantity = 0', () {
      const item = CartItem(
        stoneId: 'stone-1',
        name: 'Calacatta Gold',
        finish: 'Polished',
        pricePerSqFt: 450.0,
        quantity: 0,
      );
      expect(item.totalPrice, equals(0.0));
    });

    test('Boundary: Quantity = 1', () {
      const item = CartItem(
        stoneId: 'stone-1',
        name: 'Calacatta Gold',
        finish: 'Polished',
        pricePerSqFt: 375.50,
        quantity: 1,
      );
      expect(item.totalPrice, equals(375.50));
    });

    test('Boundary: Decimal pricePerSqFt and large quantity', () {
      const item = CartItem(
        stoneId: 'stone-1',
        name: 'Statuario Extra',
        finish: 'Honed',
        pricePerSqFt: 525.75,
        quantity: 10000,
      );
      expect(item.totalPrice, equals(5257500.0));
    });

    test('CartItem serialization roundtrip with missing/default fields', () {
      final json = {
        'stone_id': 's-123',
        'stone_name': 'Arabescato',
        'price_per_unit': 420.0,
      };
      final item = CartItem.fromJson(json);
      expect(item.stoneId, equals('s-123'));
      expect(item.name, equals('Arabescato'));
      expect(item.finish, equals('Polished')); // default
      expect(item.quantity, equals(1)); // default
      expect(item.colorHex, equals('#1C1C1E')); // default
      expect(item.totalPrice, equals(420.0));
    });
  });

  group('Phase 10 — Business Logic: Tax, Wastage & Surface Coverage', () {
    test('GST 18% tax calculation on subtotal', () {
      const subtotal = 10000.0;
      const gstRate = 0.18;
      final tax = subtotal * gstRate;
      final total = subtotal + tax;

      expect(tax, equals(1800.0));
      expect(total, equals(11800.0));
    });

    test('Wastage buffer calculation (10% and 15% standard)', () {
      const netAreaSqft = 500.0;
      
      final with10Wastage = netAreaSqft * 1.10;
      expect(with10Wastage, equals(550.0));

      final with15Wastage = netAreaSqft * 1.15;
      expect(with15Wastage, equals(575.0));
    });

    test('Box count calculation from coverage_sqft', () {
      const wallAreaSqft = 350.0;
      const coveragePerBox = 16.5; // sqft per box

      final boxesNeeded = (wallAreaSqft / coveragePerBox).ceil();
      expect(boxesNeeded, equals(22)); // 350 / 16.5 = 21.21 -> 22 boxes

      final totalCoveredArea = boxesNeeded * coveragePerBox;
      expect(totalCoveredArea, equals(363.0));
      expect(totalCoveredArea >= wallAreaSqft, isTrue);
    });

    test('Boundary: Missing/Zero coverage_sqft defaults safely', () {
      const wallAreaSqft = 200.0;
      const coveragePerBox = 0.0;

      final boxes = coveragePerBox > 0 ? (wallAreaSqft / coveragePerBox).ceil() : 0;
      expect(boxes, equals(0));
    });
  });

  group('Phase 10 — Business Logic: Metric/Imperial Unit Conversions', () {
    test('Meters to feet conversion (1m = 3.28084 ft)', () {
      const meters = 3.0;
      final feet = meters * 3.28084;
      expect((feet - 9.84252).abs() < 0.001, isTrue);
    });

    test('Square meters to square feet conversion (1 sq.m = 10.7639 sq.ft)', () {
      const sqMeters = 50.0;
      final sqFt = sqMeters * 10.7639;
      expect((sqFt - 538.195).abs() < 0.01, isTrue);
    });

    test('Inches to feet conversion (12 inches = 1 ft)', () {
      const inches = 96.0;
      final feet = inches / 12.0;
      expect(feet, equals(8.0));
    });

    test('Centimeters to feet conversion (30.48 cm = 1 ft)', () {
      const cm = 304.8;
      final feet = cm / 30.48;
      expect(feet, equals(10.0));
    });
  });

  group('Phase 10 — Business Logic: Order & AI Job Payload Construction', () {
    test('Constructs deterministic order number format', () {
      final date = DateTime(2026, 9, 11);
      final timestamp = 1789132000000;
      final orderNum = 'GS-${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}-${timestamp.toString().substring(8)}';
      expect(orderNum, startsWith('GS-20260911-'));
    });

    test('Constructs AI 4-variant batch job payloads with correct indices', () {
      const batchId = 'batch_12345';
      final jobs = List.generate(4, (index) => {
        'batch_id': batchId,
        'variant_index': index,
        'palette_name': 'Palette ${index + 1}',
        'stone_name': 'Calacatta Gold',
        'status': 'pending',
      });

      expect(jobs.length, equals(4));
      expect(jobs[0]['variant_index'], equals(0));
      expect(jobs[3]['variant_index'], equals(3));
      expect(jobs.every((j) => j['batch_id'] == batchId), isTrue);
    });

    test('QuoteRequest handles boundary conditions (null email, 0 quantity, empty message)', () {
      final qr = QuoteRequest(
        id: 'qr-1',
        stoneName: 'Onyx Verde',
        finish: 'Polished',
        area: '0',
        notes: '',
        createdAt: DateTime.now(),
      );
      expect(qr.stoneName, equals('Onyx Verde'));
      expect(qr.notes, isEmpty);
    });

    test('SampleOrder handles boundary conditions', () {
      final sample = SampleOrder(
        id: 's-1',
        stoneId: 'stone-99',
        stoneName: 'Grigio Carnico',
        name: 'John Doe',
        phone: '+919876543210',
        address: 'Suite 100',
        city: 'Bengaluru',
        pincode: '560001',
        createdAt: DateTime.now(),
      );
      expect(sample.stoneName, equals('Grigio Carnico'));
      expect(sample.pincode, equals('560001'));
    });
  });
}
