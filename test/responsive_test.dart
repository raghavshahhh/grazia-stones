import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grazia_stones/core/utils/responsive.dart';

Future<(int, double)> probe(WidgetTester t, Size size) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  late int cols;
  late double w;
  await t.pumpWidget(MaterialApp(
    builder: (c, child) => ResponsiveFrame(child: child!),
    home: Builder(builder: (c) {
      cols = gridColumns(c);
      w = MediaQuery.sizeOf(c).width;
      return const SizedBox();
    }),
  ));
  return (cols, w);
}

void main() {
  testWidgets('columns and width cap per form factor', (t) async {
    expect((await probe(t, const Size(360, 800))).$1, 2);   // phone
    expect((await probe(t, const Size(673, 841))).$1, 3);   // Z Fold inner
    expect((await probe(t, const Size(1280, 800))).$1, 5);  // tablet landscape
    expect((await probe(t, const Size(2000, 1200))).$2, kMaxContentWidth); // big window capped
  });
}
