import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../Resuable_widget/Products.dart';
import '../firebase_services/order_firebase_service.dart';

enum OrderStatus { pending, inProgress, completed }

class OrderItem {
  final int id;
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

  factory OrderItem.fromFirestore(DocumentSnapshot doc) {
    try {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      return OrderItem(
        id: (data['orderId'] as num?)?.toInt() ?? 0,
        productName: data['productName'] ?? '',
        dealer: data['dealer'] ?? '',
        quantity: (data['quantity'] as num?)?.toInt() ?? 0,
        date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
        status: _stringToOrderStatus(data['status'] ?? ''),
      );
    } catch (e) {
      return OrderItem(
        id: 0,
        productName: 'Error',
        dealer: 'Unknown',
        quantity: 0,
        date: DateTime.now(),
        status: OrderStatus.pending,
      );
    }
  }

  Map<String, dynamic> toMap() => {
    'productName': productName,
    'dealer': dealer,
    'quantity': quantity,
    'status': status.toString(),
  };

  static OrderStatus _stringToOrderStatus(String status) {
    switch (status) {
      case 'OrderStatus.completed':
        return OrderStatus.completed;
      case 'OrderStatus.inProgress':
        return OrderStatus.inProgress;
      default:
        return OrderStatus.pending;
    }
  }
}

class OrderManagementPage extends StatefulWidget {
  @override
  State<OrderManagementPage> createState() => _OrderManagementPageState();
}

class _OrderManagementPageState extends State<OrderManagementPage> {
  final OrderFirestoreService _orderService = OrderFirestoreService();

  final Color primaryColor = const Color(0xFF006A4E);
  final Color secondaryColor = const Color(0xFF00876A);
  final Color accentColor = const Color(0xFFFFA500);
  final Color backgroundColor = const Color(0xFFF5F5F5);

  void _showOrderDialog(Product product) {
    String? selectedDealer;
    int quantity = 1;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text('Create New Order', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
          content: StreamBuilder<List<String>>(
            stream: _orderService.streamDealers(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError || !(snapshot.hasData && snapshot.data!.isNotEmpty)) {
                return const Text('No dealers available');
              }

              List<String> dealers = snapshot.data!;
              selectedDealer ??= dealers.first;

              return StatefulBuilder(builder: (context, setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedDealer,
                      decoration: _inputDecoration('Select Dealer'),
                      dropdownColor: backgroundColor,
                      items: dealers
                          .map((dealer) => DropdownMenuItem(value: dealer, child: Text(dealer)))
                          .toList(),
                      onChanged: (value) => setState(() => selectedDealer = value),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration('Quantity'),
                      onChanged: (val) => quantity = int.tryParse(val) ?? 1,
                    ),
                  ],
                );
              });
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: secondaryColor)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedDealer == null) return;

                final order = OrderItem(
                  id: 0,
                  productName: product.name,
                  dealer: selectedDealer!,
                  quantity: quantity,
                  date: DateTime.now(),
                  status: OrderStatus.pending,
                );

                try {
                  await _orderService.addOrder(order);
                  Navigator.of(context).pop(); // Close dialog first
                  Future.delayed(Duration(milliseconds: 100), () {
                    _sendWhatsAppOrder(product.name, selectedDealer!, quantity);
                  });
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.message_outlined, color: Colors.white),
                  SizedBox(width: 5),
                  Text('Send Order', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: primaryColor),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
    );
  }

  void _sendWhatsAppOrder(String product, String dealer, int quantity) async {
    String message = 'Order Details:\nProduct: $product\nDealer: $dealer\nQuantity: $quantity';
    String url = 'whatsapp://send?text=${Uri.encodeComponent(message)}';

    if (await canLaunch(url)) {
      await launch(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Could not launch WhatsApp'), backgroundColor: accentColor),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text('Order Management', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () {
              _showOrderDialog(Product(
                id: "1",
                name: 'Sample Product',
                variations: [],
                category: '',
                lastRestocked: DateTime.now(),
              ));
            },
          ),
        ],
      ),
      body: StreamBuilder<List<OrderItem>>(
        stream: _orderService.streamOrders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final orders = snapshot.data ?? [];
          return orders.isEmpty ? _buildEmptyState() : _buildOrderHistoryList(orders);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 100, color: primaryColor),
          const SizedBox(height: 20),
          Text('No Orders Yet', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor)),
          const SizedBox(height: 10),
          Text('Tap "+" to create a new order', style: TextStyle(color: secondaryColor)),
        ],
      ),
    );
  }

  Widget _buildOrderHistoryList(List<OrderItem> orders) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) => _buildOrderCard(orders[index]),
    );
  }

  Widget _buildOrderCard(OrderItem order) {
    final statusData = _getStatusStyle(order.status);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Order #${order.id}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusData['color'].withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(statusData['icon'], color: statusData['color'], size: 16),
                    const SizedBox(width: 4),
                    Text(statusData['label'], style: TextStyle(color: statusData['color'], fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Product: ${order.productName}', style: TextStyle(fontSize: 16, color: primaryColor)),
          const SizedBox(height: 8),
          Text('Dealer: ${order.dealer}', style: TextStyle(fontSize: 16, color: secondaryColor)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Quantity: ${order.quantity}', style: TextStyle(fontSize: 16, color: primaryColor)),
              Text(_formatDate(order.date), style: const TextStyle(fontSize: 14, color: Colors.grey)),
            ],
          ),
        ]),
      ),
    );
  }

  Map<String, dynamic> _getStatusStyle(OrderStatus status) {
    switch (status) {
      case OrderStatus.completed:
        return {'label': 'Completed', 'icon': Icons.check_circle, 'color': Colors.green};
      case OrderStatus.inProgress:
        return {'label': 'In Progress', 'icon': Icons.refresh, 'color': Colors.orange};
      default:
        return {'label': 'Pending', 'icon': Icons.pending, 'color': Colors.grey};
    }
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
}
