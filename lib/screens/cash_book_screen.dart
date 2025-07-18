import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/database_helper.dart';
import 'cash_in_screen.dart';
import 'monthly_expenses_screen.dart';
import 'edit_earning_types_screen.dart';
import '../models/recurring_transaction.dart';
import 'recurring_transactions_screen.dart';
import 'package:flutter/services.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

class CashBookScreen extends StatefulWidget {
  final String bookName;
  final int financialStartDay;

  const CashBookScreen(
      {Key? key, required this.bookName, this.financialStartDay = 1})
      : super(key: key);

  @override
  _CashBookScreenState createState() => _CashBookScreenState();
}

class _CashBookScreenState extends State<CashBookScreen> {
  final dbHelper = DatabaseHelper.instance;

  List<Transaction> transactions = [];
  double cashIn = 0;
  double cashOut = 0;
  double balance = 0;
  final MethodChannel channel = MethodChannel('com.your.package/android_info');
  String _selectedFilter = 'All';
  List<String> _inCategories = [];
  List<String> _outCategories = [];
  String? _mainFilter;
  String? _subFilter;
  bool _showSubFilterButton = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _refreshData();
    _checkForInitialNotification();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      // Get Android SDK version
      final sdkVersion = await _getAndroidSdkVersion();

      if (sdkVersion >= 30) {
        // Android 11+ requires MANAGE_EXTERNAL_STORAGE
        PermissionStatus storageStatus =
            await Permission.manageExternalStorage.status;
        if (!storageStatus.isGranted) {
          storageStatus = await Permission.manageExternalStorage.request();
        }
      } else {
        // Android 10 and below require READ_EXTERNAL_STORAGE and WRITE_EXTERNAL_STORAGE
        PermissionStatus readStatus = await Permission.storage.status;
        if (!readStatus.isGranted) {
          readStatus = await Permission.storage.request();
        }
      }
    }

    // Request notification permission
    PermissionStatus notificationStatus = await Permission.notification.status;
    if (!notificationStatus.isGranted) {
      notificationStatus = await Permission.notification.request();
    }

    // Log the status of permissions
    print('Storage permission: ${await Permission.storage.status}');
    print(
        'Manage storage permission: ${await Permission.manageExternalStorage.status}');
    print('Notification permission: ${await Permission.notification.status}');
  }

//notification
  Future<void> _checkForInitialNotification() async {
    final initialAction =
        await AwesomeNotifications().getInitialNotificationAction();

    if (initialAction != null &&
        initialAction.payload != null &&
        initialAction.payload!.containsKey('screen') &&
        initialAction.payload!['screen'] == 'recurring_transactions') {
      // Small delay to ensure the main screen is fully loaded
      Future.delayed(const Duration(milliseconds: 500), () {
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const RecurringTransactionsScreen()));
      });
    }
  }

