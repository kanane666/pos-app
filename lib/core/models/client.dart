class Client {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final double totalDebt;
  final DateTime createdAt;

  Client({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.totalDebt = 0,
    required this.createdAt,
  });

  bool get hasDebt => totalDebt > 0;

  Client copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    double? totalDebt,
    DateTime? createdAt,
  }) {
    return Client(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      totalDebt: totalDebt ?? this.totalDebt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'total_debt': totalDebt,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      id: map['id'],
      name: map['name'],
      phone: map['phone'],
      email: map['email'],
      totalDebt: (map['total_debt'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}