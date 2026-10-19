import 'package:flutter_test/flutter_test.dart';
import 'package:grazia_stones/features/aarna_ai/services/aarna_ai_service.dart';

void main() {
  test('a finished sentence is returned untouched, even when it ends in a cutoff word', () {
    const replies = [
      'Tell me which room you are working with.',
      'Happy to help with anything you would like.',
      'Shall we start with the living room or the facade?',
      'Great choice!',
    ];
    for (final r in replies) {
      expect(AarnaAIService.sanitizeResponse(r, const [], const []), r, reason: r);
    }
  });

  test('a reply cut off mid-sentence is closed, not left dangling', () {
    final out = AarnaAIService.sanitizeResponse('Our ledge stones pair well with', const [], const []);
    expect(out.endsWith('.') || out.endsWith('!'), isTrue);
    expect(out.contains(' with.'), isFalse);
  });

  test('a reply with no terminal punctuation gets a full stop', () {
    expect(AarnaAIService.sanitizeResponse('Verona suits a feature wall', const [], const []),
        'Verona suits a feature wall.');
  });
}
