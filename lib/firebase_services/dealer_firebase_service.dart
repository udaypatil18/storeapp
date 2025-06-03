import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobistore/Screen/Delaers.dart';

class DealerFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _dealersCollection = 'dealers';

  // Stream dealers for real-time updates
  Stream<List<Dealer>> streamDealers() {
    return _firestore
        .collection(_dealersCollection)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Dealer.fromFirestore(doc)).toList();
    });
  }

  // Add a new dealer
  Future<void> addDealer(Dealer dealer) async {
    try {
      await _firestore.collection(_dealersCollection).add({
        'name': dealer.name,
        'location': dealer.location,
        'contactNumber': dealer.contactNumber,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error adding dealer: $e');
      throw e;
    }
  }

  // Delete a dealer
  Future<void> deleteDealer(String dealerId) async {
    try {
      await _firestore.collection(_dealersCollection).doc(dealerId).delete();
    } catch (e) {
      print('Error deleting dealer: $e');
      throw e;
    }
  }
}