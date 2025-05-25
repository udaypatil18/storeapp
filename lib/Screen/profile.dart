import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  // Enhanced color palette
  final Color primaryColor = Color(0xFF006A4E); // Deep Teal
  final Color secondaryColor = Color(0xFF00876A); // Lighter Teal
  final Color accentColor = Color(0xFFFFA500); // Orange for alerts
  final Color backgroundColor = Color(0xFFF5F5F5); // Light background

  // User profile data
  final UserProfile userProfile = UserProfile(
    name: 'User ABC',
    phoneNumber: '+91 9876543210',
    productCount: 3,
    dealerCount: 3,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'User Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryColor,
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Card(
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Profile Avatar
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: primaryColor.withOpacity(0.2),
                    child: Icon(
                      Icons.person,
                      size: 80,
                      color: primaryColor,
                    ),
                  ),
                  SizedBox(height: 20),

                  // Name
                  Text(
                    userProfile.name,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  SizedBox(height: 10),

                  // Phone Number
                  _buildInfoRow(
                    icon: Icons.phone,
                    text: userProfile.phoneNumber,
                  ),
                  SizedBox(height: 20),

                  // Stats Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatColumn(
                        count: userProfile.productCount,
                        label: 'Products',
                        icon: Icons.inventory,
                      ),
                      _buildStatColumn(
                        count: userProfile.dealerCount,
                        label: 'Dealers',
                        icon: Icons.storefront,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper widget to build info rows
  Widget _buildInfoRow({required IconData icon, required String text}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          color: secondaryColor,
          size: 24,
        ),
        SizedBox(width: 10),
        Text(
          text,
          style: TextStyle(
            fontSize: 18,
            color: primaryColor,
          ),
        ),
      ],
    );
  }

  // Helper widget to build stat columns
  Widget _buildStatColumn({
    required int count,
    required String label,
    required IconData icon,
  }) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: accentColor,
            size: 32,
          ),
        ),
        SizedBox(height: 8),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: secondaryColor,
          ),
        ),
      ],
    );
  }
}

// User Profile Model
class UserProfile {
  final String name;
  final String phoneNumber;
  final int productCount;
  final int dealerCount;

  UserProfile({
    required this.name,
    required this.phoneNumber,
    required this.productCount,
    required this.dealerCount,
  });
}
