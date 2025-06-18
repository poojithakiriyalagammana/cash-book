import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/database_helper.dart';
import '../../models/book.dart';
import 'cash_book_screen.dart';
import 'package:flutter/cupertino.dart';

class BookViewScreen extends StatefulWidget {
  const BookViewScreen({Key? key}) : super(key: key);

  @override
  _BookViewScreenState createState() => _BookViewScreenState();
}

class _BookViewScreenState extends State<BookViewScreen>
    with AutomaticKeepAliveClientMixin {
  List<Book> _books = [];
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final TextEditingController _bookNameController = TextEditingController();
  bool _isLoading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ModalRoute.of(context)?.isCurrent ?? false) {
      _loadBooks();
    }
  }

  Future<void> _loadBooks() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final books = await _dbHelper.getAllBooks();
      for (var book in books) {
        await _dbHelper.updateBookBalance(book.id!);
      }

      final updatedBooks = await _dbHelper.getAllBooks();

      if (mounted) {
        setState(() {
          _books = updatedBooks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading books: $e')),
        );
      }
      print('Error loading books: $e');
    }
  }

  Future<void> _createBook() async {
    final bookName = _bookNameController.text.trim();
    if (bookName.isNotEmpty) {
      try {
        final newBook = Book(name: bookName);
        await _dbHelper.insertBook(newBook);
        _bookNameController.clear();
        await _loadBooks();
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating book: $e')),
          );
        }
      }
    }
  }

  Future<void> _renameBook(Book book) async {
    final TextEditingController renameController =
        TextEditingController(text: book.name);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Book'),
        content: TextField(
          controller: renameController,
          decoration: const InputDecoration(
            hintText: 'Enter new book name',
          ),
          maxLength: 20,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = renameController.text.trim();
              if (newName.isNotEmpty) {
                try {
                  final updatedBook = book.copyWith(name: newName);
                  await _dbHelper.updateBook(updatedBook);
                  await _loadBooks();
                  if (mounted) Navigator.of(context).pop();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error renaming book: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteBook(Book book) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Book'),
        content: Text(
          'Are you sure you want to delete "${book.name}"? '
          'All transactions in this book will be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              try {
                await _dbHelper.deleteBook(book.id!);
                await _loadBooks();
                if (mounted) Navigator.of(context).pop();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting book: $e')),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddBookDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Book'),
        content: TextField(
          controller: _bookNameController,
          decoration: const InputDecoration(
            hintText: 'Enter book name',
          ),
          maxLength: 20,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () {
              _bookNameController.clear();
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _createBook,
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showClearDataBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Clear All Data',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'This will permanently delete all books, transactions, and settings. '
                'Are you sure you want to proceed?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade300,
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      _clearAllData();
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: Text('Clear Data'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTopMenuBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.settings,
                color: Colors.blue,
                size: 60,
              ),
              SizedBox(height: 16),
              Text(
                'Manage App Settings',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Choose an action to manage your app settings:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
              SizedBox(height: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _showClearDataBottomSheet();
                    },
                    icon: Icon(Icons.delete_forever, color: Colors.white),
                    label: Text('Clear All Data'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    icon: Icon(Icons.cancel, color: Colors.black54),
                    label: Text('Cancel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black54,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // New method to clear all data
  Future<void> _clearAllData() async {
    try {
      // Clear the database
      await _dbHelper.clearDatabase();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('All data has been cleared'),
            backgroundColor: Colors.green,
          ),
        );

        // Reload books (which should now only have the default book)
        await _loadBooks();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error clearing data: $e',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Error clearing data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          'MoniApp',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert, color: Colors.black),
            onPressed: _showTopMenuBottomSheet,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadBooks,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _books.isEmpty
                ? _buildEmptyState()
                : _buildBookList(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddBookDialog,
        icon: Icon(Icons.add, color: Colors.white),
        label: Text('Add Book', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromARGB(255, 44, 39, 83),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmarks_outlined,
            size: 120,
            color: const Color.fromARGB(255, 44, 39, 83),
          ),
          const SizedBox(height: 20),
          Text(
            'Create Your First Book',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: const Color.fromARGB(255, 17, 0, 130),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Track your finances with ease',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 17, 0, 130),
              padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: _showAddBookDialog,
            child: Text(
              'Create Book',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookList() {
    return ListView.builder(
      itemCount: _books.length,
      itemBuilder: (context, index) {
        final book = _books[index];
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            title: Text(
              book.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: const Color.fromARGB(255, 0, 0, 0),
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Balance: Rs ${NumberFormat('#,##0.00').format(book.totalBalance)}',
                  style: TextStyle(
                    color: book.totalBalance >= 0 ? Colors.green : Colors.red,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (book.financialStartDay != 1)
                  Text(
                    'Financial Month: ${_getFinancialMonthDisplay(book)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.grey.shade700),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: Colors.white,
              elevation: 4,
              onSelected: (value) {
                if (value == 'rename') {
                  _renameBook(book);
                } else if (value == 'delete') {
                  _deleteBook(book);
                } else if (value == 'financial_date') {
                  _showFinancialDateSetupBottomSheet(book);
                }
              },
              itemBuilder: (BuildContext context) => [
                PopupMenuItem<String>(
                  value: 'financial_date',
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today,
                          color: const Color.fromARGB(255, 79, 79, 79),
                          size: 22),
                      SizedBox(width: 10),
                      Text(
                        'Set Financial Date',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'rename',
                  child: Row(
                    children: [
                      Icon(Icons.edit,
                          color: const Color.fromARGB(255, 79, 79, 79),
                          size: 22),
                      SizedBox(width: 10),
                      Text(
                        'Rename',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete,
                          color: const Color.fromARGB(255, 79, 79, 79),
                          size: 22),
                      SizedBox(width: 10),
                      Text(
                        'Delete',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            onTap: () async {
              await _dbHelper.setCurrentBook(book.id!);
              Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                      builder: (context) => CashBookScreen(
                        bookName: book.name,
                        financialStartDay: book.financialStartDay,
                      ),
                    ),
                  )
                  .then((_) => _loadBooks());
            },
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _bookNameController.dispose();
    super.dispose();
  }

  void _showFinancialDateSetupBottomSheet(Book book) {
    int selectedDay = book.financialStartDay;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Set Financial Month Start Day',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Choose the day when your financial month starts (1-28):',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                  SizedBox(height: 20),
                  Container(
                    height: 150,
                    child: CupertinoPicker(
                      itemExtent: 40,
                      onSelectedItemChanged: (int index) {
                        selectedDay = index + 1;
                      },
                      children: List<Widget>.generate(28, (index) {
                        final day = index + 1;
                        return Center(
                          child: Text(
                            '$day',
                            style: TextStyle(fontSize: 20),
                          ),
                        );
                      }),
                      scrollController: FixedExtentScrollController(
                        initialItem: selectedDay - 1,
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  _buildFinancialDatePreview(selectedDay),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Cancel'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          try {
                            // Update the book's financial start day
                            final updatedBook = book.copyWith(
                              financialStartDay: selectedDay,
                            );
                            await _dbHelper.updateBook(updatedBook);
                            await _loadBooks();
                            if (mounted) Navigator.of(context).pop();

                            // Show confirmation
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('Financial month start day updated'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Error updating financial start day: $e'),
                                ),
                              );
                            }
                          }
                        },
                        child: Text('Save'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color.fromARGB(255, 44, 39, 83),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                              horizontal: 30, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFinancialDatePreview(int startDay) {
    final now = DateTime.now();

    // Calculate current financial month
    DateTime financialMonthStart;
    DateTime financialMonthEnd;

    if (now.day >= startDay) {
      // Current month's financial period
      financialMonthStart = DateTime(now.year, now.month, startDay);
      financialMonthEnd = DateTime(now.year, now.month + 1, startDay - 1);
    } else {
      // Previous month's financial period
      financialMonthStart = DateTime(now.year, now.month - 1, startDay);
      financialMonthEnd = DateTime(now.year, now.month, startDay - 1);
    }

    final startMonthName = DateFormat('MMM').format(financialMonthStart);
    final endMonthName = DateFormat('MMM').format(financialMonthEnd);

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            'Current Financial Month',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '$startDay $startMonthName - ${startDay - 1 > 0 ? startDay - 1 : 1} $endMonthName',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color.fromARGB(255, 44, 39, 83),
            ),
          ),
        ],
      ),
    );
  }

  String _getFinancialMonthDisplay(Book book) {
    final startDay = book.financialStartDay;
    final now = DateTime.now();

    DateTime financialMonthStart;
    DateTime financialMonthEnd;

    if (now.day >= startDay) {
      financialMonthStart = DateTime(now.year, now.month, startDay);
      financialMonthEnd = DateTime(now.year, now.month + 1, startDay - 1);
    } else {
      financialMonthStart = DateTime(now.year, now.month - 1, startDay);
      financialMonthEnd = DateTime(now.year, now.month, startDay - 1);
    }

    final startMonthName = DateFormat('MMM').format(financialMonthStart);
    final endMonthName = DateFormat('MMM').format(financialMonthEnd);

    return '$startDay $startMonthName - ${startDay - 1 > 0 ? startDay - 1 : 1} $endMonthName';
  }
}
