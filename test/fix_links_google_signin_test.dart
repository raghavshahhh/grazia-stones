import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grazia_stones/features/auth/presentation/login_screen.dart';

void main() {
  test('Google everywhere, Apple only on iPhone', () {
    expect(googleSignInAvailable(), isTrue);
    expect(appleSignInAvailable(platform: TargetPlatform.iOS, web: false, ready: true), isTrue);
    expect(appleSignInAvailable(platform: TargetPlatform.android, web: false, ready: true), isFalse);
    expect(appleSignInAvailable(platform: TargetPlatform.iOS, web: false), isFalse); // not ready yet
    expect(appleSignInAvailable(platform: TargetPlatform.iOS, web: true), isFalse);
  });
}
