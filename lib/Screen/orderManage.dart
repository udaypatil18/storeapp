import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../Resuable_widget/Products.dart';

class OrderManagementPage extends StatefulWidget {
  @override
  _OrderManagementPageState createState() => _OrderManagementPageState();
}

class _OrderManagementPageState extends State<OrderManagementPage> {
  // Enhanced color palette
  final Color primaryColor = Color(0xFF006A4E); // Deep Teal
  final Color secondaryColor = Color(0xFF00876A); // Lighter Teal
  final Color accentColor = Color(0xFFFFA500); // Orange for alerts
  final Color backgroundColor = Color(0xFFF5F5F5); // Light background

  // Dummy dealers list
  List<String> dealers = [
    'Supplier A',
    'Supplier B',
    'Supplier C',
  ];

  // Dummy order history
  List<OrderItem> orderHistory = [
    OrderItem(
      id: '001',
      productName: 'Organic Spices Mix',
      dealer: 'Supplier A',
      quantity: 50,
      date: DateTime.now().subtract(Duration(days: 5)),
      status: OrderStatus.completed,
    ),
    OrderItem(
      id: '002',
      productName: 'Cooking Utensil Set',
      dealer: 'Supplier B',
      quantity: 25,
      date: DateTime.now().subtract(Duration(days: 10)),
      status: OrderStatus.inProgress,
    ),
    OrderItem(
      id: '003',
      productName: 'Kitchen Appliance',
      dealer: 'Supplier C',
      quantity: 10,
      date: DateTime.now().subtract(Duration(days: 15)),
      status: OrderStatus.pending,
    ),
  ];

  void _showOrderDialog(Product product) {
    String selectedDealer = dealers.first;
    int quantity = 1;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              title: Text(
                'Create New Order',
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedDealer,
                    dropdownColor: backgroundColor,
                    decoration: InputDecoration(
                      labelText: 'Select Dealer',
                      labelStyle: TextStyle(color: primaryColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: primaryColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: primaryColor, width: 2),
                      ),
                    ),
                    items: dealers.map((String dealer) {
                      return DropdownMenuItem<String>(
                        value: dealer,
                        child: Text(
                          dealer,
                          style: TextStyle(color: primaryColor),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          selectedDealer = newValue;
                        });
                      }
                    },
                  ),
                  SizedBox(height: 15),
                  TextField(
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      labelStyle: TextStyle(color: primaryColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: primaryColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: primaryColor, width: 2),
                      ),
                    ),
                    onChanged: (value) {
                      quantity = int.tryParse(value) ?? 1;
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: secondaryColor),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.message_outlined, color: Colors.white),
                      SizedBox(width: 5),
                      Text(
                        'Send Order',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                  onPressed: () {
                    _sendWhatsAppOrder(
                      product: Product(
                        id: 1,
                        name: 'Sample Product',
                        stock: 0,
                        status: "Out of Stock",
                      ),
                      dealer: selectedDealer,
                      quantity: quantity,
                    );
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _sendWhatsAppOrder({
    required Product product,
    required String dealer,
    required int quantity,
  }) async {
    String message = 'Order Details:\n'
        'Product: ${product.name}\n'
        'Dealer: $dealer\n'
        'Quantity: $quantity';

    String url = 'whatsapp://send?text=${Uri.encodeComponent(message)}';

    if (await canLaunch(url)) {
      await launch(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not launch WhatsApp'),
          backgroundColor: accentColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Order Management',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryColor,
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: Colors.white),
            onPressed: () {
              _showOrderDialog(Product(
                id: 1,
                name: 'Sample Product',
                stock: 0,
                status: "Out of Stock",
              ));
            },
          ),
        ],
      ),
      body:
          orderHistory.isEmpty ? _buildEmptyState() : _buildOrderHistoryList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 120,
            color: primaryColor,
          ),
          SizedBox(height: 20),
          Text(
            'No Orders Yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Tap the "+" button to create a new order',
            style: TextStyle(
              fontSize: 16,
              color: secondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderHistoryList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: orderHistory.length,
      itemBuilder: (context, index) {
        return _buildOrderCard(orderHistory[index]);
      },
    );
  }

  Widget _buildOrderCard(OrderItem order) {
    Color statusColor;
    IconData statusIcon;

    switch (order.status) {
      case OrderStatus.completed:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case OrderStatus.inProgress:
        statusColor = Colors.orange;
        statusIcon = Icons.refresh;
        break;
      case OrderStatus.pending:
        statusColor = Colors.grey;
        statusIcon = Icons.pending;
        break;
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      margin: EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${order.id}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(statusIcon, color: statusColor, size: 16),
                      SizedBox(width: 4),
                      Text(
                        order.status.toString().split('.').last,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              'Product: ${order.productName}',
              style: TextStyle(
                fontSize: 16,
                color: primaryColor,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Dealer: ${order.dealer}',
              style: TextStyle(
                fontSize: 16,
                color: secondaryColor,
              ),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Quantity: ${order.quantity}',
                  style: TextStyle(
                    fontSize: 16,
                    color: primaryColor,
                  ),
                ),
                Text(
                  _formatDate(order.date),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

// Enum for order status
enum OrderStatus {
  pending,
  inProgress,
  completed,
}

// Order item class to represent order details
class OrderItem {
  final String id;
  final String productName;
  final String dealer;
  final int quantity;
  final DateTime date;
  final OrderStatus status;

  OrderItem({
    required this.id,
    required this.productName,
    required this.dealer,
    required this.quantity,
    required this.date,
    required this.status,
  });
}
