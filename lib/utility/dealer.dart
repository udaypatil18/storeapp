import 'package:flutter/material.dart';

// Dealer Model - keep it consistent with what you're using in DealersPage
class Dealer {
  final int id;
  final String name;
  final String location;
  final String contactNumber;

  Dealer({
    required this.id,
    required this.name,
    required this.location,
    required this.contactNumber,
  });
}

// Function to get list of dealers
List<Dealer> getDealers() {
  return [
    Dealer(
      id: 1,
      name: 'Green Wholesales',
      location: 'Mumbai',
      contactNumber: '+91 9876543210',
    ),
    Dealer(
      id: 2,
      name: 'Spice Suppliers',
      location: 'Delhi',
      contactNumber: '+91 8765432109',
    ),
    Dealer(
      id: 3,
      name: 'Kitchen Essentials',
      location: 'Bangalore',
      contactNumber: '+91 7654321098',
    ),
  ];
}
