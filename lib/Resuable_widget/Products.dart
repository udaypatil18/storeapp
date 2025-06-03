import 'package:cloud_firestore/cloud_firestore.dart';

enum ProductStatus {
  inStock,
  lowStock,
  outOfStock,
}

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

  // Add updateStock method
  void updateStock(int newStock) {
    stock = newStock;
    // Update status based on new stock level
    if (newStock <= 0) {
      status = ProductStatus.outOfStock;
    } else if (newStock <= 5) {
      status = ProductStatus.lowStock;
    } else {
      status = ProductStatus.inStock;
    }
  }

  // Add fromMap constructor for Firestore
  factory ProductVariation.fromMap(Map<String, dynamic> map) {
    return ProductVariation(
      size: map['size'] ?? '',
      stock: map['stock'] ?? 0,
      price: (map['price'] ?? 0.0).toDouble(),
      status: ProductStatus.values.firstWhere(
            (e) => e.toString() == map['status'],
        orElse: () => ProductStatus.outOfStock,
      ),
    );
  }

  // Add toMap method for Firestore
  Map<String, dynamic> toMap() {
    return {
      'size': size,
      'stock': stock,
      'price': price,
      'status': status.toString(),
    };
  }
}

class Product {
  String? id; // Change from int to String? for Firestore document ID
  String name;
  String? imagePath;
  String category;
  DateTime lastRestocked;
  List<ProductVariation> variations;

  Product({
    this.id,
    required this.name,
    this.imagePath,
    required this.category,
    required this.lastRestocked,
    required this.variations,
  });

  // Add getOverallStatus method
  ProductStatus getOverallStatus() {
    if (variations.isEmpty || variations.every((v) => v.status == ProductStatus.outOfStock)) {
      return ProductStatus.outOfStock;
    } else if (variations.any((v) => v.status == ProductStatus.lowStock)) {
      return ProductStatus.lowStock;
    } else {
      return ProductStatus.inStock;
    }
  }

  // Add getTotalStock method
  int getTotalStock() {
    return variations.fold(0, (sum, variation) => sum + variation.stock);
  }

  // Add fromFirestore constructor
  factory Product.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      name: data['name'] ?? '',
      imagePath: data['imagePath'],
      category: data['category'] ?? '',
      lastRestocked: (data['lastRestocked'] as Timestamp).toDate(),
      variations: (data['variations'] as List<dynamic>?)
          ?.map((v) => ProductVariation.fromMap(v as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  // Add toMap method for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'imagePath': imagePath,
      'category': category,
      'lastRestocked': Timestamp.fromDate(lastRestocked),
      'variations': variations.map((v) => v.toMap()).toList(),
    };
  }
}