import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobistore/Screen/cart.dart';
import 'package:mobistore/firebase_services/firebase_service.dart';

import '../Screen/Delaers.dart';

class CartService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Global shared cart for all users
  CollectionReference get _cartRef => _firestore.collection('global_cart');

  // Stream cart items
  Stream<List<CartItem>> streamCartItems() {
    return _cartRef.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => CartItem.fromFirestore(doc)).toList());
  }

  // Add item to cart
  Future<void> addItem(CartItem item) async {
    try {
      final existingItemQuery = await _cartRef
          .where('productId', isEqualTo: item.product.id)
          .where('variationSize', isEqualTo: item.variation.size)
          .limit(1)
          .get();

      final batch = _firestore.batch();

      if (existingItemQuery.docs.isNotEmpty) {
        final doc = existingItemQuery.docs.first;
        batch.update(doc.reference, {
          'quantity': item.quantity,
          'availableQuantity': item.availableQuantity,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      } else {
        final newRef = _cartRef.doc();
        batch.set(newRef, {
          'productId': item.product.id,
          'variationSize': item.variation.size,
          'product': item.product.toFirestore(),
          'variation': item.variation.toFirestore(),
          'quantity': item.quantity,
          'availableQuantity': item.availableQuantity,
          'isSelected': item.isSelected,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      print('Error adding item to cart: $e');
      throw Exception('Failed to add item to cart: $e');
    }
  }

  // Update item quantity
  Future<void> updateQuantity(String itemId, int quantity) async {
    await _cartRef.doc(itemId).update({'quantity': quantity});
  }

  // Remove item
  Future<void> removeItem(String itemId) async {
    await _cartRef.doc(itemId).delete();
  }

  // Clear cart
  Future<void> clearCart() async {
    final batch = _firestore.batch();
    final snapshots = await _cartRef.get();

    for (var doc in snapshots.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  // Get cart total
  Future<double> getCartTotal() async {
    try {
      final snapshot = await _cartRef.get();
      double total = 0.0;

      for (var doc in snapshot.docs) {
        final item = CartItem.fromFirestore(doc);
        total += (item.variation.price * item.quantity);
      }

      return total;
    } catch (e) {
      print('Error calculating cart total: $e');
      return 0.0;
    }
  }

  Future<void> updateItem(String itemId, Map<String, dynamic> data) async {
    try {
      await _cartRef.doc(itemId).update(data);
    } catch (e) {
      print('Error updating cart item: $e');
      throw e;
    }
  }

  Future<int> getItemCount() async {
    final snapshot = await _cartRef.get();
    return snapshot.docs.length;
  }

  Future<List<CartItem>> getCartItems() async {
    final snapshot = await _cartRef.get();
    return snapshot.docs.map((doc) => CartItem.fromFirestore(doc)).toList();
  }

  Future<double> getSelectedItemsTotal() async {
    try {
      final snapshot = await _cartRef.get();
      double total = 0.0;

      for (var doc in snapshot.docs) {
        final item = CartItem.fromFirestore(doc);
        if (item.isSelected) {
          total += (item.variation.price * item.quantity);
        }
      }

      return total;
    } catch (e) {
      print('Error calculating selected items total: $e');
      return 0.0;
    }
  }

  Future<List<Dealer>> fetchDealers() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('dealers').get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Dealer(
          id: doc.id,
          name: data['name'] ?? '',
          location: data['location'] ?? '',
          contactNumber: data['contactNumber'] ?? '',
        );
      }).toList();
    } catch (e) {
      print('Error fetching dealers: $e');
      return [];
    }
  }
}
