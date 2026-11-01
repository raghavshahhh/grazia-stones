import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grazia_stones/core/data/catalogue_specs.dart';
import 'package:grazia_stones/core/models/collection.dart';

// Design setup per product (build/audit/06_design_setup.md).
const _series = [
  'Alpine', 'Andorra', 'Castle Ledge', 'Cave', 'Classic Ledge', 'Colonial Brick', 'Country Ledge', 'Cuarzo',
  'Egyptian', 'European Stack', 'Flora', 'Florentine', 'Foliage', 'Fossile Rock', 'Grande Ledge', 'Hexa',
  'Lakhori Brick', 'Milano', 'Modena', 'Mountain Ledge', 'Opus Ledge', 'Rockface Linear', 'Rustic Brick', 'Sierra',
  'Sleepwood', 'Tarnished Brick', 'Tevoli', 'Travertine', 'Vantage', 'Veines', 'Venetian', 'Vine', 'Weave',
];

void main() {
  final series = {for (final s in _series) '$s Series': CatalogueSpecs.forStone('$s Series', '$s Series')};

  test('every live cultured series has a render setup', () {
    expect(series.entries.where((e) => e.value == null).map((e) => e.key), isEmpty);
    for (final s in series.values) {
      expect(['pattern', 'module', 'artwork'], contains(s!.renderType));
      expect(s.patchHeightM, isNotNull);
      expect(s.trimFraction, inInclusiveRange(0, 0.2));
    }
  });

  test('seam cut is only allowed where the design is an irregular pattern', () {
    for (final e in series.entries) {
      if (catalogueAllowsSeamCut(e.key)) expect(e.value!.renderType, 'pattern', reason: e.key);
    }
    expect(catalogueAllowsSeamCut('Premium Surface Collection'), isFalse);
    expect(catalogueAllowsSeamCut('Exclusive Collection'), isFalse);
  });

  test('period-exact crops are untrimmed modules and exist on disk', () {
    final tiles = CatalogueSpecs.bundledTextures.where((p) => p.endsWith('_tile.jpg')).toList();
    expect(tiles.length, 16);
    for (final p in tiles) {
      expect(File(p).existsSync(), isTrue, reason: p);
    }
    final athena = CatalogueSpecs.forStone('Premium Surface Collection', 'Athena')!;
    expect(athena.arTexture, 'assets/ar_textures/3d_athena_tile.jpg');
    expect(athena.trimFraction, 0);
    expect(athena.renderType, 'module');
    expect(athena.patchHeightM, 1.2); // 3 repeats of 400 mm (two 200 x 100 mm pieces per block)
    expect(athena.patchMeasured, isTrue);
  });

  test('untrimmed textures are all measured or flagged, never the old flat 1.0 default', () {
    final kite = CatalogueSpecs.forStone('Premium Surface Collection', 'Kite')!;
    expect(kite.patchHeightM, closeTo(4 * 0.3048, 0.001));
    final vegas = CatalogueSpecs.forStone('Premium Surface Collection', 'Vegas')!;
    expect(vegas.patchMeasured, isFalse);
    expect(vegas.trimFraction, 0.08);
  });

  test('Exclusive crops are skewed slices: estimates, 600x1200 panels are artwork', () {
    final m = CatalogueSpecs.forStone('Exclusive Collection', 'Midnight Scallop Mosaic')!;
    expect(m.renderType, 'artwork');
    expect(m.patchMeasured, isFalse);
    final g = CatalogueSpecs.forStone('Exclusive Collection', 'Golden Hexa Pattern')!;
    expect(g.renderType, 'module');
    expect(g.patchMeasured, isFalse);
  });

  test('Grande keeps the scale measured on its own photo', () {
    final g = series['Grande Ledge Series']!;
    expect(g.patchHeightM, 0.82);
    expect(g.patchMeasured, isTrue);
    expect(g.arTexture, isNull); // renders its own 1.jpg, the image it was measured on
  });
}
