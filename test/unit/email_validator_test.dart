import 'package:flutter_test/flutter_test.dart';
import 'package:grazia_stones/core/utils/validators.dart';

void main() {
  test('accepts normal and plus-aliased emails', () {
    for (final e in ['a@b.com', 'first.last@mail.co.in', 'name+tag@gmail.com', 'n_1-x@sub.domain.org']) {
      expect(Validators.validateEmail(e), isNull, reason: e);
      expect(Validators.email(e), isNull, reason: e);
    }
  });

  test('rejects malformed emails', () {
    for (final e in ['', 'plain', 'a@b', '@x.com', 'a b@c.com', 'a@@b.com']) {
      expect(Validators.validateEmail(e), isNotNull, reason: e);
    }
  });
}
