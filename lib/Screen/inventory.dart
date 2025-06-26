import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mobistore/Screen/cart.dart';
import 'package:mobistore/home.dart';
import 'package:mobistore/utility/dealer.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../Resuable_widget/Products.dart';
import '../firebase_services/cart_services.dart';
import '../firebase_services/firebase_service.dart';
import '../firebase_services/image_storage.dart';
import '../providers/cart_provider.dart';
import '../providers/product_provider.dart';

class ProductPage extends StatefulWidget {
  const ProductPage({Key? key}) : super(key: key);

  @override
  _ProductPageState createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final ImagePicker _picker = ImagePicker();
  final Color primaryColor = Color(0xFF006A4E);
  final Color secondaryColor = Color(0xFF00876A);
  final Color accentColor = Color(0xFFFFA500);
  final Color backgroundColor = Color(0xFFF5F5F5);

  String? tempImagePath;
  String? tempImageUrl;
  List<Dealer> dealersList = [];
  TextEditingController searchController = TextEditingController();
  String _searchQuery = '';
  ProductStatus? _filterStatus;

  @override
  void initState() {
    super.initState();
    // Use Future.delayed to ensure context is available
    Future.delayed(Duration.zero, () async {
      final provider = Provider.of<ProductProvider>(context, listen: false);
      // Avoid double-loading by only loading if needed
      if (provider.products.isEmpty) {
        await provider.loadProducts();
      }
      setState(() {}); // Ensure UI updates after load
    });
  }

