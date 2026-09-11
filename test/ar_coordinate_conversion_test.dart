import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grazia_stones/core/services/ar_native_channel.dart';

/// Regression test for the Android AR logical-pixel/native-pixel mismatch.
///
/// `scaleLogicalPointForNativeAR` is the pure conversion function extracted
/// from `ARNativeChannel`'s screen-point plugin calls (hitTestWallAtScreenPoint,
/// measureDistance). It must:
///  - leave iOS/web points untouched (they're already in the right space)
///  - scale Android points by devicePixelRatio so SceneView's native
///    hit-test receives physical pixels instead of Flutter logical pixels
void main() {
  group('scaleLogicalPointForNativeAR', () {
    test('iOS: logical point is returned unchanged regardless of density', () {
      const point = Offset(187.5, 406.0);
      final result = scaleLogicalPointForNativeAR(
        point,
        devicePixelRatio: 3.0,
        isAndroidNative: false,
      );
      expect(result, point);
    });

    test('Web: logical point is returned unchanged', () {
      const point = Offset(200, 400);
      final result = scaleLogicalPointForNativeAR(
        point,
        devicePixelRatio: 2.0,
        isAndroidNative: false,
      );
      expect(result, point);
    });

    test('Android: scales by devicePixelRatio (density 3.0)', () {
      const point = Offset(200, 400);
      final result = scaleLogicalPointForNativeAR(
        point,
        devicePixelRatio: 3.0,
        isAndroidNative: true,
      );
      expect(result, const Offset(600, 1200));
    });

    test('Android: scales by devicePixelRatio (density 2.625, a real Pixel value)', () {
      const point = Offset(360, 780);
      final result = scaleLogicalPointForNativeAR(
        point,
        devicePixelRatio: 2.625,
        isAndroidNative: true,
      );
      expect(result.dx, closeTo(945.0, 0.001));
      expect(result.dy, closeTo(2047.5, 0.001));
    });

    test('Android: density 1.0 is a no-op scale', () {
      const point = Offset(150, 300);
      final result = scaleLogicalPointForNativeAR(
        point,
        devicePixelRatio: 1.0,
        isAndroidNative: true,
      );
      expect(result, point);
    });

    test('screen-center reticle at a typical device size lands at true center after scaling', () {
      // 393x852 logical points (iPhone-sized) rendered on a hypothetical
      // Android device reporting the same logical size at density 3.0 —
      // the native hit-test must receive the physical-pixel center.
      const logicalSize = Size(393, 852);
      final center = Offset(logicalSize.width / 2, logicalSize.height / 2);
      final nativePoint = scaleLogicalPointForNativeAR(
        center,
        devicePixelRatio: 3.0,
        isAndroidNative: true,
      );
      final physicalSize = logicalSize * 3.0;
      expect(nativePoint.dx, physicalSize.width / 2);
      expect(nativePoint.dy, physicalSize.height / 2);
    });
  });
}
