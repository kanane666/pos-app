class DebtPayment {
  final String id;
  final double amount;
  final DateTime paidAt;
  final String? note;

  DebtPayment({
    required this.id,
    required this.amount,
    required this.paidAt,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'paid_at': paidAt.toIso8601String(),
      'note': note,
    };
  }

  factory DebtPayment.fromMap(Map<String, dynamic> map) {
    return DebtPayment(
      id: map['id'],
      amount: (map['amount'] as num).toDouble(),
      paidAt: DateTime.parse(map['paid_at']),
      note: map['note'],
    );
  }
}

class Debt {
  final String id;
  final String clientId;
  final String clientName;
  final String saleId;
  final double originalAmount;
  final double remainingAmount;
  final List<DebtPayment> payments;
  final DateTime createdAt;
  final DateTime? dueDate;

  Debt({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.saleId,
    required this.originalAmount,
    required this.remainingAmount,
    this.payments = const [],
    required this.createdAt,
    this.dueDate,
  });

  bool get isPaid => remainingAmount <= 0;
  bool get isOverdue => dueDate != null && DateTime.now().isAfter(dueDate!);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'client_id': clientId,
      'client_name': clientName,
      'sale_id': saleId,
      'original_amount': originalAmount,
      'remaining_amount': remainingAmount,
      'payments': payments.map((e) => e.toMap()).toList(),
      'created_at': createdAt.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
    };
  }

  factory Debt.fromMap(Map<String, dynamic> map) {
    return Debt(
      id: map['id'],
      clientId: map['client_id'],
      clientName: map['client_name'],
      saleId: map['sale_id'],
      originalAmount: (map['original_amount'] as num).toDouble(),
      remainingAmount: (map['remaining_amount'] as num).toDouble(),
      payments: (map['payments'] as List? ?? [])
          .map((e) => DebtPayment.fromMap(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(map['created_at']),
      dueDate: map['due_date'] != null ? DateTime.parse(map['due_date']) : null,
    );
  }
}