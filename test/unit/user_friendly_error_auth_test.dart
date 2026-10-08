import 'package:flutter_test/flutter_test.dart';
import 'package:grazia_stones/core/utils/user_friendly_error.dart';

void main() {
  test('email confirmation pending is not mislabelled as an AI error', () {
    for (final raw in [
      'email_confirmation_required',
      'AuthApiException(message: Email not confirmed, code: email_not_confirmed)',
    ]) {
      final e = UserFriendlyError.from(raw);
      expect(e.title, 'Confirm Your Email');
      expect(e.message, isNot(contains('visualization')));
    }
  });

  test('real AI errors still map to the studio notice', () {
    expect(UserFriendlyError.from('AI inference failed').title, 'Studio Notice');
  });
}
