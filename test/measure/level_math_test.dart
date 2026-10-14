import 'package:flutter_test/flutter_test.dart';
import 'package:grazia_stones/core/utils/level_math.dart';

void main() {
  const g = 9.80665;

  test('lying flat is level', () {
    final r = readLevel(0, 0, g);
    expect(r.flat, isTrue);
    expect(r.degrees, closeTo(0, 1e-6));
    expect(r.isLevel, isTrue);
  });

  test('flat and tilted 10 degrees reports about 10', () {
    final t = 10 * 3.141592653589793 / 180;
    final r = readLevel(g * 0.0, g * 0.17364817766693033 * 1, g * 0.984807753012208);
    expect(r.flat, isTrue);
    expect(r.degrees, closeTo(10, 0.01));
    expect(r.isLevel, isFalse);
    expect(t, greaterThan(0));
  });

  test('bubble moves toward the high side (right edge down -> bubble goes left)', () {
    final r = readLevel(-1.0, 0, g); // right edge lower => x reading negative
    expect(r.bubbleX, lessThan(0));
    final up = readLevel(0, -1.0, g); // top edge lower => y negative => bubble goes down (+y)
    expect(up.bubbleY, greaterThan(0));
  });

  test('upright portrait: straight is level, rotated 5 degrees reports 5', () {
    expect(readLevel(0, g, 0).degrees, closeTo(0, 1e-6));
    expect(readLevel(0, g, 0).flat, isFalse);
    final r = readLevel(g * 0.08715574274765817, g * 0.9961946980917455, 0);
    expect(r.degrees.abs(), closeTo(5, 0.01));
  });

  test('upright but upside down and landscape normalise to a small angle', () {
    expect(readLevel(0, -g, 0).degrees.abs(), closeTo(0, 1e-6));
    expect(readLevel(g, 0, 0).degrees.abs(), closeTo(0, 1e-6));
    expect(readLevel(-g, 0, 0).degrees.abs(), closeTo(0, 1e-6));
  });
}
