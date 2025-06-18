class ExpenseCap {
  final int? id;
  final double amount;

  ExpenseCap({
    this.id,
    required this.amount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
    };
  }

  factory ExpenseCap.fromMap(Map<String, dynamic> map) {
    return ExpenseCap(
      id: map['id'],
      amount: map['amount'],
    );
  }
}
