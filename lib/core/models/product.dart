class Product {
  final String id;
  final String name;
  final String? description;
  final double purchasePrice;
  final double sellingPrice;
  final int stock;
  final int alertStock;
  final String? imageUrl;
  final String? barcode;
  final String category;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    required this.id,
    required this.name,
    this.description,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.stock,
    this.alertStock = 5,
    this.imageUrl,
    this.barcode,
    this.category = 'Général',
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  double get margin => sellingPrice - purchasePrice;

  double get marginPercent {
    if (purchasePrice == 0) return 0;
    return (margin / purchasePrice) * 100;
  }

  bool get isLowStock => stock <= alertStock;
  bool get isOutOfStock => stock == 0;

  Product copyWith({
    String? id,
    String? name,
    String? description,
    double? purchasePrice,
    double? sellingPrice,
    int? stock,
    int? alertStock,
    String? imageUrl,
    String? barcode,
    String? category,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      stock: stock ?? this.stock,
      alertStock: alertStock ?? this.alertStock,
      imageUrl: imageUrl ?? this.imageUrl,
      barcode: barcode ?? this.barcode,
      category: category ?? this.category,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'purchase_price': purchasePrice,
      'selling_price': sellingPrice,
      'stock': stock,
      'alert_stock': alertStock,
      'image_url': imageUrl,
      'barcode': barcode,
      'category': category,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      purchasePrice: (map['purchase_price'] as num).toDouble(),
      sellingPrice: (map['selling_price'] as num).toDouble(),
      stock: map['stock'] as int,
      alertStock: map['alert_stock'] as int? ?? 5,
      imageUrl: map['image_url'],
      barcode: map['barcode'],
      category: map['category'] ?? 'Général',
      isActive: map['is_active'] == 1 || map['is_active'] == true,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }
}