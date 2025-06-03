import 'package:cloud_firestore/cloud_firestore.dart';
import '../Resuable_widget/Products.dart';
import 'package:mobistore/Screen/inventory.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _productsCollection = 'products';

  // Local cache
  final Map<String, Product> _cache = {};

  // Stream controller for real-time updates
  Stream<QuerySnapshot>? _productStream;

  // Initialize Firestore settings for better performance
  void initializeFirestore() {
    _firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  // Get products with pagination and real-time updates
  Stream<List<Product>> getProductsStream({int limit = 20}) {
    _productStream ??= _firestore
        .collection(_productsCollection)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots();

    return _productStream!.map((snapshot) {
      return snapshot.docs.map((doc) {
        final product = Product.fromFirestore(doc);
        _cache[doc.id] = product; // Update cache
        return product;
      }).toList();
    });
  }

  // Get products with pagination for initial load
  Future<List<Product>> getProducts({
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      Query query = _firestore
          .collection(_productsCollection)
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final QuerySnapshot snapshot = await query.get(
        const GetOptions(source: Source.serverAndCache),
      );

      return snapshot.docs.map((doc) {
        final product = Product.fromFirestore(doc);
        _cache[doc.id] = product; // Update cache
        return product;
      }).toList();
    } catch (e) {
      print('Error getting products: $e');
      // Return cached data if available when offline
      if (_cache.isNotEmpty) {
        return _cache.values.toList();
      }
      throw e;
    }
  }

  // Add a new product with optimized write
  Future<String> addProduct(Product product) async {
    try {
      final productData = {
        ...product.toMap(),
        'timestamp': FieldValue.serverTimestamp(),
      };

      // Optimize write with server timestamp
      final DocumentReference docRef = _firestore
          .collection(_productsCollection)
          .doc();

      await docRef.set(
        productData,
        SetOptions(merge: true),
      );

      _cache[docRef.id] = product; // Update cache
      return docRef.id;
    } catch (e) {
      print('Error adding product: $e');
      throw e;
    }
  }

  // Get a single product with cache
  Future<Product?> getProduct(String productId) async {
    // Return from cache if available
    if (_cache.containsKey(productId)) {
      return _cache[productId];
    }

    try {
      final DocumentSnapshot doc = await _firestore
          .collection(_productsCollection)
          .doc(productId)
          .get(const GetOptions(source: Source.serverAndCache));

      if (doc.exists) {
        final product = Product.fromFirestore(doc);
        _cache[productId] = product; // Update cache
        return product;
      }
      return null;
    } catch (e) {
      print('Error getting product: $e');
      throw e;
    }
  }

  // Batch update products
  Future<void> batchUpdateProducts(List<Product> products) async {
    try {
      final WriteBatch batch = _firestore.batch();

      for (var product in products) {
        final docRef = _firestore
            .collection(_productsCollection)
            .doc(product.id);

        batch.update(docRef, {
          ...product.toMap(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        //cache[product.id] = product; // Update cache
      }

      await batch.commit();
    } catch (e) {
      print('Error batch updating products: $e');
      throw e;
    }
  }

  // Update single product
  Future<void> updateProduct(String productId, Product product) async {
    try {
      await _firestore
          .collection(_productsCollection)
          .doc(productId)
          .update({
        ...product.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _cache[productId] = product; // Update cache
    } catch (e) {
      print('Error updating product: $e');
      throw e;
    }
  }

  // Delete product
  Future<void> deleteProduct(String productId) async {
    try {
      await _firestore
          .collection(_productsCollection)
          .doc(productId)
          .delete();

      _cache.remove(productId); // Remove from cache
    } catch (e) {
      print('Error deleting product: $e');
      throw e;
    }
  }

  // Clear cache
  void clearCache() {
    _cache.clear();
    _productStream = null;
  }
}