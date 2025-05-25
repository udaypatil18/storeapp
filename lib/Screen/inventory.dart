import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mobistore/Screen/cart.dart';
import 'package:mobistore/utility/dealer.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

// Before taking/picking images
Future<void> requestPermissions() async {
  Map<Permission, PermissionStatus> statuses = await [
    Permission.camera,
    Permission.storage,
  ].request();

  if (statuses[Permission.camera]!.isDenied ||
      statuses[Permission.storage]!.isDenied) {
    SnackBar(
      content: Text("Please allow the camera permission of taking pictures!"),
    );
  }
}

// Product Status Enum
enum ProductStatus {
  inStock,
  lowStock,
  outOfStock,
}

// Product Variation Model
class ProductVariation {
  String size;
  int stock;
  double price;

  ProductStatus status;

  ProductVariation({
    required this.size,
    required this.stock,
    required this.price,
    required this.status,
  });

  // Method to update stock and recalculate status
  void updateStock(int newStock) {
    stock = newStock;

    if (stock == 0) {
      status = ProductStatus.outOfStock;
    } else if (stock <= 5) {
      status = ProductStatus.lowStock;
    } else {
      status = ProductStatus.inStock;
    }
  }
}

// Product Model
class Product {
  int id;
  String name;
  String? imagePath;
  String category;
  DateTime lastRestocked;
  List<ProductVariation> variations;

  Product({
    required this.id,
    required this.name,
    this.imagePath,
    required this.category,
    required this.lastRestocked,
    required this.variations,
  });

  // Get overall status based on variations
  ProductStatus getOverallStatus() {
    if (variations.every((v) => v.status == ProductStatus.outOfStock)) {
      return ProductStatus.outOfStock;
    } else if (variations.any((v) => v.status == ProductStatus.lowStock) ||
        variations.isEmpty) {
      return ProductStatus.lowStock;
    } else {
      return ProductStatus.inStock;
    }
  }

  // Get total stock across all variations
  int getTotalStock() {
    return variations.fold(0, (sum, variation) => sum + variation.stock);
  }
}

class ProductPage extends StatefulWidget {
  const ProductPage({Key? key}) : super(key: key);

  @override
  _ProductPageState createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  // Enhanced color palette
  final Color primaryColor = Color(0xFF006A4E); // Deep Teal
  final Color secondaryColor = Color(0xFF00876A); // Lighter Teal
  final Color accentColor = Color(0xFFFFA500); // Orange for alerts
  final Color backgroundColor = Color(0xFFF5F5F5); // Light background

