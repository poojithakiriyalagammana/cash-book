import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:path/path.dart';
import 'dart:io';
import '../models/expense_cap.dart';
import '../models/transaction_type.dart';
import '../models/recurring_transaction.dart';
import '../models/book.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static int? _currentBookId;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('cash_flow.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    print("Database path: $path");

    final db = await openDatabase(
      path,
      version: 10,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );

    if (await _isDatabaseExist(path)) {
      print("Database created successfully at: $path");
    } else {
      print("Database creation failed at: $path");
    }

    return db;
  }

  Future _createDB(Database db, int version) async {
    // Create books table
    await db.execute('''
CREATE TABLE books(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  total_balance REAL NOT NULL DEFAULT 0.0,
  financial_start_day INTEGER NOT NULL DEFAULT 1
)''');
    print("Table 'books' created.");

    await db.execute('''
    CREATE TABLE transactions(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      book_id INTEGER NOT NULL,
      type TEXT NOT NULL,
      amount REAL NOT NULL,
      transaction_type_name TEXT NOT NULL,
      payment_mode TEXT NOT NULL,
      date_time TEXT NOT NULL,
      note TEXT,
      FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
    )''');
    print("Table 'transactions' created.");

    await db.execute('''
    CREATE TABLE expense_caps(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      book_id INTEGER NOT NULL,
      amount REAL NOT NULL,
      FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
    )''');
    print("Table 'expense_caps' created.");

    await db.execute('''
CREATE TABLE transaction_types(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  book_id INTEGER,
  FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
)''');
    print("Table 'transaction_types' created.");

    await db.execute('''
    CREATE TABLE recurring_transactions(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      book_id INTEGER NOT NULL,
      type TEXT NOT NULL,
      amount REAL NOT NULL,
      transaction_type_name TEXT NOT NULL,
      payment_mode TEXT NOT NULL,
      start_date TEXT NOT NULL,
      day_of_month INTEGER NOT NULL,
      is_active INTEGER NOT NULL DEFAULT 1,
      note TEXT,
      FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
    )''');
    print("Table 'recurring_transactions' created.");

    // Insert default transaction types
    await _insertDefaultTransactionTypes(db);
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
    CREATE TABLE expense_caps(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      amount REAL NOT NULL
    )''');
      print("Table 'expense_caps' added.");
      await db.insert('expense_caps', {'amount': 0.0});
    }

    if (oldVersion < 3) {
      await db.execute('''
    ALTER TABLE transactions RENAME COLUMN party_name TO transaction_type_name
    ''');
      await db.execute('''
    CREATE TABLE transaction_types(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      category TEXT NOT NULL
    )''');
      print("Table 'transaction_types' created.");

      await db.execute('''
    CREATE TABLE recurring_transactions(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      type TEXT NOT NULL,
      amount REAL NOT NULL,
      transaction_type_name TEXT NOT NULL,
      payment_mode TEXT NOT NULL,
      start_date TEXT NOT NULL,
      day_of_month INTEGER NOT NULL,
      is_active INTEGER NOT NULL DEFAULT 1,
      note TEXT

    )''');
      print("Table 'recurring_transactions' created.");

      await _insertDefaultTransactionTypes(db);
    }
    if (oldVersion < 4) {
      await db.execute('''
    ALTER TABLE transactions ADD COLUMN note TEXT
    ''');
    }
    if (oldVersion < 5) {
      await db.execute('''
    ALTER TABLE recurring_transactions ADD COLUMN note TEXT
    ''');
    }
    if (oldVersion < 7) {
      await db.execute('''
      CREATE TABLE books(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        total_balance REAL NOT NULL DEFAULT 0.0,
        
      )''');

      await db.execute('ALTER TABLE transactions ADD COLUMN book_id INTEGER');
      await db.execute('ALTER TABLE expense_caps ADD COLUMN book_id INTEGER');
      await db.execute(
          'ALTER TABLE recurring_transactions ADD COLUMN book_id INTEGER');
      await db
          .execute('ALTER TABLE transaction_types ADD COLUMN book_id INTEGER');

      print("Added books table and book_id columns.");
    }
    if (oldVersion < 8) {
      List<Map<String, dynamic>> bookResult = await db.query('books', limit: 1);
      if (bookResult.isEmpty) {
        final defaultBookId = await db
            .insert('books', {'name': 'My First Book', 'total_balance': 0.0});
        bookResult = [
          {'id': defaultBookId}
        ];
      }

      final firstBookId = bookResult.first['id'] as int;

      try {
        await db.query('transaction_types',
            where: 'book_id IS NOT NULL', limit: 1);
      } catch (e) {
        await db.execute(
            'ALTER TABLE transaction_types ADD COLUMN book_id INTEGER');
      }

      await _insertDefaultTransactionTypes(db, bookId: firstBookId);
    }
    if (oldVersion < 10) {
      try {
        await db.execute(
            'ALTER TABLE books ADD COLUMN financial_start_day INTEGER NOT NULL DEFAULT 1');
        print("Added financial_start_day column to books table");
      } catch (e) {
        print("Error adding financial_start_day column: $e");
      }
    }
  }

  // Book-related methods
  Future<int> insertBook(Book book) async {
    final db = await instance.database;
    return await db.insert('books', book.toMap());
  }

  Future<List<Book>> getAllBooks() async {
    final db = await instance.database;
    final result = await db.query('books');
    return result.map((map) => Book.fromMap(map)).toList();
  }

  Future<Book?> getBookById(int bookId) async {
    final db = await instance.database;
    final result =
        await db.query('books', where: 'id = ?', whereArgs: [bookId]);
    return result.isNotEmpty ? Book.fromMap(result.first) : null;
  }

  Future<void> setCurrentBook(int bookId) async {
    _currentBookId = bookId;
  }

  Future<Book?> getCurrentBook() async {
    final bookId = await getCurrentBookId();
    if (bookId == null) {
      return null;
    }
    return await getBookById(bookId);
  }

  Future<int?> getCurrentBookId() async {
    if (_currentBookId == null) {
      final books = await getAllBooks();
      if (books.isEmpty) {
        final newBook = Book(name: 'My First Book');
        _currentBookId = await insertBook(newBook);
      } else {
        _currentBookId = books.first.id;
      }
    }
    return _currentBookId;
  }

  Future _insertDefaultTransactionTypes(Database db, {int? bookId}) async {
    // Default earning types
    final earningTypes = [
      {'name': 'Salary Income', 'category': 'in', 'book_id': bookId},
      {'name': 'Business Income', 'category': 'in', 'book_id': bookId},
      {'name': 'Interest Income', 'category': 'in', 'book_id': bookId},
      {'name': 'Rental Income', 'category': 'in', 'book_id': bookId},
      {'name': 'Gift', 'category': 'in', 'book_id': bookId},
      {'name': 'Other Income', 'category': 'in', 'book_id': bookId},
    ];

    // Default expense types
    final expenseTypes = [
      {'name': 'Food', 'category': 'out', 'book_id': bookId},
      {'name': 'Transportation', 'category': 'out', 'book_id': bookId},
      {'name': 'Utilities', 'category': 'out', 'book_id': bookId},
      {'name': 'Housing', 'category': 'out', 'book_id': bookId},
      {'name': 'Healthcare', 'category': 'out', 'book_id': bookId},
      {'name': 'Entertainment', 'category': 'out', 'book_id': bookId},
      {'name': 'Shopping', 'category': 'out', 'book_id': bookId},
      {'name': 'Education', 'category': 'out', 'book_id': bookId},
      {'name': 'Travel', 'category': 'out', 'book_id': bookId},
      {'name': 'Other Expense', 'category': 'out', 'book_id': bookId},
    ];

    // Insert all default types
    for (var type in [...earningTypes, ...expenseTypes]) {
      await db.insert('transaction_types', type);
    }

    print("Default transaction types added.");
  }

  Future<void> updateBookBalance(int bookId) async {
    final db = await instance.database;

    // Calculate total balance by summing income and subtracting expenses
    final incomeResult = await db.rawQuery('''
    SELECT SUM(amount) as total 
    FROM transactions 
    WHERE type = 'in' AND book_id = ?
  ''', [bookId]);

    final expenseResult = await db.rawQuery('''
    SELECT SUM(amount) as total 
    FROM transactions 
    WHERE type = 'out' AND book_id = ?
  ''', [bookId]);

    final totalIncome =
        (incomeResult.first['total'] as num?)?.toDouble() ?? 0.0;
    final totalExpense =
        (expenseResult.first['total'] as num?)?.toDouble() ?? 0.0;

    final totalBalance = totalIncome - totalExpense;

    await db.update('books', {'total_balance': totalBalance},
        where: 'id = ?', whereArgs: [bookId]);
  }

  // Transaction Methods
  Future<int> insertTransaction(Transaction transaction) async {
    final bookId = await getCurrentBookId();
    final db = await instance.database;
    final transactionMap = transaction.toMap();
    transactionMap['book_id'] = bookId!;
    final transactionId = await db.insert('transactions', transactionMap);

    // Update book balance after inserting transaction
    await updateBookBalance(bookId);

    return transactionId;
  }

  Future<List<Transaction>> getAllTransactions() async {
    final bookId = await getCurrentBookId();
    final db = await instance.database;
    final result = await db.query('transactions',
        where: 'book_id = ?', whereArgs: [bookId], orderBy: 'date_time DESC');
    return result.map((map) => Transaction.fromMap(map)).toList();
  }

  Future<List<Transaction>> getTransactionsByTypeAndDateRange(
      String type, DateTime startDate, DateTime endDate) async {
    final bookId = await getCurrentBookId();
    final db = await instance.database;

    final result = await db.query(
      'transactions',
      where: 'type = ? AND date_time BETWEEN ? AND ? AND book_id = ?',
      whereArgs: [
        type,
        startDate.toIso8601String(),
        endDate.toIso8601String(),
        bookId,
      ],
      orderBy: 'date_time DESC',
    );

    return result.map((map) => Transaction.fromMap(map)).toList();
  }

  Future<List<Transaction>> getFilteredTransactions({
    String? type,
    String? transactionTypeName,
    String? paymentMode,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final bookId = await getCurrentBookId();
    final db = await instance.database;
    String whereClause = 'book_id = ?';
    List<dynamic> whereArgs = [bookId];

    if (type != null) {
      whereClause += ' AND type = ?';
      whereArgs.add(type);
    }

    if (transactionTypeName != null) {
      whereClause += ' AND transaction_type_name = ?';
      whereArgs.add(transactionTypeName);
    }

    if (paymentMode != null) {
      whereClause += ' AND payment_mode = ?';
      whereArgs.add(paymentMode);
    }

    if (startDate != null && endDate != null) {
      whereClause += ' AND date_time BETWEEN ? AND ?';
      whereArgs.add(startDate.toIso8601String());
      whereArgs.add(endDate.toIso8601String());
    }

    final result = await db.query(
      'transactions',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'date_time DESC',
    );

    return result.map((map) => Transaction.fromMap(map)).toList();
  }

  Future<double> getTotalCashIn() async {
    final bookId = await getCurrentBookId();
    final db = await instance.database;
    final result = await db.rawQuery(
        'SELECT SUM(amount) as total FROM transactions WHERE type = ? AND book_id = ?',
        ['in', bookId]);
    return result.first['total'] == null
        ? 0.0
        : result.first['total'] as double;
  }

  Future<double> getTotalCashOut() async {
    final bookId = await getCurrentBookId();
    final db = await instance.database;
    final result = await db.rawQuery(
        'SELECT SUM(amount) as total FROM transactions WHERE type = ? AND book_id = ?',
        ['out', bookId]);
    return result.first['total'] == null
        ? 0.0
        : result.first['total'] as double;
  }

  Future<double> getBalance() async {
    final bookId = await getCurrentBookId();
    final db = await instance.database;
    final cashInResult = await db.rawQuery(
        'SELECT SUM(amount) as total FROM transactions WHERE type = ? AND book_id = ?',
        ['in', bookId]);
    final cashOutResult = await db.rawQuery(
        'SELECT SUM(amount) as total FROM transactions WHERE type = ? AND book_id = ?',
        ['out', bookId]);

    final cashIn = cashInResult.first['total'] == null
        ? 0.0
        : cashInResult.first['total'] as double;
    final cashOut = cashOutResult.first['total'] == null
        ? 0.0
        : cashOutResult.first['total'] as double;

    return cashIn - cashOut;
  }

  Future<void> deleteBook(int bookId) async {
    final db = await instance.database;
    await db.delete('books', where: 'id = ?', whereArgs: [bookId]);
  }

  // Update book details
  Future<int> updateBook(Book book) async {
    final db = await instance.database;
    return await db
        .update('books', book.toMap(), where: 'id = ?', whereArgs: [book.id]);
  }

  // TransactionType Methods
  Future<int> insertTransactionType(TransactionType type) async {
    final bookId = await getCurrentBookId();
    final db = await instance.database;
    final typeMap = type.toMap();
    typeMap['book_id'] = bookId;
    return await db.insert('transaction_types', typeMap);
  }

  Future<int> updateTransactionType(TransactionType type) async {
    final db = await instance.database;
    return await db.update(
      'transaction_types',
      type.toMap(),
      where: 'id = ?',
      whereArgs: [type.id],
    );
  }

  Future<int> deleteTransactionType(int id) async {
    final db = await instance.database;
    return await db.delete(
      'transaction_types',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<TransactionType>> getTransactionTypesByCategory(
      String category) async {
    final bookId = await getCurrentBookId();
    final db = await instance.database;
    final result = await db.query(
      'transaction_types',
      where: 'category = ? AND (book_id IS NULL OR book_id = ?)',
      whereArgs: [category, bookId],
      orderBy: 'name ASC',
    );
    return result.map((map) => TransactionType.fromMap(map)).toList();
  }

  Future<List<TransactionType>> getAllTransactionTypes() async {
    final bookId = await getCurrentBookId();
    final db = await instance.database;
    final result = await db.query('transaction_types',
        where: 'book_id IS NULL OR book_id = ?',
        whereArgs: [bookId],
        orderBy: 'name ASC');
    return result.map((map) => TransactionType.fromMap(map)).toList();
  }

  Future<List<TransactionType>> getAllEarningTypes() async {
    return getTransactionTypesByCategory('in');
  }

  Future<List<TransactionType>> getAllExpenseTypes() async {
    return getTransactionTypesByCategory('out');
  }

  // RecurringTransaction Methods
  Future<int> insertRecurringTransaction(
      RecurringTransaction transaction) async {
    final bookId = await getCurrentBookId();
    final db = await instance.database;
    final transactionMap = transaction.toMap();
    transactionMap['book_id'] = bookId;
    return await db.insert('recurring_transactions', transactionMap);
  }

  Future<List<RecurringTransaction>> getActiveRecurringTransactions() async {
    final bookId = await getCurrentBookId();
    final db = await instance.database;
    final result = await db.query(
      'recurring_transactions',
      where: 'is_active = ? AND book_id = ?',
      whereArgs: [1, bookId],
    );
    return result.map((map) => RecurringTransaction.fromMap(map)).toList();
  }

  Future<int> updateRecurringTransaction(
      RecurringTransaction transaction) async {
    final db = await instance.database;
    return await db.update(
      'recurring_transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<int> updateRecurringTransactionStatus(int id, bool isActive) async {
    final db = await instance.database;
    return await db.update(
      'recurring_transactions',
      {'is_active': isActive ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<RecurringTransaction?> getRecurringTransactionByTransactionProperties(
      Transaction transaction) async {
    final db = await instance.database;

    final result = await db.query(
      'recurring_transactions',
      where:
          'type = ? AND transaction_type_name = ? AND amount = ? AND book_id = ?',
      whereArgs: [
        transaction.type,
        transaction.transactionTypeName,
        transaction.amount,
        transaction.bookId
      ],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return RecurringTransaction.fromMap(result.first);
  }

  Future<int> deleteRecurringTransactionByTransactionProperties(
      Transaction transaction) async {
    final db = await instance.database;

    return await db.delete(
      'recurring_transactions',
      where: 'type = ? AND transaction_type_name = ? AND book_id = ?',
      whereArgs: [
        transaction.type,
        transaction.transactionTypeName,
        transaction.bookId
      ],
    );
  }

  Future<RecurringTransaction?> getRecurringTransactionById(int id) async {
    final db = await instance.database;

    final result = await db.query(
      'recurring_transactions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return RecurringTransaction.fromMap(result.first);
  }

  // ExpenseCap Methods
  Future<ExpenseCap> getExpenseCap() async {
    final bookId = await getCurrentBookId();
    final db = await instance.database;
    final maps = await db.query('expense_caps',
        where: 'book_id = ?', whereArgs: [bookId], limit: 1);

    if (maps.isEmpty) {
      final id =
          await db.insert('expense_caps', {'book_id': bookId, 'amount': 0.0});
      return ExpenseCap(id: id, amount: 0.0);
    }

    return ExpenseCap.fromMap(maps.first);
  }

  Future<void> updateExpenseCap(ExpenseCap expenseCap) async {
    final bookId = await getCurrentBookId();
    final db = await instance.database;
    final existingCaps = await db
        .query('expense_caps', where: 'book_id = ?', whereArgs: [bookId]);

    if (existingCaps.isEmpty) {
      await db
          .insert('expense_caps', {...expenseCap.toMap(), 'book_id': bookId});
    } else {
      await db.update(
        'expense_caps',
        expenseCap.toMap(),
        where: 'book_id = ?',
        whereArgs: [bookId],
      );
    }
  }

  // Helper method to check
  Future<bool> _isDatabaseExist(String path) async {
    return await File(path).exists();
  }

  // Monthly statistics methods
  Future<Map<String, double>> getMonthlyStats(DateTime month) async {
    final bookId = await getCurrentBookId();
    final db = await instance.database;
    final startDate = DateTime(month.year, month.month, 1);
    final endDate = DateTime(month.year, month.month + 1, 0);

    // Get monthly income
    final incomeResult = await db.rawQuery(
        'SELECT SUM(amount) as total FROM transactions WHERE type = ? AND date_time BETWEEN ? AND ? AND book_id = ?',
        ['in', startDate.toIso8601String(), endDate.toIso8601String(), bookId]);
    final monthlyIncome = incomeResult.first['total'] == null
        ? 0.0
        : incomeResult.first['total'] as double;

    // Get monthly expense
    final expenseResult = await db.rawQuery(
        'SELECT SUM(amount) as total FROM transactions WHERE type = ? AND date_time BETWEEN ? AND ? AND book_id = ?',
        [
          'out',
          startDate.toIso8601String(),
          endDate.toIso8601String(),
          bookId
        ]);
    final monthlyExpense = expenseResult.first['total'] == null
        ? 0.0
        : expenseResult.first['total'] as double;

    return {
      'income': monthlyIncome,
      'expense': monthlyExpense,
      'balance': monthlyIncome - monthlyExpense
    };
  }

  // Get category-wise breakdown of transactions for a specific period
  Future<Map<String, double>> getCategoryBreakdown({
    required String type,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final bookId = await getCurrentBookId();
    final db = await instance.database;
    String query = '''
    SELECT transaction_type_name, SUM(amount) as total 
    FROM transactions 
    WHERE type = ? AND book_id = ?
  ''';
    List<dynamic> args = [type, bookId];

    if (startDate != null && endDate != null) {
      query += ' AND date_time BETWEEN ? AND ?';
      args.add(startDate.toIso8601String());
      args.add(endDate.toIso8601String());
    }

    query += ' GROUP BY transaction_type_name ORDER BY total DESC';
    final result = await db.rawQuery(query, args);

    Map<String, double> breakdown = {};
    for (var row in result) {
      breakdown[row['transaction_type_name'] as String] =
          row['total'] as double;
    }

    return breakdown;
  }

  // Process recurring transactions that are due
  Future<List<Transaction>> processRecurringTransactions() async {
    final bookId = await getCurrentBookId();
    final db = await instance.database;
    final today = DateTime.now();
    final currentDay = today.day;

    List<Transaction> processedTransactions = [];

    // Get all active recurring transactions for this book
    final recurringTransactions = await getActiveRecurringTransactions();

    for (var recurring in recurringTransactions) {
      // Check if transaction should be processed today
      if (recurring.dayOfMonth == currentDay) {
        // Check if it has already been processed this month
        final startOfToday = DateTime(today.year, today.month, today.day);
        final endOfToday =
            DateTime(today.year, today.month, today.day, 23, 59, 59);

        final existingTransactions = await db.query(
          'transactions',
          where:
              'book_id = ? AND type = ? AND transaction_type_name = ? AND amount = ? AND date_time BETWEEN ? AND ?',
          whereArgs: [
            bookId,
            recurring.type,
            recurring.transactionTypeName,
            recurring.amount,
            startOfToday.toIso8601String(),
            endOfToday.toIso8601String()
          ],
        );

        // If not already processed today, create a new transaction
        if (existingTransactions.isEmpty) {
          final transaction = Transaction(
            id: 0,
            type: recurring.type,
            amount: recurring.amount,
            transactionTypeName: recurring.transactionTypeName,
            paymentMode: recurring.paymentMode,
            dateTime: DateTime.now(),
          );

          final id = await insertTransaction(transaction);
          transaction.id = id;
          processedTransactions.add(transaction);
        }
      }
    }

    return processedTransactions;
  }

  // Delete a transaction
  Future<int> deleteTransaction(int id) async {
    final db = await instance.database;
    final transaction =
        await db.query('transactions', where: 'id = ?', whereArgs: [id]);
    final bookId = transaction.first['book_id'] as int;

    final deletedRows = await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );

    // Update book balance after deleting transaction
    await updateBookBalance(bookId);

    return deletedRows;
  }

  Future<int> updateTransaction(Transaction transaction) async {
    final db = await instance.database;
    final updatedRows = await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );

    // Handle bookId more robustly
    if (transaction.bookId == null) {
      throw Exception('Invalid or null bookId');
    }

    // Update book balance after updating transaction
    await updateBookBalance(transaction.bookId!);

    return updatedRows;
  }

  // Get transaction count
  Future<int> getTransactionCount() async {
    final db = await instance.database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as count FROM transactions');
    return result.first['count'] as int;
  }

  // Clear database
  Future<void> clearDatabase() async {
    final db = await instance.database;
    await db.delete('transactions');
    await db.delete('recurring_transactions');
    await db.delete('transaction_types');
    await db.delete('expense_caps');
    await db.delete('books');

    // Create a default book first
    final defaultBook = Book(name: 'My First Book', totalBalance: 0.0);
    final bookId = await insertBook(defaultBook); // This gives you the book ID

    // Now insert expense cap with valid book ID
    await db.insert('expense_caps', {'amount': 0.0, 'book_id': bookId});

    await _insertDefaultTransactionTypes(db);
  }

  Future<List<Map<String, dynamic>>> getTransactionCounts({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final bookId = await getCurrentBookId();
    final db = await instance.database;

    // This query will join transactions with transaction_types to get both
    // transaction data and the associated transaction type information
    final result = await db.rawQuery('''
    SELECT t.id, t.type, t.amount, t.transaction_type_name as transactionTypeName, 
           t.payment_mode, t.date_time, tt.id as transaction_type_id, t.book_id
    FROM transactions t
    LEFT JOIN transaction_types tt ON t.transaction_type_name = tt.name
    WHERE t.date_time BETWEEN ? AND ? AND t.book_id = ?
    ORDER BY t.date_time DESC
  ''', [startDate.toIso8601String(), endDate.toIso8601String(), bookId]);

    // If no results, return empty list
    if (result.isEmpty) {
      return [];
    }

    return result;
  }

  Future<List<Transaction>> getTransactionsByType(String type) async {
    final bookId = await getCurrentBookId();
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'type = ? AND book_id = ?',
      whereArgs: [type, bookId],
      orderBy: 'date_time DESC',
    );
    return List.generate(maps.length, (i) => Transaction.fromMap(maps[i]));
  }

  Future<List<Transaction>> getTransactionsByCategory(String category) async {
    final bookId = await getCurrentBookId();
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'transaction_type_name = ? AND book_id = ?',
      whereArgs: [category, bookId],
      orderBy: 'date_time DESC',
    );
    return List.generate(maps.length, (i) => Transaction.fromMap(maps[i]));
  }

  Future<void> setFinancialStartDay(int bookId, int startDay) async {
    final db = await instance.database;
    await db.update('books', {'financial_start_day': startDay},
        where: 'id = ?', whereArgs: [bookId]);
  }

  Future<int> getFinancialStartDay(int bookId) async {
    final db = await instance.database;
    final result = await db.query('books',
        columns: ['financial_start_day'], where: 'id = ?', whereArgs: [bookId]);

    if (result.isNotEmpty && result.first['financial_start_day'] != null) {
      return result.first['financial_start_day'] as int;
    }
    return 1; // Default to 1st day of month
  }

  Future<double> getTotalExpenseForPeriod({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final bookId = await getCurrentBookId();
    final db = await database;

    final query = '''
      SELECT 
        SUM(t.amount) as total
      FROM 
        transactions t
      JOIN 
        transaction_types tt ON t.transaction_type_name = tt.name AND (tt.book_id IS NULL OR tt.book_id = ?)
      WHERE 
        t.type = 'out' AND
        t.book_id = ? AND
        t.date_time BETWEEN ? AND ?
    ''';

    final result = await db.rawQuery(query, [
      bookId,
      bookId,
      startDate.toIso8601String(),
      endDate.toIso8601String()
    ]);

    final total = result.first['total'];
    return total != null ? (total as num).toDouble() : 0.0;
  }

  Future<double> getTotalIncomeForPeriod({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final bookId = await getCurrentBookId();
    final db = await database;

    final query = '''
      SELECT 
        SUM(t.amount) as total
      FROM 
        transactions t
      JOIN 
        transaction_types tt ON t.transaction_type_name = tt.name AND (tt.book_id IS NULL OR tt.book_id = ?)
      WHERE 
        t.type = 'in' AND
        t.book_id = ? AND
        t.date_time BETWEEN ? AND ?
    ''';

    final result = await db.rawQuery(query, [
      bookId,
      bookId,
      startDate.toIso8601String(),
      endDate.toIso8601String()
    ]);

    final total = result.first['total'];
    return total != null ? (total as num).toDouble() : 0.0;
  }
}
