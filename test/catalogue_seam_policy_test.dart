import 'package:flutter_test/flutter_test.dart';
import 'package:grazia_stones/core/models/collection.dart';

void main() {
  test('seam cut only for natural cultured-stone series, never for designed patterns', () {
    expect(catalogueAllowsSeamCut('Grande Ledge Series'), isTrue);
    expect(catalogueAllowsSeamCut('Tarnished Brick Series'), isTrue);
    expect(catalogueAllowsSeamCut('Exclusive Collection'), isFalse);       // chevrons, stripes, medallions
    expect(catalogueAllowsSeamCut('Premium Surface Collection'), isFalse); // regular 3D panels
    expect(catalogueAllowsSeamCut('Flora Series'), isFalse);               // CNC carving
    expect(catalogueAllowsSeamCut('Hexa Series'), isFalse);
    expect(catalogueAllowsSeamCut('Travertine Series'), isFalse);          // regular slab grid
    expect(catalogueAllowsSeamCut('Andorra Series'), isTrue);              // ledge
    expect(catalogueAllowsSeamCut('Unknown Series'), isFalse);
  });
}