// Helper method to get Android SDK version
  Future<int> _getAndroidSdkVersion() async {
    if (Platform.isAndroid) {
      return int.parse(await channel.invokeMethod('getAndroidSdkVersion'));
    }
    return 0;
  }

  Future<void> _refreshData() async {
    final txns = await dbHelper.getAllTransactions();
    final totalIn = await dbHelper.getTotalCashIn();
    final totalOut = await dbHelper.getTotalCashOut();
    final bal = await dbHelper.getBalance();

    // Fetch categories
    final inCategories = await dbHelper.getAllEarningTypes();
    final outCategories = await dbHelper.getAllExpenseTypes();

    setState(() {
      transactions = txns;
      cashIn = totalIn;
      cashOut = totalOut;
      balance = bal;

      // Separate categories by type
      _inCategories = inCategories.map((e) => e.name).toList();
      _outCategories = outCategories.map((e) => e.name).toList();
    });
  }

  // Method to show export options dialog
  void _showExportOptions() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Export Cash Expense'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: const Text('Export as PDF'),
                // onTap: () {
                //   Navigator.pop(context);
                //   _exportToPDF();
                // },
              ),
              ListTile(
                leading: const Icon(Icons.table_chart, color: Colors.green),
                title: const Text('Export as Excel'),
                // onTap: () {
                //   Navigator.pop(context);
                //   _exportToExcel();
                // },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  // Method to show more options menu
  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.category, color: Colors.blue),
                title: const Text('Manage Earning Types'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EditEarningTypesScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.category_outlined, color: Colors.orange),
                title: const Text('Manage Expense Types'),
              ),
              ListTile(
                leading: const Icon(Icons.repeat, color: Colors.purple),
                title: const Text('Recurring Transactions'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RecurringTransactionsScreen(),
                    ),
                  ).then((_) => _refreshData());
                },
              ),
              ListTile(
                leading: const Icon(Icons.bar_chart_rounded,
                    color: Color.fromARGB(255, 176, 39, 39)),
                title: const Text('Transaction Trends'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Modified filter method
  void _filterTransactions() async {
    List<Transaction> filteredTxns;

    if (_mainFilter == 'All') {
      filteredTxns = await dbHelper.getAllTransactions();
      _selectedFilter = 'All';
    } else if (_mainFilter == 'Cash In' && _subFilter == null) {
      filteredTxns = await dbHelper.getTransactionsByType('in');
      _selectedFilter = 'Cash In';
    } else if (_mainFilter == 'Cash Out' && _subFilter == null) {
      filteredTxns = await dbHelper.getTransactionsByType('out');
      _selectedFilter = 'Cash Out';
    } else if (_mainFilter == 'Cash In' && _subFilter != null) {
      filteredTxns = await dbHelper.getTransactionsByCategory(_subFilter!);
      _selectedFilter = 'In: $_subFilter';
    } else if (_mainFilter == 'Cash Out' && _subFilter != null) {
      filteredTxns = await dbHelper.getTransactionsByCategory(_subFilter!);
      _selectedFilter = 'Out: $_subFilter';
    } else {
      filteredTxns = await dbHelper.getAllTransactions();
      _selectedFilter = 'All';
    }

    setState(() {
      transactions = filteredTxns;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Builder(
          builder: (context) {
            double screenWidth = MediaQuery.of(context).size.width;
            double fontSize = screenWidth * 0.06;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.bookName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: fontSize,
                  ),
                )
              ],
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            tooltip: 'Monthly Expenses',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const MonthlyExpensesScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.description),
            onPressed: _showExportOptions,
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showMoreOptions,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Cash In (+)'),
                      const SizedBox(height: 5),
                      Text(
                        'Rs ${NumberFormat('#,##0.00').format(cashIn)}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.grey[300],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Cash Out (-)'),
                      const SizedBox(height: 5),
                      Text(
                        'Rs ${NumberFormat('#,##0.00').format(cashOut)}',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.grey[300],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Balance'),
                      const SizedBox(height: 5),
                      Text(
                        'Rs. ${NumberFormat('#,##0.00').format(balance)}',
                        style: TextStyle(
                          color: balance >= 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Text(
                        "Filter: ",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        _selectedFilter,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.black.withOpacity(0.6),
                        ),
                      ),
                      Spacer(),
                    ],
                  ),

                  const SizedBox(height: 5),

                  // Main filter and sub filter buttons in the same row, aligned to the right
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Main filter button
                      Container(
                        width: 100,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: ButtonTheme(
                            alignedDropdown: true,
                            child: PopupMenuButton<String>(
                              onSelected: (String value) {
                                setState(() {
                                  _mainFilter = value;
                                  _subFilter = null;
                                  _showSubFilterButton = (value == 'Cash In' ||
                                      value == 'Cash Out');
                                  _filterTransactions();
                                });
                              },
                              itemBuilder: (BuildContext context) {
                                return [
                                  PopupMenuItem<String>(
                                      value: 'All', child: Text('All')),
                                  PopupMenuItem<String>(
                                      value: 'Cash In', child: Text('Cash In')),
                                  PopupMenuItem<String>(
                                      value: 'Cash Out',
                                      child: Text('Cash Out')),
                                ];
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Filter",
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 14),
                                    ),
                                    SizedBox(width: 5),
                                    Icon(Icons.arrow_drop_down,
                                        color: Colors.white, size: 20),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      // Sub filter button (only show if applicable)
                      if (_showSubFilterButton)
                        Container(
                          width: 110,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _mainFilter == 'Cash In'
                                ? Colors.green
                                : Colors.red,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: ButtonTheme(
                              alignedDropdown: true,
                              child: PopupMenuButton<String>(
                                onSelected: (String value) {
                                  setState(() {
                                    _subFilter = value;
                                    _filterTransactions();
                                  });
                                },
                                itemBuilder: (BuildContext context) {
                                  final categories = _mainFilter == 'Cash In'
                                      ? _inCategories
                                      : _outCategories;
                                  return [
                                    PopupMenuItem<String>(
                                      value: null,
                                      child: Text('All ${_mainFilter}'),
                                    ),
                                    ...categories
                                        .map(
                                            (category) => PopupMenuItem<String>(
                                                  value: category,
                                                  child: Text(category),
                                                ))
                                        .toList(),
                                  ];
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "Category",
                                        style: TextStyle(
                                            color: Colors.white, fontSize: 10),
                                      ),
                                      SizedBox(width: 5),
                                      Icon(Icons.arrow_drop_down,
                                          color: Colors.white, size: 20),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Divider(thickness: 1),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      children: [
                        Text('Showing transactions'),
                        Text(
                          widget.bookName,
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color.fromARGB(255, 158, 158, 158),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Divider(thickness: 1),
                  ),
                ],
              ),
            ),
            Expanded(
              child: transactions.isEmpty
                  ? const Center(child: Text('No transactions yet'))
                  : ListView.builder(
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        final date = DateFormat('E, dd MMM yyyy')
                            .format(transactions[index].dateTime);

                        // Check if we need a date header
                        final showDateHeader = index == 0 ||
                            !DateUtils.isSameDay(transactions[index].dateTime,
                                transactions[index - 1].dateTime);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showDateHeader)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: Text(
                                  date,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              // child: TransactionListItem(
                              //     transaction: transactions[index]),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const CashInScreen()),
                  );
                  _refreshData();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 24, 122, 27),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add,
                      color: Colors.white,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'CASH IN',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  // await Navigator.push(
                  //   context,
                  //   MaterialPageRoute(
                  //       builder: (context) => const CashOutScreen()),
                  // );
                  _refreshData();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 174, 21, 10),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.remove,
                      color: Colors.white,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'CASH OUT',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
