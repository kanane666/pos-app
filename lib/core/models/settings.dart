class AppSettings {
  final double maxDiscountPercent;
  final bool enforceMinPrice;

  AppSettings({
    this.maxDiscountPercent = 20,
    this.enforceMinPrice = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'max_discount_percent': maxDiscountPercent,
      'enforce_min_price': enforceMinPrice ? 1 : 0,
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      maxDiscountPercent:
          (map['max_discount_percent'] as num?)?.toDouble() ?? 20,
      enforceMinPrice:
          map['enforce_min_price'] == 1 || map['enforce_min_price'] == true,
    );
  }

  AppSettings copyWith({
    double? maxDiscountPercent,
    bool? enforceMinPrice,
  }) {
    return AppSettings(
      maxDiscountPercent: maxDiscountPercent ?? this.maxDiscountPercent,
      enforceMinPrice: enforceMinPrice ?? this.enforceMinPrice,
    );
  }
}