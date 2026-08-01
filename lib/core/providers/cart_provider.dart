import 'package:flutter/material.dart';
import '../models/cart_item.dart';
import '../models/stone.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);
  int get itemCount => _items.length;
  double get total => _items.fold(0, (sum, item) => sum + item.totalPrice);

  void addItem(Stone stone, {String finish = 'Polished', int quantity = 1, String colorHex = '#1C1C1E'}) {
    final existingIndex = _items.indexWhere((i) => i.stoneId == stone.id);
    if (existingIndex >= 0) {
      _items[existingIndex] = _items[existingIndex].copyWith(
        quantity: _items[existingIndex].quantity + quantity,
      );
    } else {
      _items.add(CartItem(
        stoneId: stone.id,
        name: stone.name,
        finish: finish,
        pricePerSqFt: stone.pricePerSqFt,
        quantity: quantity,
        colorHex: colorHex,
      ));
    }
    notifyListeners();
  }

  void removeItem(String stoneId) {
    _items.removeWhere((i) => i.stoneId == stoneId);
    notifyListeners();
  }

  void updateQuantity(String stoneId, int quantity) {
    final index = _items.indexWhere((i) => i.stoneId == stoneId);
    if (index >= 0) {
      if (quantity <= 0) {
        _items.removeAt(index);
      } else {
        _items[index] = _items[index].copyWith(quantity: quantity);
      }
      notifyListeners();
    }
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
