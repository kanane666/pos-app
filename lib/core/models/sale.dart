class SaleItem {
  final String productId;
  final String productName;
  final double unitPrice;
  final double purchasePrice;
  final int quantity;
  final double discount;

  SaleItem({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.purchasePrice,
    required this.quantity,
    this.discount = 0,
  });

  double get total => (unitPrice - discount) * quantity;
  double get profit => (unitPrice - discount - purchasePrice) * quantity;

  Map<String, dynamic> toMap() {
    return {
      'product_id': productId,
      'product_name': productName,
      'unit_price': unitPrice,
      'purchase_price': purchasePrice,
      'quantity': quantity,
      'discount': discount,
    };
  }

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      productId: map['product_id'],
      productName: map['product_name'],
      unitPrice: (map['unit_price'] as num).toDouble(),
      purchasePrice: (map['purchase_price'] as num).toDouble(),
      quantity: map['quantity'] as int,
      discount: (map['discount'] as num?)?.toDouble() ?? 0,
    );
  }
}

enum PaymentMethod { cash, mobileMoney, card, debt }

enum SaleStatus { completed, cancelled, partial }

class Sale {
  final String id;
  final List<SaleItem> items;
  final double totalAmount;
  final double paidAmount;
  final PaymentMethod paymentMethod;
  final SaleStatus status;
  final String? clientId;
  final String? clientName;
  final String? note;
  final DateTime createdAt;

  Sale({
    required this.id,
    required this.items,
    required this.totalAmount,
    required this.paidAmount,
    required this.paymentMethod,
    this.status = SaleStatus.completed,
    this.clientId,
    this.clientName,
    this.note,
    required this.createdAt,
  });

  double get remainingAmount => totalAmount - paidAmount;
  bool get hasDebt => remainingAmount > 0;
  double get totalProfit => items.fold(0, (sum, item) => sum + item.profit);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'items': items.map((e) => e.toMap()).toList(),
      'total_amount': totalAmount,
      'paid_amount': paidAmount,
      'payment_method': paymentMethod.name,
      'status': status.name,
      'client_id': clientId,
      'client_name': clientName,
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id'],
      items: (map['items'] as List)
          .map((e) => SaleItem.fromMap(e as Map<String, dynamic>))
          .toList(),
      totalAmount: (map['total_amount'] as num).toDouble(),
      paidAmount: (map['paid_amount'] as num).toDouble(),
      paymentMethod: PaymentMethod.values.byName(map['payment_method']),
      status: SaleStatus.values.byName(map['status']),
      clientId: map['client_id'],
      clientName: map['client_name'],
      note: map['note'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}