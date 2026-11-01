import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grazia_stones/core/services/mock_data_service.dart';
import 'package:grazia_stones/features/aarna_ai/services/aarna_ai_service.dart';
import 'package:grazia_stones/shared/widgets/aarna_living_avatar.dart';

void main() {
  final stones = MockDataService.stones;

  test('no designs from the server means no cards (plain answers stay plain)', () {
    expect(AarnaAIService.resolveDesigns(null, stones), isEmpty);
    expect(AarnaAIService.resolveDesigns(const [], stones), isEmpty);
  });

  test('server designs map to catalogue stones by id, then name, in order; unknown ones dropped', () {
    final a = stones[0], b = stones[1];
    final out = AarnaAIService.resolveDesigns([
      {'id': b.id, 'name': b.name},
      {'id': 'not-in-catalogue', 'name': a.name.toUpperCase()},
      {'id': 'missing', 'name': 'Does Not Exist'},
      {'id': b.id, 'name': b.name},
    ], stones);
    expect(out, [b, a]);
  });

  testWidgets('header avatar renders idle, searching and waving (writes PNG for review)', (tester) async {
    final key = GlobalKey();
    Widget row() => RepaintBoundary(
          key: key,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(24),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AarnaLivingAvatar(size: 76, popOut: true, pose: AarnaPose.idle),
                SizedBox(width: 24),
                AarnaLivingAvatar(size: 76, popOut: true, pose: AarnaPose.searching, isSearching: true),
                SizedBox(width: 24),
                AarnaLivingAvatar(size: 76, popOut: true, pose: AarnaPose.waving),
              ],
            ),
          ),
        );
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: row()))));
      await tester.pump(const Duration(milliseconds: 600));
      for (final e in find.byType(Image).evaluate()) {
        // Avatars are animated WebP renders; the test decoder can stall on them, so don't wait forever.
        await precacheImage((e.widget as Image).image, e).timeout(const Duration(seconds: 5), onTimeout: () {});
      }
    });
    await tester.pump(const Duration(milliseconds: 700));
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await tester.runAsync(() => boundary.toImage(pixelRatio: 2));
    final bytes = await tester.runAsync(() => img!.toByteData(format: ui.ImageByteFormat.png));
    expect(bytes, isNotNull);
    final out = Platform.environment['AARNA_OUT'];
    if (out != null) {
      await tester.runAsync(() => File('$out/aarna_avatar_states.png').writeAsBytes(bytes!.buffer.asUint8List()));
    }
  });
}