  void _addToCart(Product product, ProductVariation variation) {
    CartManager.instance.addItem(product, variation);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} (${variation.size}) added to cart'),
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
  }

  // Image picker
  final ImagePicker _picker = ImagePicker();

  // Dealers list
  List<Dealer> dealersList = [];

  // Products list
  List<Product> products = [
    Product(
      id: 1,
      name: 'Black Pepper',
      category: 'Spices',
      lastRestocked: DateTime.now().subtract(Duration(days: 30)),
      variations: [
        ProductVariation(
          size: '100g',
          stock: 15,
          price: 30,
          status: ProductStatus.inStock,
        ),
        ProductVariation(
          size: '250g',
          stock: 10,
          price: 70,
          status: ProductStatus.inStock,
        ),
      ],
    ),
    Product(
      id: 2,
      name: 'Milton Bottle',
      category: 'Kitchenware',
      lastRestocked: DateTime.now().subtract(Duration(days: 60)),
      variations: [
        ProductVariation(
          size: '500ml',
          stock: 0,
          price: 200,
          status: ProductStatus.outOfStock,
        ),
        ProductVariation(
          size: '1L',
          stock: 0,
          price: 300,
          status: ProductStatus.outOfStock,
        ),
      ],
    ),
    Product(
      id: 3,
      name: 'Salt',
      category: 'Spices',
      lastRestocked: DateTime.now().subtract(Duration(days: 45)),
      variations: [
        ProductVariation(
          size: '500g',
          stock: 5,
          price: 20,
          status: ProductStatus.lowStock,
        ),
        ProductVariation(
          size: '1kg',
          stock: 15,
          price: 35,
          status: ProductStatus.inStock,
        ),
      ],
    ),
  ];

  // Search and filter controllers
  TextEditingController searchController = TextEditingController();
  String _searchQuery = '';
  ProductStatus? _filterStatus;

  @override
  void initState() {
    super.initState();
    // Initialize dealers list
    dealersList = getDealers();
  }

  // Take a picture with camera
  Future<void> _takePicture(Product product) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 90,
      );

      if (image != null) {
        setState(() {
          product.imagePath = image.path;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Product image updated')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to take picture: $e')),
      );
    }
  }

  // Pick image from gallery
  Future<void> _pickImage(Product product) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 90,
      );

      if (image != null) {
        setState(() {
          product.imagePath = image.path;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Product image updated')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  // Show image options dialog
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    icon: Icon(Icons.camera_alt),
                    label: Text('Camera'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _takePicture(product);
                    },
                  ),
                  ElevatedButton.icon(
                    icon: Icon(Icons.photo_library),
                    label: Text('Gallery'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _pickImage(product);
                    },
                  ),
                ],
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

  // Filter products method
  List<Product> _filterProducts() {
    return products.where((product) {
      final matchesSearch =
          product.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesStatus =
          _filterStatus == null || product.getOverallStatus() == _filterStatus;
      return matchesSearch && matchesStatus;
    }).toList();
  }

  // Edit Variation Stock Dialog
  void _showEditVariationStockDialog(
      Product product, ProductVariation variation) {
    final stockController =
        TextEditingController(text: variation.stock.toString());

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit Stock for ${product.name} (${variation.size})'),
          content: TextField(
            controller: stockController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'New Stock Quantity',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: Text('Update'),
              onPressed: () {
                final newStock = int.tryParse(stockController.text);
                if (newStock != null && newStock >= 0) {
                  setState(() {
                    variation.updateStock(newStock);
                    product.lastRestocked = DateTime.now();
                  });
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Stock updated successfully')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Please enter a valid stock quantity')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  // Add New Variation Dialog
  void _showAddVariationDialog(Product product) {
    final sizeController = TextEditingController();
    final stockController = TextEditingController();
    final priceController = TextEditingController();
    final reorderPointController = TextEditingController();

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
              onPressed: () {
                // Validate inputs
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

                // Determine initial status
                ProductStatus initialStatus;
                if (newStock == 0) {
                  initialStatus = ProductStatus.outOfStock;
                } else {
                  initialStatus = ProductStatus.inStock;
                }

                // Add new variation
                setState(() {
                  product.variations.add(ProductVariation(
                    size: sizeController.text,
                    stock: newStock,
                    price: newPrice,
                    status: initialStatus,
                  ));
                  product.lastRestocked = DateTime.now();
                });

                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Variation added successfully')),
                );
              },
            ),
          ],
        );
      },
    );
  }

  // Add New Product Dialog with Camera Option
  void _showAddProductDialog() {
    final nameController = TextEditingController();
    final categoryController = TextEditingController();
    String? tempImagePath;

    // Function to take a picture
    Future<void> _captureImage() async {
      try {
        final XFile? image = await _picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 800,
          maxHeight: 800,
          imageQuality: 90,
        );

        if (image != null) {
          setState(() {
            tempImagePath = image.path;
          });
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to take picture: $e')),
        );
      }
    }

    // Function to pick image from gallery
    Future<void> _pickImageFromGallery() async {
      try {
        final XFile? image = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 800,
          maxHeight: 800,
          imageQuality: 90,
        );

        if (image != null) {
          setState(() {
            tempImagePath = image.path;
          });
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }

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
                    // Image Preview or Capture Button
                    Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: tempImagePath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(tempImagePath!),
                                fit: BoxFit.cover,
                              ),
                            )
                          : Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.image,
                                      size: 50, color: Colors.grey),
                                  Text('No Image Selected'),
                                ],
                              ),
                            ),
                    ),
                    SizedBox(height: 10),

                    // Image Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          icon: Icon(Icons.camera_alt),
                          label: Text('Camera'),
                          onPressed: () async {
                            await _captureImage();
                            setDialogState(() {});
                          },
                        ),
                        ElevatedButton.icon(
                          icon: Icon(Icons.photo_library),
                          label: Text('Gallery'),
                          onPressed: () async {
                            await _pickImageFromGallery();
                            setDialogState(() {});
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 20),

                    // Product Name
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Product Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 10),

                    // Category
                    TextField(
                      controller: categoryController,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 10),

                    // Note about variations
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber),
                      ),
                      child: Text(
                        'You will be able to add product variations (sizes, weights) after creating the product.',
                        style: TextStyle(fontSize: 12),
                      ),
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
                  child: Text('Add Product'),
                  onPressed: () {
                    // Validate inputs
                    if (nameController.text.isEmpty ||
                        categoryController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Please fill all fields')),
                      );
                      return;
                    }

                    // Add new product
                    final newProduct = Product(
                      id: products.length + 1,
                      name: nameController.text,
                      imagePath: tempImagePath,
                      category: categoryController.text,
                      lastRestocked: DateTime.now(),
                      variations: [],
                    );

                    setState(() {
                      products.add(newProduct);
                    });

                    Navigator.of(context).pop();

                    // Show add variation dialog
                    _showAddVariationDialog(newProduct);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Show dealer order dialog for a specific variation
  void _showDealerOrderDialog(Product product, ProductVariation variation) {
    final quantityController = TextEditingController();
    Dealer? selectedDealer;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Order ${product.name} (${variation.size})'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Dealer Selection
                DropdownButtonFormField<Dealer>(
                  value: selectedDealer,
                  decoration: InputDecoration(
                    labelText: 'Select Dealer',
                    border: OutlineInputBorder(),
                  ),
                  items: dealersList.map((dealer) {
                    return DropdownMenuItem<Dealer>(
                      value: dealer,
                      child: Text(
                        '${dealer.name} (${dealer.location})',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (dealer) {
                    setState(() {
                      selectedDealer = dealer;
                    });
                  },
                ),
                SizedBox(height: 16),

                // Quantity Input
                TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Quantity',
                    border: OutlineInputBorder(),
                  ),
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
              child: Text('Place Order'),
              onPressed: () {
                // Validate inputs
                if (selectedDealer == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please select a dealer')),
                  );
                  return;
                }

                final quantity = int.tryParse(quantityController.text);
                if (quantity == null || quantity <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please enter a valid quantity')),
                  );
                  return;
                }

                // Update product stock
                setState(() {
                  variation.updateStock(variation.stock + quantity);
                  product.lastRestocked = DateTime.now();
                });

                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Order placed with ${selectedDealer!.name}'),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  // Delete Variation Dialog
  void _deleteVariation(Product product, ProductVariation variation) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Variation'),
          content: Text(
              'Are you sure you want to delete ${variation.size} variation from ${product.name}?'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Delete'),
              onPressed: () {
                setState(() {
                  product.variations.remove(variation);
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Variation deleted successfully')),
                );
              },
            ),
          ],
        );
      },
    );
  }

  // Delete Product Method
  void _deleteProduct(Product product) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Product'),
          content: Text(
              'Are you sure you want to delete ${product.name} with all its variations?'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Delete'),
              onPressed: () {
                setState(() {
                  products.remove(product);
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Product deleted successfully')),
                );
              },
            ),
          ],
        );
      },
    );
  }

  // Filter Dialog
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

  // View variations dialog
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
                // Header
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      // Product image if available
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

                      // Product details
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

                      // Add variation button
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

                // Variations list
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

// Extract empty variations view to a separate method
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

// Extract variations list view to a separate method
  Widget _buildVariationsListView(
      Product product, ScrollController scrollController) {
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

// Extract variation card to a separate method
  Widget _buildVariationCard(
      Product product, ProductVariation variation, BuildContext context) {
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
            // Variation details
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

            // Action buttons
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

// Helper method to get status color
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

// Helper method to build status badge
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

// Create a combined edit dialog for both stock and price
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
            onPressed: () {
              // Validate inputs
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

              // Save changes to database
              // _productDatabase.updateProduct(product);

              // Show success message
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

// This is the previous stock-only edit dialog that we're replacing
// Keep for reference or delete if no longer needed

  // Get status label
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

  @override
  Widget build(BuildContext context) {
    // Filter products based on search query and status filter
    final filteredProducts = _filterProducts();

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
          // Search Bar
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

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Filter status indicator
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

          // Product List
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
                                // Product Image
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
                                              image: FileImage(
                                                  File(product.imagePath!)),
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

                                // Product Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                                _showImageOptionsDialog(
                                                    product);
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
                                              color:
                                                  statusColor.withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                  color: statusColor),
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
                                                color: accentColor
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                    color: accentColor),
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
