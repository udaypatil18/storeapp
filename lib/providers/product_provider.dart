import 'package:flutter/material.dart';
import '../Resuable_widget/Products.dart';
import '../firebase_services/firebase_service.dart';
import '../firebase_services/image_storage.dart';

class ProductProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  List<Product> _products = [];
  bool _isLoading = false;
  String? _error;

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Call this on app start or when needed
  Future<void> loadProducts({bool forceRefresh = false}) async {
    if (_products.isNotEmpty && !forceRefresh) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _products = await _firestoreService.getProducts();
    } catch (e) {
      _error = 'Error loading products: $e';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addProduct(Product product) async {
    try {
      final productId = await _firestoreService.addProduct(product);
      product.id = productId;
      _products.add(product);
      notifyListeners();
    } catch (e) {
      _error = 'Error adding product: $e';
      notifyListeners();
    }
  }

  Future<void> updateProduct(Product product) async {
    if (product.id == null) {
      _error = 'Error: Product ID is missing';
      notifyListeners();
      return;
    }
    try {
      await _firestoreService.updateProduct(product.id!, product);
      final idx = _products.indexWhere((p) => p.id == product.id);
      if (idx != -1) _products[idx] = product;
      notifyListeners();
    } catch (e) {
      _error = 'Error updating product: $e';
      notifyListeners();
    }
  }
  Future<void> deleteProduct(Product product) async {
    if (product.id == null) {
      _error = 'Error: Product ID is missing';
      notifyListeners();
      return;
    }
    try {
      // ✅ Clean up image from Firebase Storage
      if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
        await ImageStorage.deleteFromFirebase(product.imageUrl!);
      }

      await _firestoreService.deleteProduct(product.id!);
      _products.removeWhere((p) => p.id == product.id);
      notifyListeners();
    } catch (e) {
      _error = 'Error deleting product: $e';
      notifyListeners();
    }
  }


  // Optional: expose a method to clear (if needed)
  void clear() {
    _products = [];
    notifyListeners();
  }
}