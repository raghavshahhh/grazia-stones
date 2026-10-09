import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grazia_stones/core/data/catalogue_specs.dart';
import 'package:grazia_stones/core/models/stone.dart';

void main() {
  group('Stone.fromMap fills gaps from the client PDFs', () {
    test('Premium 3D design gets its PDF size, thickness, box data and clean texture', () {
      final s = Stone.fromMap({'name': 'Verona', 'collections': {'name': 'Premium Surface Collection'}});
      expect(s.size, '300 × 80 mm');
      expect(s.thickness, '30 mm');
      expect(s.sqftPerBox, 7.2);
      expect(s.piecesPerBox, 36);
      expect(s.arTexture, 'assets/ar_textures/3d_verona.jpg');
    });

    test('Exclusive Patina design gets its PDF panel size', () {
      final s = Stone.fromMap({'name': 'Midnight Scallop Mosaic', 'collections': {'name': 'Exclusive Collection'}});
      expect(s.size, '600 × 1200 mm');
      expect(s.thickness, '15-20 mm');
    });

    test('Cultured series gets its PDF tile size and sqft per box', () {
      final s = Stone.fromMap({'name': 'Grande Ledge Series', 'collections': {'name': 'Grande Ledge Series'}});
      expect(s.size, '490 × 195 mm');
      expect(s.sqftPerBox, 7.0);
    });

    test('collage thumbnails are replaced by a clean bundled crop', () {
      final s = Stone.fromMap({'name': 'Egyptian Series', 'collections': {'name': 'Egyptian Series'}});
      expect(s.arTexture, 'assets/ar_textures/egyptian.jpg');
    });

    test('values stored in the database always win', () {
      final s = Stone.fromMap({
        'name': 'Verona',
        'collections': {'name': 'Premium Surface Collection'},
        'size': '1 x 1',
        'coverage_sqft': 9.5,
        'ar_texture': 'https://example.com/t.jpg',
      });
      expect(s.size, '1 x 1');
      expect(s.sqftPerBox, 9.5);
      expect(s.arTexture, 'https://example.com/t.jpg');
    });

    test('stones outside the catalogue keep the old defaults', () {
      final s = Stone.fromMap({'name': 'Mystery', 'collections': {'name': 'Unknown Series'}});
      expect(s.size, '');
      expect(s.sqftPerBox, 10.5);
    });
  });

  test('every bundled AR texture named in the specs exists on disk', () {
    final paths = CatalogueSpecs.bundledTextures.toList();
    expect(paths.length, greaterThanOrEqualTo(64)); // 22 surface + 39 exclusive + 3 collage series
    expect(paths.where((p) => !File(p).existsSync()), isEmpty);
  });
}
