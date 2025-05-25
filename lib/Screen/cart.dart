import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:io';

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

class CartItem {
  final Product product;
  final ProductVariation variation;
  int quantity;
  bool isSelected;

  CartItem({
    required this.product,
    required this.variation,
    this.quantity = 1,
    this.isSelected = true,
  });

  double get totalPrice => variation.price * quantity;
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

  // Store ScaffoldMessengerState reference for safe access
  late ScaffoldMessengerState _scaffoldMessenger;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Safely store reference to scaffold messenger
    _scaffoldMessenger = ScaffoldMessenger.of(context);
  }

  @override
  void initState() {
    super.initState();
    // Initialize dealers list
    dealersList = getDealers();
  }

  // Toggle selection of all items
  void _toggleSelectAll(bool? value) {
    setState(() {
      for (var item in CartManager.instance.items) {
        item.isSelected = value ?? false;
      }
    });
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
  void _removeFromCart(CartItem item) {
    setState(() {
      CartManager.instance.removeItem(item);
    });

    _scaffoldMessenger.showSnackBar(
      SnackBar(content: Text('Removed from cart')),
    );
  }

  // Increase quantity of an item
  void _increaseQuantity(CartItem item) {
    setState(() {
      item.quantity++;
    });
  }

  // Decrease quantity of an item
  void _decreaseQuantity(CartItem item) {
    if (item.quantity > 1) {
      setState(() {
        item.quantity--;
      });
    }
  }

  // Update quantity directly
  void _updateQuantity(CartItem item, String value) {
    final newQuantity = int.tryParse(value);
    if (newQuantity != null && newQuantity > 0) {
      setState(() {
        item.quantity = newQuantity;
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

  // Place order for selected items
  void _placeOrder() {
    if (_countSelectedItems() == 0) {
      _scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Please select items to place order')),
      );
      return;
    }

    if (selectedDealer == null) {
      _showDealerSelectionDialog();
      return;
    }

    final selectedItems =
        CartManager.instance.items.where((item) => item.isSelected).toList();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Confirm Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dealer: ${selectedDealer!.name}'),
            SizedBox(height: 8),
            Text(
              'Total: ₹${_calculateTotalSelectedPrice().toStringAsFixed(2)}',
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
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          TextButton(
            child: Text('Place Order'),
            onPressed: () {
              // Use dialogContext to pop the dialog
              Navigator.of(dialogContext).pop();
              _processPurchaseOrder();
            },
          ),
        ],
      ),
    );
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
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Select Dealer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...dealersList.map((dealer) => RadioListTile<Dealer>(
                  title: Text(dealer.name),
                  subtitle: Text(dealer.location),
                  value: dealer,
                  groupValue: selectedDealer,
                  onChanged: (Dealer? value) {
                    // Use dialogContext to pop the dialog
                    Navigator.of(dialogContext).pop();

                    // Update state if still mounted
                    if (mounted) {
                      setState(() {
                        selectedDealer = value;
                      });

                      // Place order after selection if mounted
                      _placeOrder();
                    }
                  },
                )),
          ],
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
          if (CartManager.instance.items.isNotEmpty)
            Row(
              children: [
                Checkbox(
                  value: _areAllItemsSelected(),
                  onChanged: _toggleSelectAll,
                  activeColor: accentColor,
                ),
                Text(
                  'Select All',
                  style: TextStyle(color: Colors.white),
                ),
                SizedBox(width: 16),
              ],
            ),
        ],
      ),
      body: CartManager.instance.items.isEmpty
          ? _buildEmptyCart()
          : _buildCartList(),
      bottomNavigationBar:
          CartManager.instance.items.isEmpty ? null : _buildCheckoutBar(),
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
              Navigator.of(context).pop();
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

  // Cart list UI
  Widget _buildCartList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: CartManager.instance.items.length,
      itemBuilder: (context, index) {
        final item = CartManager.instance.items[index];
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
                  onChanged: (bool? value) {
                    setState(() {
                      item.isSelected = value ?? false;
                    });
                  },
                  activeColor: primaryColor,
                ),
                // Product Image
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                    image: item.product.imagePath != null
                        ? DecorationImage(
                            image: FileImage(File(item.product.imagePath!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: item.product.imagePath == null
                      ? Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.grey[400],
                        )
                      : null,
                ),
                SizedBox(width: 16),
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
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Price: ₹${item.variation.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          // Quantity adjustment
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                InkWell(
                                  onTap: () => _decreaseQuantity(item),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    child: Icon(Icons.remove, size: 16),
                                  ),
                                ),
                                Container(
                                  width: 40,
                                  padding: EdgeInsets.symmetric(horizontal: 4),
                                  child: TextField(
                                    textAlign: TextAlign.center,
                                    keyboardType: TextInputType.number,
                                    controller: TextEditingController(
                                        text: item.quantity.toString()),
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    onChanged: (value) =>
                                        _updateQuantity(item, value),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => _increaseQuantity(item),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    child: Icon(Icons.add, size: 16),
                                  ),
                                ),
                              ],
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

  // Checkout bar UI
  Widget _buildCheckoutBar() {
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
                  'Total (${_countSelectedItems()} items):',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  '₹ ${_calculateTotalSelectedPrice().toStringAsFixed(2)}',
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
              onPressed: _placeOrder,
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
