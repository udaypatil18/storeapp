import 'package:flutter/foundation.dart';
import '../Resuable_widget/Products.dart';
import '../Screen/cart.dart';
 // For CartItem

class CartManager extends ChangeNotifier {
  static final CartManager _instance = CartManager._internal();
  static CartManager get instance => _instance;

  CartManager._internal();

  List<CartItem> items = [];

  void addItem(Product product, ProductVariation variation) {
    final existingIndex = items.indexWhere(
          (item) => item.product.id == product.id && item.variation.size == variation.size,
    );
    if (existingIndex != -1) {
      items[existingIndex].quantity++;
    } else {
      items.add(CartItem(product: product, variation: variation));
    }
    notifyListeners();
  }

  void removeItem(CartItem item) {
    items.remove(item);
    notifyListeners();
  }

  void clearCart() {
    items.clear();
    notifyListeners();
  }
}