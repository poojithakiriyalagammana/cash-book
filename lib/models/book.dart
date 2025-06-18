class Book {
  final int? id;
  final String name;
  final double totalBalance;
  final int financialStartDay;

  Book({
    this.id,
    required this.name,
    this.totalBalance = 0.0,
    this.financialStartDay = 1,
  });

  Book copyWith({
    int? id,
    String? name,
    double? totalBalance,
    int? financialStartDay,
  }) {
    return Book(
      id: id ?? this.id,
      name: name ?? this.name,
      totalBalance: totalBalance ?? this.totalBalance,
      financialStartDay: financialStartDay ?? this.financialStartDay,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'total_balance': totalBalance,
      'financial_start_day': financialStartDay,
    };
  }

  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'],
      name: map['name'],
      totalBalance: map['total_balance'] is int
          ? (map['total_balance'] as int).toDouble()
          : map['total_balance'] as double,
      financialStartDay: map['financial_start_day'] as int? ?? 1,
    );
  }
}
