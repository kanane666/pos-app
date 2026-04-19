class WorkSession {
  final String id;
  final double openingCash;
  final double? closingCash;
  final DateTime openedAt;
  final DateTime? closedAt;
  final bool isOpen;

  WorkSession({
    required this.id,
    required this.openingCash,
    this.closingCash,
    required this.openedAt,
    this.closedAt,
    this.isOpen = true,
  });

  Duration get duration {
    final end = closedAt ?? DateTime.now();
    return end.difference(openedAt);
  }

  String get durationLabel {
    final h = duration.inHours;
    final m = duration.inMinutes % 60;
    return '${h}h${m.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'opening_cash': openingCash,
      'closing_cash': closingCash,
      'opened_at': openedAt.toIso8601String(),
      'closed_at': closedAt?.toIso8601String(),
      'is_open': isOpen ? 1 : 0,
    };
  }

  factory WorkSession.fromMap(Map<String, dynamic> map) {
    return WorkSession(
      id: map['id'],
      openingCash: (map['opening_cash'] as num).toDouble(),
      closingCash: map['closing_cash'] != null
          ? (map['closing_cash'] as num).toDouble()
          : null,
      openedAt: DateTime.parse(map['opened_at']),
      closedAt: map['closed_at'] != null
          ? DateTime.parse(map['closed_at'])
          : null,
      isOpen: map['is_open'] == 1 || map['is_open'] == true,
    );
  }

  WorkSession copyWith({
    double? closingCash,
    DateTime? closedAt,
    bool? isOpen,
  }) {
    return WorkSession(
      id: id,
      openingCash: openingCash,
      closingCash: closingCash ?? this.closingCash,
      openedAt: openedAt,
      closedAt: closedAt ?? this.closedAt,
      isOpen: isOpen ?? this.isOpen,
    );
  }
}