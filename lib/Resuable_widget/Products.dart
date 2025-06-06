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

  void updateStock(int newStock) {
    stock = newStock;
    if (newStock <= 0) {
      status = ProductStatus.outOfStock;
    } else if (newStock <= 5) {
      status = ProductStatus.lowStock;
    } else {
      status = ProductStatus.inStock;
    }
  }

  // Update the method name to fromFirestore and handle the data conversion
  factory ProductVariation.fromFirestore(Map<String, dynamic> data) {
    return ProductVariation(
      size: data['size'] ?? '',
      stock: data['stock'] ?? 0,
      price: (data['price'] ?? 0.0).toDouble(),
      status: ProductStatus.values.firstWhere(
            (e) => e.toString() == data['status'],
        orElse: () => ProductStatus.outOfStock,
      ),
    );
  }

  // Update the method name to toFirestore
  Map<String, dynamic> toFirestore() {
    return {
      'size': size,
      'stock': stock,
      'price': price,
      'status': status.toString(),
    };
  }

  // Keep the old methods for backwards compatibility
  factory ProductVariation.fromMap(Map<String, dynamic> map) =>
      ProductVariation.fromFirestore(map);

  Map<String, dynamic> toMap() => toFirestore();
}

class Product {
  String? id;
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

  ProductStatus getOverallStatus() {
    if (variations.isEmpty || variations.every((v) => v.status == ProductStatus.outOfStock)) {
      return ProductStatus.outOfStock;
    } else if (variations.any((v) => v.status == ProductStatus.lowStock)) {
      return ProductStatus.lowStock;
    } else {
      return ProductStatus.inStock;
    }
  }

  int getTotalStock() {
    return variations.fold(0, (sum, variation) => sum + variation.stock);
  }

  // Update to handle both DocumentSnapshot and Map
  factory Product.fromFirestore(dynamic source) {
    Map<String, dynamic> data;
    String? documentId;

    if (source is DocumentSnapshot) {
      data = source.data() as Map<String, dynamic>;
      documentId = source.id;
    } else if (source is Map<String, dynamic>) {
      data = source;
      documentId = data['id'] as String?;
    } else {
      throw ArgumentError('Invalid source type for Product.fromFirestore');
    }

    return Product(
      id: documentId,
      name: data['name'] ?? '',
      imagePath: data['imagePath'],
      category: data['category'] ?? '',
      lastRestocked: (data['lastRestocked'] as Timestamp?)?.toDate() ?? DateTime.now(),
      variations: (data['variations'] as List<dynamic>?)
          ?.map((v) => ProductVariation.fromFirestore(v as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  // Update method name to toFirestore and keep the same implementation
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'imagePath': imagePath,
      'category': category,
      'lastRestocked': Timestamp.fromDate(lastRestocked),
      'variations': variations.map((v) => v.toFirestore()).toList(),
    };
  }

  // Keep the old methods for backwards compatibility
  factory Product.fromMap(Map<String, dynamic> map) =>
      Product.fromFirestore(map);

  Map<String, dynamic> toMap() => toFirestore();
}