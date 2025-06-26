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

  factory ProductVariation.fromFirestore(Map<String, dynamic> data) {
    return ProductVariation(
      size: data['size'] ?? '',
      stock: data['stock'] ?? 0,
      price: (data['price'] ?? 0).toDouble(),
      status: ProductStatus.values.firstWhere(
            (e) => e.toString() == data['status'],
        orElse: () => ProductStatus.outOfStock,
      ),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'size': size,
      'stock': stock,
      'price': price,
      'status': status.toString(),
    };
  }

  factory ProductVariation.fromMap(Map<String, dynamic> map) =>
      ProductVariation.fromFirestore(map);

  Map<String, dynamic> toMap() => toFirestore();
}

class Product {
  String? id;
  String name;
  String? imagePath; // 📁 Local storage path (for caching or UI display)
  String? imageUrl;  // 🌐 Firebase Storage URL
  String category;
  DateTime lastRestocked;
  List<ProductVariation> variations;

  Product({
    this.id,
    required this.name,
    this.imagePath,
    this.imageUrl,
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
      imageUrl: data['imageUrl'],
      category: data['category'] ?? '',
      lastRestocked: (data['lastRestocked'] as Timestamp?)?.toDate() ?? DateTime.now(),
      variations: (data['variations'] as List<dynamic>?)
          ?.map((v) => ProductVariation.fromFirestore(v as Map<String, dynamic>))
          .toList() ??
          [],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'imagePath': imagePath, // Optional: store only if needed locally
      'imageUrl': imageUrl,   // ✅ Main reference for Firebase Storage
      'category': category,
      'lastRestocked': Timestamp.fromDate(lastRestocked),
      'variations': variations.map((v) => v.toFirestore()).toList(),
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) =>
      Product.fromFirestore(map);

  Map<String, dynamic> toMap() => toFirestore();
}
