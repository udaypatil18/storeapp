import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../Resuable_widget/Products.dart';
import '../utility/dealer.dart';
import 'inventory.dart';

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:mobistore/Resuable_widget/Products.dart';
import 'package:mobistore/firebase_services/firebase_service.dart';
import 'package:mobistore/firebase_services/cart_services.dart';



class CartItem {
  final String? id;
  final Product product;
  final ProductVariation variation;
  int quantity;
  int? availableQuantity;
  bool isSelected;

  CartItem({
    this.id,
    required this.product,
    required this.variation,
    this.quantity = 1,
    this.availableQuantity,
    this.isSelected = true,
  });

  double get totalPrice => variation.price * quantity;

  // Create CartItem from Firestore document
  factory CartItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CartItem(
      id: doc.id,
      product: Product.fromFirestore(data['product'] as Map<String, dynamic>),
      variation: ProductVariation.fromFirestore(data['variation'] as Map<String, dynamic>),
      quantity: data['quantity'] ?? 1,
      availableQuantity: data['availableQuantity'], // Add this line
      isSelected: data['isSelected'] ?? true,
    );
  }

  // Convert CartItem to Firestore data
  // Modify the toFirestore method in CartItem class
  Map<String, dynamic> toFirestore() {
    return {
      'productId': product.id,
      'product': product.toFirestore(),
      'variation': variation.toFirestore(),
      'quantity': quantity,
      'availableQuantity': availableQuantity, // Add this line
      'isSelected': isSelected,
    };
  }
}

class CartPage extends StatefulWidget {
  const CartPage({Key? key}) : super(key: key);

  @override
  _CartPageState createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  // Enhanced color palette (same as inventory page for consistency)
  final Color primaryColor = Color(0xFF006A4E); // Deep Teal
  final Color secondaryColor = Color(0xFF00876A); // Lighter Teal
  final Color accentColor = Color(0xFFFFA500); // Orange for alerts
  final Color backgroundColor = Color(0xFFF5F5F5); // Light background

  // Dealers list
  List<Dealer> dealersList = [];
  Dealer? selectedDealer;
  bool _loadingDealers = false;
  // Store ScaffoldMessengerState reference for safe access
  late ScaffoldMessengerState _scaffoldMessenger;

