// models/recurring_transaction.dart
class RecurringTransaction {
  int? id;
  final String type; // 'in' or 'out'
  final double amount;
  final String transactionTypeName;
  final String paymentMode;
  final DateTime startDate;
  final int dayOfMonth;
  final bool isActive;
  final String? note;
  final int? bookId; // Change bookId type to int?

  RecurringTransaction({
    this.id,
    required this.type,
    required this.amount,
    required this.transactionTypeName,
    required this.paymentMode,
    required this.startDate,
    required this.dayOfMonth,
    this.isActive = true,
    this.note,
    this.bookId, // Update constructor to accept int? for bookId
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'transaction_type_name': transactionTypeName,
      'payment_mode': paymentMode,
      'start_date': startDate.toIso8601String(),
      'day_of_month': dayOfMonth,
      'is_active': isActive ? 1 : 0,
      'note': note,
      'book_id': bookId, // Use bookId as int? here
    };
  }

  factory RecurringTransaction.fromMap(Map<String, dynamic> map) {
    return RecurringTransaction(
      id: map['id'],
      type: map['type'],
      amount: map['amount'],
      transactionTypeName: map['transaction_type_name'],
      paymentMode: map['payment_mode'],
      startDate: DateTime.parse(map['start_date']),
      dayOfMonth: map['day_of_month'],
      isActive: map['is_active'] == 1,
      note: map['note'],
      bookId: map['book_id'], // Make sure bookId is an int here
    );
  }
}

// Update the Transaction model to include transactionTypeName
class Transaction {
  int? id;
  final String type; // 'in' or 'out'
  final double amount;
  final String transactionTypeName;
  final String paymentMode;
  final DateTime dateTime;
  final String? note;
  final int? bookId;

  Transaction({
    this.id,
    required this.type,
    required this.amount,
    required this.transactionTypeName,
    required this.paymentMode,
    required this.dateTime,
    this.note,
    this.bookId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'transaction_type_name': transactionTypeName,
      'payment_mode': paymentMode,
      'date_time': dateTime.toIso8601String(),
      'note': note,
      'book_id': bookId,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      type: map['type'],
      amount: map['amount'],
      transactionTypeName: map['transaction_type_name'],
      paymentMode: map['payment_mode'],
      dateTime: DateTime.parse(map['date_time']),
      note: map['note'],
      bookId: map['book_id'] is String
          ? int.tryParse(map['book_id'])
          : map['book_id'] as int?,
    );
  }
}
