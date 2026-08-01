import 'package:flutter/material.dart';
import '../models/quote_request.dart';

class QuoteProvider extends ChangeNotifier {
  final List<QuoteRequest> _quotes = [
    QuoteRequest(
      id: 'q1',
      stoneName: 'Charcoal Black',
      finish: 'Polished',
      area: '450 sq ft',
      status: 'Pending',
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
    ),
    QuoteRequest(
      id: 'q2',
      stoneName: 'Walnut Brown',
      finish: 'Leathered',
      area: '1200 sq ft',
      status: 'Completed',
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    ),
  ];

  List<QuoteRequest> get quotes => List.unmodifiable(_quotes);

  void addQuote(QuoteRequest quote) {
    _quotes.insert(0, quote);
    notifyListeners();
  }
}
