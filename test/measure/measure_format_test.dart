import 'package:flutter_test/flutter_test.dart';
import 'package:grazia_stones/core/utils/measure_format.dart';

void main() {
  test('known lengths in every unit', () {
    expect(formatMeasureLength(1.0, 'm'), '1.00 m');
    expect(formatMeasureLength(1.0, 'cm'), '100.0 cm');
    expect(formatMeasureLength(1.0, 'mm'), '1000 mm');
    expect(formatMeasureLength(0.0254, 'in'), '1.0"');
    expect(formatMeasureLength(0.3048, 'ft'), '1\' 0.0"');
    expect(formatMeasureLength(0.6096, 'ft'), '2\' 0.0"');
    expect(formatMeasureLength(0.0123, 'mm'), '12 mm');
  });

  test('feet and inches carry correctly instead of showing 12 inches', () {
    // 0.3043 m = 11.98 in -> rounds to 12.0 in = 1 ft 0.0 in
    expect(formatMeasureLength(0.3043, 'ft'), '1\' 0.0"');
    expect(formatMeasureLength(1.8288, 'ft'), '6\' 0.0"');
  });

  test('unit list has all five units', () {
    expect(kMeasureUnits, ['mm', 'cm', 'm', 'in', 'ft']);
  });
}
