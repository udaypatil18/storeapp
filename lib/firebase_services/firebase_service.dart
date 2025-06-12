import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Resuable_widget/Products.dart';
import 'package:mobistore/Screen/inventory.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';


class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();

  factory FirestoreService() => _instance;

  // 1. Implement batch loading with appropriate chunk size
  static const int BATCH_SIZE = 10;
  // 2. Optimize cache duration based on data update frequency
  static const Duration cacheDuration = Duration(minutes: 15);

  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _productsCollection = 'products';

  /// Enhanced cache with timestamp
  final Map<String, Product> _cache = {};
  DateTime? _lastCacheUpdate;
  // static const cacheDuration = Duration(minutes: 5);

  // Stream controller for real-time updates
  Stream<QuerySnapshot>? _productStream;

  void _initializeFirestore() {
    _firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      sslEnabled: true,
    );

    _firestore.enablePersistence(const PersistenceSettings(
      synchronizeTabs: true,
    ));
  }

  // Get products with pagination and real-time updates
  // Optimized product fetching with pagination and caching
  Stream<List<Product>> getProductsStream({int limit = 20}) {
    return _firestore
        .collection(_productsCollection)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs
            .map((doc) => Product.fromFirestore(doc))
            .toList());
  }


  // Get products with pagination for initial load
  Future<List<Product>> getProducts({
    int limit = 20,
    DocumentSnapshot? lastDocument,
    bool forceRefresh = false,
  }) async {
    try {
      // Skip cache if forcing refresh
      if (!forceRefresh && _isCacheValid()) {
        return _cache.values.toList()
          ..sort((a, b) => b.lastRestocked.compareTo(a.lastRestocked));
      }

      // Your existing query code
      Query query = _firestore
          .collection(_productsCollection)
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get(
        GetOptions(source: forceRefresh ? Source.server : Source.serverAndCache),
      );

      final products = <Product>[];
      for (final doc in snapshot.docs) {
        final product = Product.fromFirestore(doc);
        _cache[doc.id] = product;
        products.add(product);
      }

      _lastCacheUpdate = DateTime.now();
      return products;
    } catch (e) {
      print('Error fetching products: $e');
      if (!forceRefresh && _cache.isNotEmpty) {
        return _cache.values.toList()
          ..sort((a, b) => b.lastRestocked.compareTo(a.lastRestocked));
      }
      rethrow;
    }
  }


  bool _isCacheValid() {
    if (_cache.isEmpty || _lastCacheUpdate == null) return false;
    return DateTime.now().difference(_lastCacheUpdate!) < cacheDuration;
  }

  Future<void> clearCache({bool forceRefresh = false}) async {
    _cache.clear();
    _lastCacheUpdate = null;

    if (forceRefresh) {
      await getProducts();
    }
  }


  // Add a new product with optimized write
  // In your FirestoreService class
  Future<String> addProduct(Product product) async {
    try {
      final productData = {
        ...product.toFirestore(),
        'timestamp': FieldValue.serverTimestamp(),
      };

      final DocumentReference docRef = await _firestore
          .collection(_productsCollection)
          .add(productData);

      // Clear cache immediately after adding
      _cache.clear();
      _lastCacheUpdate = null;

      return docRef.id;
    } catch (e) {
      print('Error adding product: $e');
      throw e;
    }
  }


  Future<Product?> getProduct(String productId) async {
    try {
      final DocumentSnapshot doc = await _firestore
          .collection(_productsCollection)
          .doc(productId)
          .get(const GetOptions(
        source: Source.cache, // Try cache first
        serverTimestampBehavior: ServerTimestampBehavior.estimate,
      ));

      if (doc.exists) {
        return Product.fromFirestore(doc);
      }

      // If not in cache, fetch from server
      return await _firestore
          .collection(_productsCollection)
          .doc(productId)
          .get(const GetOptions(source: Source.server))
          .then((doc) => doc.exists ? Product.fromFirestore(doc) : null);
    } catch (e) {
      print('Error getting product: $e');
      rethrow;
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
  Future<void> updateProduct(String productId, dynamic data) async {
    try {
      if (data is Product) {
        await _firestore.collection(_productsCollection)  // Use _productsCollection
            .doc(productId)
            .update(data.toFirestore());
      } else if (data is Map<String, dynamic>) {
        await _firestore.collection(_productsCollection)  // Use _productsCollection
            .doc(productId)
            .update(data);
      }
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
}