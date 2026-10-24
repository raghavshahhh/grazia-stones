import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grazia_stones/core/services/mock_data_service.dart';
import 'package:grazia_stones/features/aarna_ai/services/aarna_ai_service.dart';
import 'package:grazia_stones/shared/widgets/aarna_living_avatar.dart';

void main() {
  final svc = AarnaAIService.instance;
  final cols = MockDataService.collections;

  test('small talk gets no product cards', () {
    for (final q in ['hey', 'Hello', 'hi aarna', 'how are you', 'kaise ho', 'thanks', 'ok', 'namaste', 'who are you']) {
      expect(svc.wantsProducts(q, cols), isFalse, reason: q);
    }
  });

  test('product questions in English, Hindi and Hinglish do get cards', () {
    for (final q in [
      'living room wall ke liye stone batao',
      'show me exterior options',
      'mujhe fluted panel chahiye',
      'price of brick series',
      'bedroom design suggest karo',
      'Exclusive Patina Series',
    ]) {
      expect(svc.wantsProducts(q, cols), isTrue, reason: q);
    }
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
