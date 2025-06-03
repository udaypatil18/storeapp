import 'package:cloud_firestore/cloud_firestore.dart';

import '../Screen/orderManage.dart';

class OrderFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _ordersCollection = 'orders';
  final String _dealersCollection = 'dealers';
  final String _counterCollection = 'counters';

  // Get the next order ID using a counter document
  Future<int> _getNextOrderId() async {
    try {
      // Use a transaction to ensure atomic increment
      return await _firestore.runTransaction<int>((transaction) async {
        // Get the counter document
        DocumentReference counterRef = _firestore
            .collection(_counterCollection)
            .doc('orderCounter');

        DocumentSnapshot counterDoc = await transaction.get(counterRef);

        // If the counter doesn't exist, create it with initial value
        if (!counterDoc.exists) {
          transaction.set(counterRef, {'value': 1});
          return 1;
        }

        // Get the current counter value
        int currentValue = (counterDoc.data() as Map<String, dynamic>)['value'] ?? 0;
        int nextValue = currentValue + 1;

        // Update the counter
        transaction.update(counterRef, {'value': nextValue});

        return nextValue;
      });
    } catch (e) {
      print('Error getting next order ID: $e');
      // Generate a timestamp-based ID as fallback
      return DateTime.now().millisecondsSinceEpoch;
    }
  }

  // Add a new order with the correct ID
  Future<void> addOrder(OrderItem order) async {
    try {
      int nextId = await _getNextOrderId();

      Map<String, dynamic> orderData = {
        ...order.toMap(),
        'orderId': nextId,  // Store the order ID in the document
        'date': FieldValue.serverTimestamp(),
        'createdAt': DateTime.now().toIso8601String(),
      };

      await _firestore
          .collection(_ordersCollection)
          .doc(nextId.toString())
          .set(orderData);
    } catch (e) {
      print('Error adding order: $e');
      throw e;
    }
  }

  // Stream orders with proper ordering
  Stream<List<OrderItem>> streamOrders() {
    return _firestore
        .collection(_ordersCollection)
        .orderBy('orderId', descending: true)  // Order by orderId instead of date
        .snapshots()
        .map((snapshot) {
      try {
        return snapshot.docs.map((doc) {
          return OrderItem.fromFirestore(doc);
        }).toList();
      } catch (e) {
        print('Error mapping orders: $e');
        return [];
      }
    });
  }

  // Stream dealers (unchanged)
  Stream<List<String>> streamDealers() {
    return _firestore
        .collection(_dealersCollection)
        .snapshots()
        .map((snapshot) {
      try {
        return snapshot.docs
            .map((doc) => doc.data()['name'] as String)
            .where((name) => name != null)
            .toList();
      } catch (e) {
        print('Error mapping dealers: $e');
        return [];
      }
    });
  }
}