  Future<void> _addNewProduct(BuildContext context, Product product) async {
    final provider = Provider.of<ProductProvider>(context, listen: false);
    try {
      await provider.addProduct(product);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding product: $e')),
        );
      }
    }
  }

  Future<void> _updateProduct(BuildContext context, Product product) async {
    if (product.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Product ID is missing')),
      );
      return;
    }
    final provider = Provider.of<ProductProvider>(context, listen: false);
    try {
      await provider.updateProduct(product);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating product: $e')),
        );
      }
    }
  }

  Future<void> _addToCart(Product product, ProductVariation variation) async {
    try {
      final int? availableQuantity = await showDialog<int>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          final TextEditingController quantityController = TextEditingController();

          return AlertDialog(
            title: Text('Enter Available Quantity'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Product: ${product.name}', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Size: ${variation.size}'),
                SizedBox(height: 16),
                TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Available Quantity',
                    border: OutlineInputBorder(),
                    helperText: 'Enter the quantity available for this item',
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(null),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final text = quantityController.text;
                  if (text.isEmpty || int.tryParse(text) == null || int.parse(text) <= 0) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text('Please enter a valid quantity')),
                    );
                    return;
                  }
                  Navigator.of(dialogContext).pop(int.parse(text));
                },
                child: Text('Add to Cart'),
              ),
            ],
          );
        },
      );

      if (availableQuantity == null) return;

      final cartService = CartService();
      final cartItem = CartItem(
        product: product,
        variation: variation,
        availableQuantity: availableQuantity,
      );

      await cartService.addItem(cartItem);
      context.read<CartManager>().addItem(product, variation);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} (${variation.size}) - $availableQuantity available'),
          action: SnackBarAction(
            label: 'VIEW CART',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CartPage()),
              );
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add to cart: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Optimized: Use async/await and remove setState from image picking, use ValueNotifier for dialog reactivity
  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        tempImagePath = image.path;
        setState(() {}); // Only update if image picked
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  void _showImageOptionsDialog(Product product) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Product Image'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (product.imagePath != null)
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: FileImage(File(product.imagePath!)),
                      fit: BoxFit.cover,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              SizedBox(height: 20),
              ElevatedButton.icon(
                icon: Icon(Icons.photo_library),
                label: Text('Select from Gallery'),
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _pickImageFromGallery();
                  setState(() {
                    product.imagePath = tempImagePath;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Product image updated successfully')),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Close'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  List<Product> _filterProducts(ProductProvider provider) {
    return provider.products.where((product) {
      final matchesSearch = product.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesStatus = _filterStatus == null || product.getOverallStatus() == _filterStatus;
      return matchesSearch && matchesStatus;
    }).toList();
  }

  void _showAddVariationDialog(Product product) {
    final sizeController = TextEditingController();
    final stockController = TextEditingController();
    final priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Add New Variation for ${product.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: sizeController,
                  decoration: InputDecoration(
                    labelText: 'Size/Weight (e.g., 250g, 1kg)',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: stockController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Stock',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Price',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 10),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: Text('Add Variation'),
              onPressed: () async {
                if (sizeController.text.isEmpty ||
                    stockController.text.isEmpty ||
                    priceController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please fill all fields')),
                  );
                  return;
                }

                final newStock = int.parse(stockController.text);
                final newPrice = double.parse(priceController.text);

                ProductStatus initialStatus = newStock == 0
                    ? ProductStatus.outOfStock
                    : ProductStatus.inStock;

                try {
                  product.variations.add(ProductVariation(
                    size: sizeController.text,
                    stock: newStock,
                    price: newPrice,
                    status: initialStatus,
                  ));
                  product.lastRestocked = DateTime.now();

                  final provider = Provider.of<ProductProvider>(context, listen: false);
                  await provider.updateProduct(product);

                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Variation added successfully')),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error adding variation: $e')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showEditVariationDialog(Product product, ProductVariation variation) {
    final TextEditingController stockController =
    TextEditingController(text: variation.stock.toString());
    final TextEditingController priceController =
    TextEditingController(text: variation.price.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${variation.size} Variation'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: stockController,
                decoration: InputDecoration(
                  labelText: 'Stock Quantity',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              SizedBox(height: 16),
              TextField(
                controller: priceController,
                decoration: InputDecoration(
                  labelText: 'Price (₹)',
                  border: OutlineInputBorder(),
                  prefixText: '₹',
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            child: Text('Save Changes'),
            onPressed: () async {
              int? newStock = int.tryParse(stockController.text);
              double? newPrice = double.tryParse(priceController.text);

              if (newStock == null || newPrice == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please enter valid values')),
                );
                return;
              }

              // Update variation
              setState(() {
                variation.stock = newStock;
                variation.price = newPrice;
                // Update status based on new stock level
                if (newStock <= 0) {
                  variation.status = ProductStatus.outOfStock;
                } else if (newStock <= 5) {
                  variation.status = ProductStatus.lowStock;
                } else {
                  variation.status = ProductStatus.inStock;
                }
              });

              // Save changes to provider/database
              final provider = Provider.of<ProductProvider>(context, listen: false);
              await provider.updateProduct(product);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Variation updated successfully')),
              );

              Navigator.of(context).pop();
              _viewProductVariations(product); // Refresh the variations view
            },
          ),
        ],
      ),
    );
  }

  void _deleteVariation(Product product, ProductVariation variation) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Variation'),
          content: Text(
            'Are you sure you want to delete ${variation.size} variation from ${product.name}?',
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Delete'),
              onPressed: () async {
                try {
                  product.variations.remove(variation);

                  final provider = Provider.of<ProductProvider>(context, listen: false);
                  await provider.updateProduct(product);

                  Navigator.of(context).pop();

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Variation deleted successfully')),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting variation: $e')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _deleteProduct(Product product) {
    if (product.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: Product ID is missing')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Product'),
          content: Text('Are you sure you want to delete ${product.name} with all its variations?'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Delete'),
              onPressed: () async {
                Navigator.of(context).pop();

                try {
                  final provider = Provider.of<ProductProvider>(context, listen: false);
                  await provider.deleteProduct(product);

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Product deleted successfully')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error deleting product: $e')),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Filter Products'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ProductStatus?>(
              title: Text('All Products'),
              value: null,
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() {
                  _filterStatus = value;
                });
                Navigator.of(context).pop();
              },
            ),
            RadioListTile<ProductStatus>(
              title: Text('In Stock'),
              value: ProductStatus.inStock,
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() {
                  _filterStatus = value;
                });
                Navigator.of(context).pop();
              },
            ),
            RadioListTile<ProductStatus>(
              title: Text('Low Stock'),
              value: ProductStatus.lowStock,
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() {
                  _filterStatus = value;
                });
                Navigator.of(context).pop();
              },
            ),
            RadioListTile<ProductStatus>(
              title: Text('Out of Stock'),
              value: ProductStatus.outOfStock,
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() {
                  _filterStatus = value;
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _viewProductVariations(Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (_, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      if (product.imagePath != null)
                        Container(
                          width: 60,
                          height: 60,
                          margin: EdgeInsets.only(right: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: FileImage(File(product.imagePath!)),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Category: ${product.category}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.add_circle, color: Colors.white),
                        tooltip: 'Add Variation',
                        onPressed: () {
                          Navigator.of(context).pop();
                          _showAddVariationDialog(product);
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: product.variations.isEmpty
                      ? _buildEmptyVariationsView(product, context)
                      : _buildVariationsListView(product, scrollController),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyVariationsView(Product product, BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No variations yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton.icon(
            icon: Icon(Icons.add),
            label: Text('Add Variation'),
            onPressed: () {
              Navigator.of(context).pop();
              _showAddVariationDialog(product);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVariationsListView(Product product, ScrollController scrollController) {
    return ListView.builder(
      controller: scrollController,
      padding: EdgeInsets.all(16),
      itemCount: product.variations.length,
      itemBuilder: (context, index) {
        final variation = product.variations[index];
        return _buildVariationCard(product, variation, context);
      },
    );
  }

  Widget _buildVariationCard(Product product, ProductVariation variation, BuildContext context) {
    Color statusColor = _getStatusColor(variation.status);

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: secondaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          variation.size,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      _buildStatusBadge(variation.status, statusColor),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Price: ₹${variation.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 16),
                      Text(
                        'Stock: ${variation.stock} units',
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  icon: Icon(Icons.edit, color: primaryColor),
                  tooltip: 'Edit Variation',
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showEditVariationDialog(product, variation);
                  },
                ),
                IconButton(
                  icon: Icon(Icons.add_shopping_cart, color: secondaryColor),
                  tooltip: 'Add to Cart',
                  onPressed: () {
                    Navigator.of(context).pop();
                    _addToCart(product, variation);
                  },
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Delete Variation',
                  onPressed: () {
                    Navigator.of(context).pop();
                    _deleteVariation(product, variation);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(ProductStatus status) {
    switch (status) {
      case ProductStatus.inStock:
        return Colors.green;
      case ProductStatus.lowStock:
        return Colors.orange;
      case ProductStatus.outOfStock:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildStatusBadge(ProductStatus status, Color statusColor) {
    String statusText = status == ProductStatus.inStock
        ? 'In Stock'
        : status == ProductStatus.lowStock
        ? 'Low Stock'
        : 'Out of Stock';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          color: statusColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _getStatusLabel(ProductStatus status) {
    switch (status) {
      case ProductStatus.inStock:
        return 'In Stock';
      case ProductStatus.lowStock:
        return 'Low Stock';
      case ProductStatus.outOfStock:
        return 'Out of Stock';
      default:
        return 'Unknown';
    }
  }

  // Optimized add product dialog: Use ValueNotifier for image reactivity
  // ... (imports and class declaration remain unchanged)

  // ... (imports and class declaration remain unchanged)

  void _showAddProductDialog() {
    final nameController = TextEditingController();
    final categoryController = TextEditingController();
    final ValueNotifier<String?> dialogImagePath = ValueNotifier<String?>(tempImagePath);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Add New Product'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ValueListenableBuilder<String?>(
                      valueListenable: dialogImagePath,
                      builder: (context, imagePath, _) {
                        return Container(
                          height: 150,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: imagePath != null
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(imagePath),
                              fit: BoxFit.cover,
                            ),
                          )
                              : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.image, size: 50, color: Colors.grey),
                                Text('No Image Selected'),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: Icon(Icons.photo_library),
                      label: Text('Select from Gallery'),
                      onPressed: () async {
                        final XFile? image = await _picker.pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 800,
                          maxHeight: 800,
                          imageQuality: 85,
                        );
                        if (image != null) {
                          dialogImagePath.value = image.path;
                        }
                      },
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Product Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: categoryController,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () {
                    setState(() {
                      tempImagePath = null;
                      tempImageUrl = null;
                    });
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton(
                  child: Text('Save'),
                  onPressed: () async {
                    if (nameController.text.isEmpty || categoryController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Please fill in all fields')),
                      );
                      return;
                    }

                    String? imageUrl;
                    final pickedPath = dialogImagePath.value;
                    if (pickedPath != null) {
                      final result = await ImageStorage.uploadImageWithUrl(pickedPath);
                      if (result != null) {
                        imageUrl = result['downloadUrl'];
                      }
                    }

                    final newProduct = Product(
                      name: nameController.text,
                      category: categoryController.text,
                      imagePath: pickedPath,
                      imageUrl: imageUrl,
                      variations: [],
                      lastRestocked: DateTime.now(),
                    );

                    final provider = Provider.of<ProductProvider>(context, listen: false);
                    try {
                      await provider.addProduct(newProduct);

                      setState(() {
                        tempImagePath = null;
                        tempImageUrl = null;
                      });

                      Navigator.of(context).pop(); // Close add product dialog

                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(content: Text('Product added successfully')),
                      );

                      // Post-frame callback to open add variation dialog after the dialog is closed
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        Product? addedProduct;
                        try {
                          addedProduct = provider.products.firstWhere(
                                (p) =>
                            p.name == newProduct.name &&
                                p.category == newProduct.category &&
                                (p.imageUrl == newProduct.imageUrl ||
                                    (p.imageUrl == null && newProduct.imageUrl == null)),
                          );
                        } catch (e) {
                          addedProduct = null;
                        }
                        if (addedProduct != null) {
                          _showAddVariationDialog(addedProduct);
                        }
                      });
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error adding product: $e')),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

// ... (rest of the file unchanged)

// ... (rest of the file unchanged)

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ProductProvider>(context);
    final filteredProducts = _filterProducts(provider);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Product Inventory',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: primaryColor,
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            color: Colors.white,
          ),
          IconButton(
            icon: Icon(Icons.shopping_cart),
            color: Colors.white,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CartPage()),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddProductDialog,
        backgroundColor: accentColor,
        child: Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search products',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (_filterStatus != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Chip(
                      label: Text(
                        'Filtered: ${_getStatusLabel(_filterStatus!)}',
                        style: TextStyle(color: Colors.white),
                      ),
                      backgroundColor: _getStatusColor(_filterStatus!),
                      deleteIcon: Icon(Icons.close, color: Colors.white),
                      onDeleted: () {
                        setState(() {
                          _filterStatus = null;
                        });
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: filteredProducts.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 100,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 24),
                  Text(
                    'No products found',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 8),
                  if (_searchQuery.isNotEmpty || _filterStatus != null)
                    TextButton.icon(
                      icon: Icon(Icons.refresh),
                      label: Text('Clear filters'),
                      onPressed: () {
                        setState(() {
                          searchController.clear();
                          _searchQuery = '';
                          _filterStatus = null;
                        });
                      },
                    )
                  else
                    TextButton.icon(
                      icon: Icon(Icons.add),
                      label: Text('Add your first product'),
                      onPressed: _showAddProductDialog,
                    ),
                ],
              ),
            )
                : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: filteredProducts.length,
              itemBuilder: (context, index) {
                final product = filteredProducts[index];
                final status = product.getOverallStatus();
                final totalStock = product.getTotalStock();
                final statusColor = _getStatusColor(status);

                return Card(
                  margin: EdgeInsets.only(bottom: 16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: () => _viewProductVariations(product),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () => _showImageOptionsDialog(product),
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                                image: product.imagePath != null
                                    ? DecorationImage(
                                  image: FileImage(File(product.imagePath!)),
                                  fit: BoxFit.cover,
                                )
                                    : null,
                              ),
                              child: product.imagePath == null
                                  ? Icon(
                                Icons.camera_alt,
                                color: Colors.grey[400],
                              )
                                  : null,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        product.name,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    PopupMenuButton(
                                      icon: Icon(Icons.more_vert),
                                      onSelected: (value) {
                                        if (value == 'edit') {
                                          _showImageOptionsDialog(product);
                                        } else if (value == 'delete') {
                                          _deleteProduct(product);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit, size: 18),
                                              SizedBox(width: 8),
                                              Text('Edit Image'),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete,
                                                  size: 18,
                                                  color: Colors.red),
                                              SizedBox(width: 8),
                                              Text('Delete Product',
                                                  style: TextStyle(
                                                      color: Colors.red)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Category: ${product.category}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                  ),
                                ),
                                SizedBox(height: 8),
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: statusColor),
                                      ),
                                      child: Text(
                                        _getStatusLabel(status),
                                        style: TextStyle(
                                          color: statusColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Stock: $totalStock units',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Last Restocked: ${DateFormat('MMM dd, yyyy').format(product.lastRestocked)}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                                SizedBox(height: 8),
                                product.variations.isNotEmpty
                                    ? Row(
                                  children: [
                                    Icon(
                                      Icons.list,
                                      size: 14,
                                      color: Colors.grey[600],
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      '${product.variations.length} variations',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                    Spacer(),
                                    Text(
                                      'View Details',
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      size: 12,
                                      color: primaryColor,
                                    ),
                                  ],
                                )
                                    : Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: accentColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: accentColor),
                                  ),
                                  child: Text(
                                    'No variations - Add now',
                                    style: TextStyle(
                                      color: accentColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}