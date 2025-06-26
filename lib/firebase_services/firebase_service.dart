// ✅ OPTIMIZED VERSION OF FirestoreService from inventory.dart file
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Resuable_widget/Products.dart';
import 'image_storage.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;

  static const int BATCH_SIZE = 10;
  static const Duration cacheDuration = Duration(minutes: 15);

  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _productsCollection = 'products';

  final Map<String, Product> _cache = {};
  DateTime? _lastCacheUpdate;

  Stream<List<Product>> getProductsStream({int limit = 20}) {
    return _firestore
        .collection(_productsCollection)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Product.fromFirestore).toList());
  }

  Future<List<Product>> getProducts({
    int limit = 20,
    DocumentSnapshot? lastDocument,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _isCacheValid()) {
      return _cache.values.toList()
        ..sort((a, b) => b.lastRestocked.compareTo(a.lastRestocked));
    }

    try {
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
    } catch (e, stacktrace) {
      print('Error fetching products: $e');
      print(stacktrace);
      if (!forceRefresh && _cache.isNotEmpty) {
        return _cache.values.toList()
          ..sort((a, b) => b.lastRestocked.compareTo(a.lastRestocked));
      }
      rethrow;
    }
  }

  bool _isCacheValid() {
    return _cache.isNotEmpty &&
        _lastCacheUpdate != null &&
        DateTime.now().difference(_lastCacheUpdate!) < cacheDuration;
  }

  Future<void> clearCache({bool forceRefresh = false}) async {
    _cache.clear();
    _lastCacheUpdate = null;
    if (forceRefresh) await getProducts();
  }

  Future<String> addProduct(Product product) async {
    try {
      final productData = {
        ...product.toFirestore(),
        'timestamp': FieldValue.serverTimestamp(),
      };

      final docRef = await _firestore.collection(_productsCollection).add(productData);

      _cache.clear();
      _lastCacheUpdate = null;

      return docRef.id;
    } catch (e, stacktrace) {
      print('Error adding product: $e');
      print(stacktrace);
      rethrow;
    }
  }

  Future<Product?> getProduct(String productId) async {
    try {
      final cacheHit = _cache[productId];
      if (cacheHit != null) return cacheHit;

      final doc = await _firestore.collection(_productsCollection).doc(productId).get(const GetOptions(
        source: Source.cache,
        serverTimestampBehavior: ServerTimestampBehavior.estimate,
      ));

      if (doc.exists) return Product.fromFirestore(doc);

      final serverDoc = await _firestore.collection(_productsCollection).doc(productId).get(const GetOptions(source: Source.server));

      return serverDoc.exists ? Product.fromFirestore(serverDoc) : null;
    } catch (e, stacktrace) {
      print('Error getting product: $e');
      print(stacktrace);
      rethrow;
    }
  }

  Future<void> batchUpdateProducts(List<Product> products) async {
    if (products.isEmpty) return;

    try {
      final batch = _firestore.batch();

      for (final product in products) {
        final docRef = _firestore.collection(_productsCollection).doc(product.id);
        batch.update(docRef, {
          ...product.toMap(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e, stacktrace) {
      print('Error batch updating products: $e');
      print(stacktrace);
      rethrow;
    }
  }

  Future<void> updateProduct(String productId, dynamic data) async {
    try {
      final docRef = _firestore.collection(_productsCollection).doc(productId);
      final oldDoc = await docRef.get();
      final oldData = oldDoc.data();
      final oldImageUrl = oldData?['imageUrl'];

      if (data is Product) {
        if (oldImageUrl != null && oldImageUrl != data.imageUrl) {
          await ImageStorage.deleteFromFirebase(oldImageUrl);
        }
        await docRef.update(data.toFirestore());
      } else if (data is Map<String, dynamic>) {
        if (oldImageUrl != null && data['imageUrl'] != oldImageUrl) {
          await ImageStorage.deleteFromFirebase(oldImageUrl);
        }
        await docRef.update(data);
      }
    } catch (e, stacktrace) {
      print('Error updating product: $e');
      print(stacktrace);
      rethrow;
    }
  }

  Future<void> deleteProduct(String productId) async {
    try {
      final docRef = _firestore.collection(_productsCollection).doc(productId);
      final doc = await docRef.get();
      final data = doc.data();
      final imageUrl = data?['imageUrl'];

      if (imageUrl != null) {
        await ImageStorage.deleteFromFirebase(imageUrl);
      }

      await docRef.delete();
      _cache.remove(productId);
    } catch (e, stacktrace) {
      print('Error deleting product: $e');
      print(stacktrace);
      rethrow;
    }
  }
}
