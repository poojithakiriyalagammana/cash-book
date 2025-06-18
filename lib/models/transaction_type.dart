// models/transaction_type.dart
class TransactionType {
  int? id;
  final String name;
  final String category; // 'in' for earnings or 'out' for expenses

  TransactionType({
    this.id,
    required this.name,
    required this.category,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
    };
  }

  factory TransactionType.fromMap(Map<String, dynamic> map) {
    return TransactionType(
      id: map['id'],
      name: map['name'],
      category: map['category'],
    );
  }
}
