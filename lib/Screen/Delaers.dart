import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

  final Color primaryColor = const Color(0xFF006A4E);
  final Color secondaryColor = const Color(0xFF00876A);
  final Color accentColor = const Color(0xFFFFA500);
  final Color backgroundColor = const Color(0xFFF5F5F5);

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  void _showAddDealerBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
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
        child: SingleChildScrollView(
          child: Column(
            children: [
              Text('Add New Dealer',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor)),
              const SizedBox(height: 20),
              _buildTextField(_nameController, 'Dealer Name', Icons.store),
              const SizedBox(height: 10),
              _buildTextField(_contactController, 'Contact Number', Icons.phone, TextInputType.phone),
              const SizedBox(height: 10),
              _buildTextField(_locationController, 'Location', Icons.location_city),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _addDealer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Add Dealer', style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon,
      [TextInputType? type]) {
    return TextField(
      controller: controller,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primaryColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
      ),
    );
  }

  Future<void> _addDealer() async {
    if (_nameController.text.isEmpty ||
        _contactController.text.isEmpty ||
        _locationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Please fill all required fields'), backgroundColor: accentColor),
      );
      return;
    }

    try {
      await _firestore.collection('dealers').add({
        'name': _nameController.text,
        'location': _locationController.text,
        'contactNumber': _contactController.text,
        'timestamp': FieldValue.serverTimestamp(),
      });
      _nameController.clear();
      _contactController.clear();
      _locationController.clear();
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding dealer: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _deleteDealer(Dealer dealer) async {
    Navigator.pop(context); // Close the dialog immediately
    try {
      await _firestore.collection('dealers').doc(dealer.id).delete();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting dealer: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Dealers Management', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: primaryColor,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('dealers').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final dealers = snapshot.data?.docs.map((doc) => Dealer.fromFirestore(doc)).toList() ?? [];

          return dealers.isEmpty ? _buildEmptyState() : _buildDealersList(dealers);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDealerBottomSheet,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Dealer', style: TextStyle(color: Colors.white)),
        backgroundColor: secondaryColor,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.storefront_outlined, size: 100, color: primaryColor),
          const SizedBox(height: 20),
          Text('No Dealers Found', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor)),
          const SizedBox(height: 10),
          Text('Tap the "Add Dealer" button to get started', style: TextStyle(fontSize: 16, color: secondaryColor)),
        ],
      ),
    );
  }

  Widget _buildDealersList(List<Dealer> dealers) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: dealers.length,
      itemBuilder: (context, index) => _buildDealerCard(dealers[index]),
    );
  }

  Widget _buildDealerCard(Dealer dealer) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(dealer.name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor)),
          const SizedBox(height: 10),
          _buildInfoRow(Icons.location_city, dealer.location),
          const SizedBox(height: 5),
          _buildInfoRow(Icons.phone, dealer.contactNumber),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: Icon(Icons.delete_forever, color: accentColor),
              onPressed: () => showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Delete Dealer', style: TextStyle(color: primaryColor)),
                  content: Text('Are you sure you want to delete ${dealer.name}?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel', style: TextStyle(color: secondaryColor)),
                    ),
                    ElevatedButton(
                      onPressed: () => _deleteDealer(dealer),
                      style: ElevatedButton.styleFrom(backgroundColor: accentColor),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              ),
            ),
          )
        ]),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: secondaryColor),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(fontSize: 16, color: primaryColor))),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _locationController.dispose();
    super.dispose();
  }
}
