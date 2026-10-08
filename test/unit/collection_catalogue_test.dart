import 'package:flutter_test/flutter_test.dart';
import 'package:grazia_stones/core/models/collection.dart';

Collection _c(String name) => Collection(id: name, name: name, description: '');

void main() {
  test('all 36 live collections map to the client catalogue', () {
    const live = [
      'Grande Ledge Series', 'Country Ledge Series', 'Mountain Ledge Series',
      'Opus Ledge Series', 'Classic Ledge Series', 'Vantage Series',
      'Rockface Linear Series', 'Castle Ledge Series', 'Cuarzo Series',
      'Venetian Series', 'Andorra Series', 'Rustic Brick Series',
      'European Stack Series', 'Tarnished Brick Series', 'Florentine Series',
      'Veines Series', 'Foliage Series', 'Travertine Series', 'Hexa Series',
      'Sleepwood Series', 'Milano Series', 'Sierra Series', 'Alpine Series',
      'Fossile Rock Series', 'Rockface Series', 'Tevoli Series',
      'Colonial Brick Series', 'Lakhori Brick Series', 'Flora Series',
      'Vine Series', 'Modena Series', 'Cave Series', 'Egyptian Series',
      'Weave Series', 'Premium Surface Collection', 'Exclusive Collection',
    ];
    for (final n in live) {
      expect(_c(n).catalogueGroup, isNotNull, reason: n);
    }
    // each live collection gets a distinct rank (no accidental key clash)
    expect(live.map((n) => _c(n).catalogueRank).toSet().length, live.length);
  });

  test('titles follow the client handwriting', () {
    expect(_c('Venetian Series').displayName, 'Venecia Ledge Series');
    expect(_c('Travertine Series').displayName, 'Travertino Series');
    expect(_c('Sleepwood Series').displayName, 'Sleeper Wood Series');
    expect(_c('Tevoli Series').displayName, 'Tivoli Series');
    expect(_c('Exclusive Collection').displayName, 'Exclusive Patina Series');
    expect(_c('Premium Surface Collection').catalogueGroup, CatalogueGroups.premium3d);
    expect(_c('Vantage Series').catalogueGroup, CatalogueGroups.ledge);
    expect(_c('Flora Series').catalogueGroup, CatalogueGroups.premiumCnc);
  });

  test('unknown collections keep their name and sort last', () {
    final c = _c('Brand New Series');
    expect(c.displayName, 'Brand New Series');
    expect(c.catalogueGroup, isNull);
  });
}
