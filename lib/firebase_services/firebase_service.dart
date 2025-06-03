import 'package:cloud_firestore/cloud_firestore.dart';
import '../Resuable_widget/Products.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _productsCollection = 'products'; // Collection name

  // Get all products
  Future<List<Product>> getProducts() async {
    try {
      QuerySnapshot querySnapshot = await _firestore.collection(_productsCollection).get();
      return querySnapshot.docs.map((doc) {
        return Product.fromFirestore(doc);
      }).toList();
    } catch (e) {
      print('Error getting products: $e');
      throw e;
    }
  }

  // Add a new product
  Future<String> addProduct(Product product) async {
    try {
      DocumentReference docRef = await _firestore.collection(_productsCollection).add(product.toMap());
      return docRef.id;
    } catch (e) {
      print('Error adding product: $e');
      throw e;
    }
  }

  // Update an existing product
  Future<void> updateProduct(String productId, Product product) async {
    try {
      await _firestore.collection(_productsCollection).doc(productId).update(product.toMap());
    } catch (e) {
      print('Error updating product: $e');
      throw e;
    }
  }

  // Delete a product
  Future<void> deleteProduct(String productId) async {
    try {
      await _firestore.collection(_productsCollection).doc(productId).delete();
    } catch (e) {
      print('Error deleting product: $e');
      throw e;
    }
  }

  // Get a single product
  Future<Product?> getProduct(String productId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection(_productsCollection).doc(productId).get();
      if (doc.exists) {
        return Product.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting product: $e');
      throw e;
    }
  }
}