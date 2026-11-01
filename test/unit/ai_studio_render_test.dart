import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/features/ai_viz/services/ai_studio_render.dart';

Stone _stone(String id, {String collection = '', String category = '', List<String> images = const [], List<String> colours = const []}) =>
    Stone(
      id: id,
      name: 'Stone $id',
      productCode: id,
      collection: collection,
      category: category,
      pricePerSqFt: 0,
      description: '',
      images: images,
      availableColors: colours,
    );

void main() {
  group('RenderEta', () {
    test('estimate is the average of the last renders, default without history', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await RenderEta.estimateMs(), RenderEta.defaultMs);
      for (final ms in [10000, 12000, 14000, 16000, 18000, 20000]) {
        await RenderEta.record(ms);
      }
      // Only the last 5 are kept: 12..20 s.
      expect(await RenderEta.estimateMs(), 16000);
      expect(RenderEta.averageMs(['1000']), 8000, reason: 'clamped to a sane floor');
    });

    test('progress rises to 90% at the estimate and never reaches 100% while waiting', () {
      expect(RenderEta.progress(0, 16000), 0);
      expect(RenderEta.progress(8000, 16000), closeTo(0.45, 1e-9));
      expect(RenderEta.progress(16000, 16000), closeTo(0.9, 1e-9));
      expect(RenderEta.progress(60000, 16000), lessThan(0.97));
      expect(RenderEta.progress(20000, 16000), greaterThan(RenderEta.progress(18000, 16000)));
    });

    test('countdown stops before 0 so the UI can say "Almost there"', () {
      expect(RenderEta.secondsLeft(0, 16000), 16);
      expect(RenderEta.secondsLeft(14100, 16000), 2);
      expect(RenderEta.secondsLeft(15100, 16000), isNull);
      expect(RenderEta.secondsLeft(30000, 16000), isNull);
    });
  });

  test('render JPEG is downscaled to the max side and labelled as JPEG', () {
    final png = Uint8List.fromList(img.encodePng(img.Image(width: 2000, height: 1000)));
    final url = renderJpegDataUrl((png, roomMaxSide));
    expect(url, startsWith('data:image/jpeg;base64,'));
    final out = img.decodeJpg(base64Decode(url.split(',').last))!;
    expect(out.width, roomMaxSide);
    expect(out.height, 640);

    // Undecodable bytes pass through instead of failing the render.
    expect(renderJpegDataUrl((Uint8List.fromList([1, 2, 3]), 1024)), 'data:image/jpeg;base64,AQID');
  });

  test('colours come from the catalogue images, named when the DB has names', () {
    expect(stoneColours(_stone('a', images: ['x'])), isEmpty);
    final named = stoneColours(_stone('a', images: ['u1', 'u2'], colours: ['Grey', 'Rust']));
    expect(named.map((c) => c.label), ['Grey', 'Rust']);
    expect(named.map((c) => c.imageUrl), ['u1', 'u2']);
    expect(stoneColours(_stone('a', images: ['u1', 'u2'])).map((c) => c.label), ['Shade 1', 'Shade 2']);
  });

  test('related stones: same collection first, then category, no duplicates or self', () {
    final me = _stone('me', collection: 'Ledge', category: 'Wall');
    final all = [
      me,
      _stone('c1', collection: 'Other', category: 'Wall'),
      _stone('l1', collection: 'Ledge', category: 'Wall'),
      _stone('x', collection: 'Other', category: 'Floor'),
      _stone('l2', collection: 'Ledge', category: 'Floor'),
    ];
    expect(relatedStones(me, all).map((s) => s.id), ['l1', 'l2', 'c1']);
    expect(relatedStones(me, all, limit: 2).map((s) => s.id), ['l1', 'l2']);
    expect(relatedStones(_stone('lone'), all), isEmpty);
  });
}
