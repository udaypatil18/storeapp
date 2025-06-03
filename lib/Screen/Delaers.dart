import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// Import the Dealer class and getDealers function from utility
import '../firebase_services/dealer_firebase_service.dart';
import '../utility/dealer.dart' as DealerUtil;
class Dealer {
  String? id;
  final String name;
  final String location;
  final String contactNumber;

  Dealer({
    this.id,
    required this.name,
    required this.location,
    required this.contactNumber,
  });

  // Add these methods to work with Firestore
  factory Dealer.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Dealer(
      id: doc.id,
      name: data['name'] ?? '',
      location: data['location'] ?? '',
      contactNumber: data['contactNumber'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'location': location,
      'contactNumber': contactNumber,
    };
  }
}
class DealersPage extends StatefulWidget {
  const DealersPage({Key? key}) : super(key: key);

  @override
  State<DealersPage> createState() => _DealersPageState();
}

class _DealersPageState extends State<DealersPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Enhanced color palette
  final Color primaryColor = Color(0xFF006A4E); // Deep Teal
  final Color secondaryColor = Color(0xFF00876A); // Lighter Teal
  final Color accentColor = Color(0xFFFFA500); // Orange for alerts
  final Color backgroundColor = Color(0xFFF5F5F5); // Light background

  final DealerFirestoreService _dealerService = DealerFirestoreService();

  // List to store dealers - using the Dealer class from utility


  // Controllers for the add dealer form
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  // Method to show add dealer bottom sheet
  void _showAddDealerBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      backgroundColor: backgroundColor,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add New Dealer',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 20),
            _buildTextField(_nameController, 'Dealer Name', Icons.store),
            const SizedBox(height: 10),
            _buildTextField(
                _locationController, 'Location', Icons.location_city),
            const SizedBox(height: 10),
            _buildTextField(_contactController, 'Contact Number', Icons.phone,
                TextInputType.phone),
            const SizedBox(height: 10),
            _buildTextField(_emailController, 'Email Address', Icons.email,
                TextInputType.emailAddress),
            const SizedBox(height: 10),
            _buildTextField(
              _addressController,
              'Address',
              Icons.location_on,
              TextInputType.multiline,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _addDealer,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Add Dealer',
                style: TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Helper method to build consistent text fields
  Widget _buildTextField(
      TextEditingController controller, String labelText, IconData prefixIcon,
      [TextInputType? keyboardType, int? maxLines = 1]) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(prefixIcon, color: primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primaryColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
    );
  }

  // Method to add a new dealer
  void _addDealer() async {
    if (_nameController.text.isEmpty ||
        _contactController.text.isEmpty ||
        _locationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: accentColor,
        ),
      );
      return;
    }

    try {
      // Add to Firestore
      await _firestore.collection('dealers').add({
        'name': _nameController.text,
        'location': _locationController.text,
        'contactNumber': _contactController.text,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Clear controllers and close bottom sheet
      _nameController.clear();
      _contactController.clear();
      _locationController.clear();
      _emailController.clear();
      _addressController.clear();
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding dealer: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  // Method to delete a dealer
  void _deleteDealer(Dealer dealer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Dealer',
          style: TextStyle(color: primaryColor),
        ),
        content: Text('Are you sure you want to delete ${dealer.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: TextStyle(color: secondaryColor)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _firestore.collection('dealers').doc(dealer.id).delete();
                Navigator.of(context).pop();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error deleting dealer: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: accentColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Dealers Management',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        elevation: 0,
      ),
      body:StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('dealers').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final dealers = snapshot.data?.docs
              .map((doc) => Dealer.fromFirestore(doc))
              .toList() ?? [];

          return dealers.isEmpty ? _buildEmptyState() : _buildDealersList(dealers);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDealerBottomSheet,
        icon: Icon(Icons.add, color: Colors.white),
        label: Text('Add Dealer', style: TextStyle(color: Colors.white)),
        backgroundColor: secondaryColor,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.storefront_outlined,
            size: 120,
            color: primaryColor,
          ),
          const SizedBox(height: 20),
          Text(
            'No Dealers Found',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Tap the "Add Dealer" button to get started',
            style: TextStyle(
              fontSize: 16,
              color: secondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDealersList(List<Dealer> dealers) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: dealers.length,
      itemBuilder: (context, index) {
        final dealer = dealers[index];
        return _buildDealerCard(dealer);
      },
    );
  }

  Widget _buildDealerCard(Dealer dealer) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      margin: const EdgeInsets.symmetric(vertical: 10),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    dealer.name,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.location_city, dealer.location),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.phone, dealer.contactNumber),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: Icon(
                  Icons.delete_forever,
                  color: accentColor,
                  size: 28,
                ),
                onPressed: () => _deleteDealer(dealer),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          color: secondaryColor,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: primaryColor,
              fontSize: 16,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    // Clean up controllers
    _nameController.dispose();
    _contactController.dispose();
    _locationController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }
}