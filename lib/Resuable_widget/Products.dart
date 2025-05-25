// File: lib/Resuable_widget/Products.dart
class Product {
  int id;
  String name;
  int stock;
  String status;
  double price;

  Product({
    required this.id,
    required this.name,
    required this.stock,
    required this.status,
    this.price = 0.0,
  });

  // Optional: Add a method to update stock and status
  void updateStock(int newStock) {
    stock = newStock;
    status = newStock == 0
        ? 'Out of Stock'
        : (newStock < 10 ? 'Low Stock' : 'In Stock');
  }
}
