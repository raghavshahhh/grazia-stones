import 'package:flutter_test/flutter_test.dart';
import 'package:grazia_stones/config/router.dart';

void main() {
  String? r(String loc, {bool loggedIn = false, bool admin = false}) =>
      authRedirect(Uri.parse(loc), isLoggedIn: loggedIn, isAdmin: admin);

  test('admin gate keeps the target', () {
    expect(r('/admin/orders'), '/login?redirect=%2Fadmin%2Forders');
    expect(r('/admin/orders', loggedIn: true), startsWith('/login?redirect='));
    expect(r('/admin/orders', loggedIn: true, admin: true), isNull);
  });

  test('restored admin session is forwarded from login to the target', () {
    expect(r('/login?redirect=%2Fadmin%2Forders'), isNull); // still restoring
    expect(r('/login?redirect=%2Fadmin%2Forders', loggedIn: true, admin: true), '/admin/orders');
    expect(r('/login?redirect=%2Fcart', loggedIn: true), '/cart');
  });

  test('no loop for non-admin, no off-app redirects', () {
    expect(r('/login?redirect=%2Fadmin', loggedIn: true), isNull);
    expect(r('/login?redirect=https%3A%2F%2Fevil.com', loggedIn: true, admin: true), '/home');
    expect(r('/login?redirect=%2F%2Fevil.com', loggedIn: true, admin: true), '/home');
    expect(r('/login', loggedIn: true), '/home');
    expect(r('/register', loggedIn: true), '/home');
    expect(r('/home', loggedIn: true), isNull);
  });

  test('signed-out users only reach the auth and legal pages', () {
    expect(r('/home'), '/login?redirect=%2Fhome');
    expect(r('/ai-viz'), '/login?redirect=%2Fai-viz');
    expect(r('/ar-view?stoneId=x'), '/login?redirect=%2Far-view%3FstoneId%3Dx');
    for (final open in ['/', '/onboarding', '/login', '/register', '/forgot-password', '/reset-password', '/privacy', '/terms']) {
      expect(r(open), isNull, reason: open);
    }
  });
}
