import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Dealer {
  final String id;  // Changed from int to String for Firestore compatibility
  final String name;
  final String location;
  final String contactNumber;

  Dealer({
    required this.id,
    required this.name,
    required this.location,
    required this.contactNumber,
  });

  // Add this method to create Dealer from Firestore document
  factory Dealer.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Dealer(
      id: doc.id,
      name: data['name'] ?? '',
      location: data['location'] ?? '',
      contactNumber: data['contactNumber'] ?? '',
    );
  }

  // Add this method to convert Dealer to Firestore data
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'location': location,
      'contactNumber': contactNumber,
    };
  }
}

// Function to get list of dealers - can be used as a fallback
List<Dealer> getDealersList() {
  return [
    Dealer(
      id: '1',
      name: 'Green Wholesales',
      location: 'Mumbai',
      contactNumber: '+91 9876543210',
    ),
    Dealer(
      id: '2',
      name: 'Spice Suppliers',
      location: 'Delhi',
      contactNumber: '+91 8765432109',
    ),
    Dealer(
      id: '3',
      name: 'Kitchen Essentials',
      location: 'Bangalore',
      contactNumber: '+91 7654321098',
    ),
  ];
}

// Function to ensure dealers exist in Firestore
Future<void> ensureDealersExist() async {
  try {
    final snapshot = await FirebaseFirestore.instance.collection('dealers').get();

    if (snapshot.docs.isEmpty) {
      // If no dealers exist, add the default ones
      final batch = FirebaseFirestore.instance.batch();

      for (var dealer in getDealersList()) {
        final docRef = FirebaseFirestore.instance.collection('dealers').doc();
        batch.set(docRef, dealer.toFirestore());
      }

      await batch.commit();
      print('Default dealers added to Firestore');
    }
  } catch (e) {
    print('Error ensuring dealers exist: $e');
  }
}