  late final CartService _cartService;
  late Stream<List<CartItem>> _cartStream;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Safely store reference to scaffold messenger
    _scaffoldMessenger = ScaffoldMessenger.of(context);
  }

  @override
  void initState() {
    super.initState();
    // Initialize cart service with current user ID
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _cartService = CartService(userId: user.uid);
      _cartStream = _cartService.streamCartItems();
      _loadDealers();
    }
  }

  // Toggle selection of all items
  Future<void> _toggleSelectAll(bool? value, List<CartItem> items) async {
    if (value != null) {
      for (var item in items) {
        await _cartService.updateItem(item.id!, {'isSelected': value});
      }
    }
  }


  // Modified _calculateTotalSelectedPrice() method with debugging
  double _calculateTotalSelectedPrice() {
    double total = 0;

    for (var item in CartManager.instance.items) {
      if (item.isSelected) {
        total += (item.variation.price * item.quantity);
      }
    }

    return total;
  }

  // Calculate total number of selected items
  int _countSelectedItems() {
    return CartManager.instance.items.where((item) => item.isSelected).length;
  }

  // Remove an item from cart
  Future<void> _removeFromCart(CartItem item) async {
    await _cartService.removeItem(item.id!);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Item removed from cart')),
    );
  }

  // Update quantity directly
  // Optimized cart operations
  Future<void> _updateQuantity(CartItem item, String value) async {
    final newQuantity = int.tryParse(value);
    if (newQuantity != null && newQuantity > 0) {
      await _cartService.updateQuantity(item.id!, newQuantity);
    }
  }

  // Add this method
  Future<void> _loadDealers() async {
    setState(() {
      _loadingDealers = true;
    });

    try {
      final dealers = await FirebaseFirestore.instance
          .collection('dealers')
          .get()
          .then((snapshot) => snapshot.docs
          .map((doc) => Dealer.fromFirestore(doc))
          .toList());

      setState(() {
        dealersList = dealers;
        _loadingDealers = false;
      });
    } catch (e) {
      print('Error loading dealers: $e');
      setState(() {
        _loadingDealers = false;
      });
    }
  }

  // Generate and share order as PDF
  Future<void> _generateAndShareOrderPdf() async {
    if (_countSelectedItems() == 0 || selectedDealer == null) {
      return;
    }

    final selectedItems =
    CartManager.instance.items.where((item) => item.isSelected).toList();

    final pdf = pw.Document();

    // Add pages to the PDF
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Order Receipt',
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Text('Dealer: ${selectedDealer!.name}'),
              pw.Text('Location: ${selectedDealer!.location}'),
              pw.Text(
                  'Date: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}'),
              pw.SizedBox(height: 20),
              pw.Text('Order Summary:',
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: pw.EdgeInsets.all(5),
                        child: pw.Text('Item',
                            style:
                            pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(5),
                        child: pw.Text('Size',
                            style:
                            pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(5),
                        child: pw.Text('Qty',
                            style:
                            pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  ...selectedItems.map((item) => pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: pw.EdgeInsets.all(5),
                        child: pw.Text(item.product.name),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(5),
                        child: pw.Text(item.variation.size),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(5),
                        child: pw.Text('${item.quantity}'),
                      ),
                    ],
                  )),
                ],
              ),
              pw.SizedBox(height: 20),
            ],
          );
        },
      ),
    );

    // Save the PDF
    final output = await getTemporaryDirectory();
    final file = File(
        '${output.path}/order_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());

    // Share the PDF - Fixed: Using the correct method from share_plus
    await Share.shareXFiles([XFile(file.path)], text: 'Your Order Receipt');
  }


  // Add this method to _CartPageState class
  Future<pw.Document> _generateOrderPdf(List<CartItem> items) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Order Receipt',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              // Add dealer information
              pw.Text('Dealer: ${selectedDealer?.name ?? "N/A"}',
                  style: pw.TextStyle(fontSize: 14)),
              pw.Text('Location: ${selectedDealer?.location ?? "N/A"}',
                  style: pw.TextStyle(fontSize: 14)),
              pw.Text('Date: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 14)),
              pw.SizedBox(height: 20),
              pw.Text('Order Summary:',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: pw.EdgeInsets.all(5),
                        child: pw.Text('Item',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(5),
                        child: pw.Text('Size',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(5),
                        child: pw.Text('Qty',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(5),
                        child: pw.Text('Price',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  ...items.map((item) => pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: pw.EdgeInsets.all(5),
                        child: pw.Text(item.product.name),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(5),
                        child: pw.Text(item.variation.size),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(5),
                        child: pw.Text('${item.quantity}'),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(5),
                        child: pw.Text('₹${item.totalPrice.toStringAsFixed(2)}'),
                      ),
                    ],
                  )),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Total: Rs .${items.fold(0.0, (sum, item) => sum + item.totalPrice).toStringAsFixed(2)}',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

// Add this method to _CartPageState class
  Future<void> _createOrder(List<CartItem> items) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final orderData = {
      'userId': user.uid,
      'dealerId': selectedDealer!.id,
      'dealerName': selectedDealer!.name,
      'dealerLocation': selectedDealer!.location,
      'items': items.map((item) => {
        'productId': item.product.id,
        'product': item.product.toFirestore(),
        'variation': item.variation.toFirestore(),
        'quantity': item.quantity,
        'price': item.variation.price,
        'totalPrice': item.totalPrice,
      }).toList(),
      'totalAmount': items.fold(0.0, (sum, item) => sum + item.totalPrice),
      'orderDate': FieldValue.serverTimestamp(),
      'status': 'pending',
      'createdAt': DateTime.now().toIso8601String(), // Add this as a backup timestamp
    };

    try {
      await FirebaseFirestore.instance.collection('orders').add(orderData);
    } catch (e) {
      print('Error creating order: $e');
      throw Exception('Failed to create order: $e');
    }
  }


  Future<String> _cacheOrderPdf(List<CartItem> items) async {
    final pdf = await _generateOrderPdf(items);
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/order_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file.path;
  }

  // Place order for selected items
  // Update the _placeOrder method signature and implementation
  Future<void> _placeOrder() async {
    if (selectedDealer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a dealer first')),
      );
      _showDealerSelectionDialog();
      return;
    }

    final items = await _cartService.getCartItems();
    final selectedItems = items.where((item) => item.isSelected).toList();

    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select items to place order')),
      );
      return;
    }

    try {
      // Show confirmation dialog
      bool? confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text('Confirm Order'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dealer: ${selectedDealer!.name}'),
                SizedBox(height: 8),
                Text(
                  'Total: ₹${selectedItems.fold(0.0, (sum, item) => sum + item.totalPrice).toStringAsFixed(2)}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                Text('Order Summary:'),
                SizedBox(height: 8),
                ...selectedItems.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text(
                    '• ${item.product.name} (${item.variation.size}) x ${item.quantity}',
                    style: TextStyle(fontSize: 14),
                  ),
                )),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: Text('Confirm'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // Show loading dialog
      BuildContext? dialogContext;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          dialogContext = context;
          return Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Processing order...'),
                  ],
                ),
              ),
            ),
          );
        },
      );

      try {
        // Generate and cache PDF first
        final pdfPath = await _cacheOrderPdf(selectedItems);

        // Create order in Firestore
        await _createOrder(selectedItems);

        // Remove items from cart
        for (var item in selectedItems) {
          await _cartService.removeItem(item.id!);
        }

        // Close loading dialog
        if (dialogContext != null && mounted) {
          Navigator.of(dialogContext!).pop();
        }

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order placed successfully')),
        );

        // Share PDF
        await Share.shareXFiles(
          [XFile(pdfPath)],
          text: 'Order Receipt',
          subject: 'Order Receipt ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
        );

      } catch (e) {
        // Close loading dialog on error
        if (dialogContext != null && mounted) {
          Navigator.of(dialogContext!).pop();
        }

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error placing order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Separate method to process purchase after dialog closes
  void _processPurchaseOrder() {
    _generateAndShareOrderPdf().then((_) {
      if (mounted) {
        setState(() {
          // Create a copy of the items list to avoid modification during iteration
          final itemsToRemove = CartManager.instance.items
              .where((item) => item.isSelected)
              .toList();

          // Remove each selected item from the cart
          for (var item in itemsToRemove) {
            CartManager.instance.removeItem(item);
          }
        });

        // Show confirmation message using the saved messenger reference
        _scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Order placed successfully')),
        );
      }
    });
  }

  // Show dealer selection dialog
  void _showDealerSelectionDialog() {
    if (dealersList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No dealers available. Please try again later.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Select Dealer'),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_loadingDealers)
                Center(child: CircularProgressIndicator())
              else if (dealersList.isEmpty)
                Text('No dealers available')
              else
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: dealersList.map((dealer) => RadioListTile<Dealer>(
                        title: Text(dealer.name),
                        subtitle: Text(dealer.location),
                        value: dealer,
                        groupValue: selectedDealer,
                        onChanged: (Dealer? value) {
                          setState(() {
                            selectedDealer = value;
                          });
                          Navigator.of(dialogContext).pop();
                          _placeOrder();
                        },
                      )).toList(),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }

  // Check if all items are selected
  bool _areAllItemsSelected() {
    if (CartManager.instance.items.isEmpty) return false;
    return CartManager.instance.items.every((item) => item.isSelected);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
      title: Text(
      'My Cart',
      style: TextStyle(color: Colors.white),
    ),
    backgroundColor: primaryColor,
    actions: [
    StreamBuilder<List<CartItem>>(
    stream: _cartStream,
    builder: (context, snapshot) {
    if (!snapshot.hasData || snapshot.data!.isEmpty) {
    return SizedBox.shrink();
    }
    final items = snapshot.data!;
    final allSelected = items.every((item) => item.isSelected);
    return Row(
    children: [
    Checkbox(
    value: allSelected,
    onChanged: (value) => _toggleSelectAll(value, items),
    activeColor: accentColor,
    ),
    Text(
    'Select All',
    style: TextStyle(color: Colors.white),
    ),
    SizedBox(width: 16),
    ],
    );
    },
    ),
    ],
    ),
      body: StreamBuilder<List<CartItem>>(
        stream: _cartStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final items = snapshot.data ?? [];

          if (items.isEmpty) {
            return _buildEmptyCart();
          }

          return _buildCartList(items);
        },
      ),
      bottomNavigationBar: _buildCheckoutBar(),
    );
  }

  // Empty cart UI
  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 100, color: Colors.grey),
          SizedBox(height: 24),
          Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton.icon(
            icon: Icon(Icons.add_shopping_cart),
            label: Text(
              'Browse Products',
              style: TextStyle(color: Colors.white),
            ),
            onPressed: () {
              // Replace Navigator.pop with Navigator.push to go to the Products page
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProductPage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              iconColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showQuantityDialog(CartItem item) {
    final TextEditingController controller = TextEditingController(text: item.quantity.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Quantity'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter quantity for ${item.product.name}'),
            SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(5), // Limit to 5 digits
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: Text('Update'),
            onPressed: () async {
              final newQuantity = int.tryParse(controller.text);
              if (newQuantity != null && newQuantity > 0) {
                await _cartService.updateQuantity(item.id!, newQuantity);
                Navigator.of(context).pop();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please enter a valid quantity')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _updateItemSelection(CartItem item, bool? value) async {
    if (value != null) {
      try {
        await _cartService.updateItem(item.id!, {'isSelected': value});
      } catch (e) {
        print('Error updating item selection: $e');
      }
    }
  }
  // Cart list UI
// In CartPage class, update only the relevant part of _buildCartList method
  Widget _buildCartList(List<CartItem> items) {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          margin: EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Checkbox for selection
                Checkbox(
                  value: item.isSelected,
                  onChanged: (bool? value) => _updateItemSelection(item, value),
                  activeColor: primaryColor,
                ),
                // Product Image
                if (item.product.imagePath != null)
                  Container(
                    width: 70,
                    height: 70,
                    margin: EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: FileImage(File(item.product.imagePath!)),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                // Product details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.product.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Size: ${item.variation.size}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      SizedBox(height: 4),
                      // Add Available Quantity display here
                      Text(
                        'Available Quantity: ${item.availableQuantity ?? "Not set"}',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Price: ₹${item.variation.price.toStringAsFixed(2)}',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          // Quantity adjustment
                          GestureDetector(
                            onTap: () => _showQuantityDialog(item),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.edit, size: 16, color: Colors.grey[600]),
                                  SizedBox(width: 4),
                                  Text(
                                    'Quantity: ${item.quantity}gm',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Spacer(),
                          // Remove button
                          IconButton(
                            icon: Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _removeFromCart(item),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  Widget _buildCheckoutBar() {
    return StreamBuilder<List<CartItem>>(
      stream: _cartStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox.shrink();
        }

        final items = snapshot.data!;
        final selectedItems = items.where((item) => item.isSelected).toList();
        final totalPrice = selectedItems.fold(
          0.0,
              (sum, item) => sum + item.totalPrice,
        );

        return Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total (${selectedItems.length} items):',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      '₹ ${totalPrice.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
                Spacer(),
                ElevatedButton(
                  onPressed: selectedItems.isNotEmpty ? _placeOrder : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text(
                    'Place Order',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  @override
  void dispose() {
    // No context-dependent operations here
    super.dispose();
  }
}

// Cart Manager (Singleton)
class CartManager {
  // Singleton instance
  static final CartManager _instance = CartManager._internal();
  static CartManager get instance => _instance;

  CartManager._internal();

  // List to store cart items
  List<CartItem> items = [];

  // Add item to cart
  void addItem(Product product, ProductVariation variation) {
    // Check if item already exists in cart
    final existingItemIndex = items.indexWhere(
          (item) =>
      item.product.id == product.id &&
          item.variation.size == variation.size,
    );

    if (existingItemIndex != -1) {
      // If item exists, increase quantity
      items[existingItemIndex].quantity++;
    } else {
      // Otherwise add new item
      items.add(CartItem(
        product: product,
        variation: variation,
      ));
    }
  }

  // Remove item from cart
  void removeItem(CartItem item) {
    items.remove(item);
  }

  // Clear cart
  void clearCart() {
    items.clear();
  }
}