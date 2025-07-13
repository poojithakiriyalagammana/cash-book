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
      version: 2,
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
  }
}
