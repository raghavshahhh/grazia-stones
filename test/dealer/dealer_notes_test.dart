import 'package:flutter_test/flutter_test.dart';
import 'package:grazia_stones/features/dealer/presentation/dealer_leads_screen.dart';

void main() {
  test('dealer note is read from object, list or missing embed', () {
    expect(dealerNotesOf({'quote_dealer_notes': {'notes': 'site visit'}}), 'site visit');
    expect(dealerNotesOf({'quote_dealer_notes': [{'notes': 'called'}]}), 'called');
    expect(dealerNotesOf({'quote_dealer_notes': []}), '');
    expect(dealerNotesOf({'quote_dealer_notes': null}), '');
    expect(dealerNotesOf({}), '');
  });
}
