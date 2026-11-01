import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grazia_stones/features/ai_viz/services/branded_render.dart';

Future<(ui.Image, ByteData)> _pixels(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final image = (await codec.getNextFrame()).image;
  return (image, (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('share caption points at the owner site', () {
    expect(aiStudioShareCaption, contains('https://waitlist.graziastones.com'));
    expect(aiStudioShareCaption, isNot(contains('graziastones.com/')));
  });

  testWidgets('watermark keeps full resolution and marks only the bottom-right corner', (tester) async {
    await tester.runAsync(() async {
      final input = File('assets/images/home_hero_living_room.jpg').readAsBytesSync();
      final output = await watermarkRender(input);

      final (before, beforePx) = await _pixels(input);
      final (after, afterPx) = await _pixels(output);
      expect(after.width, before.width);
      expect(after.height, before.height);

      // Count changed pixels in the logo box (bottom-right, 14% wide, 3.5% inset) and in a
      // same-sized box at the top-left, which must be untouched.
      int changedIn(int x0, int y0, int w, int h) {
        var changed = 0;
        for (var y = y0; y < y0 + h; y++) {
          for (var x = x0; x < x0 + w; x++) {
            final i = (y * before.width + x) * 4;
            final d = (beforePx.getUint8(i) - afterPx.getUint8(i)).abs() +
                (beforePx.getUint8(i + 1) - afterPx.getUint8(i + 1)).abs() +
                (beforePx.getUint8(i + 2) - afterPx.getUint8(i + 2)).abs();
            if (d > 24) changed++;
          }
        }
        return changed;
      }

      final boxW = (before.width * 0.14).round();
      final boxH = (boxW * 797 / 1100).round(); // grazia-logo-white.png aspect
      final inset = (before.width * 0.035).round();
      final logoBox = changedIn(before.width - inset - boxW, before.height - inset - boxH, boxW, boxH);
      final corner = changedIn(0, 0, boxW, boxH);

      expect(logoBox, greaterThan(boxW * boxH * 0.05), reason: 'logo should change a visible share of its box');
      expect(corner, 0, reason: 'nothing outside the logo area should change');
    });
  });
}
