// ignore_for_file: unused_local_variable

import 'dart:io';
import 'package:cash_expense_manager/screens/transaction_trends_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import '../services/database_helper.dart';
import '../widgets/transaction_list_item.dart';
import 'cash_in_screen.dart';
import 'cash_out_screen.dart';
import 'monthly_expenses_screen.dart';
import 'edit_earning_types_screen.dart';
import 'edit_expense_types_screen.dart';
import '../models/recurring_transaction.dart';
import 'recurring_transactions_screen.dart';
import 'cash_pie_chart_screen.dart';
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
                onTap: () {
                  Navigator.pop(context);
                  _exportToPDF();
                },
              ),
              ListTile(
                leading: const Icon(Icons.table_chart, color: Colors.green),
                title: const Text('Export as Excel'),
                onTap: () {
                  Navigator.pop(context);
                  _exportToExcel();
                },
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
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EditExpenseTypesScreen(),
                    ),
                  );
                },
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ExpenseTrendScreen(),
                    ),
                  ).then((_) => _refreshData());
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Method to export data to PDF
  Future<void> _exportToPDF() async {
    // First check if we have permission
    if (!await _checkPermission()) {
      return;
    }

    try {
      // Calculate the start and end dates based on financial start day
      DateTime startDate;
      DateTime endDate;

      // If today is before financial start day, it's previous month's period
      final now = DateTime.now();
      if (now.day < widget.financialStartDay) {
        // Period is from previous month's financial start day to this month's day before financial start
        startDate = DateTime(now.year, now.month - 1, widget.financialStartDay);
        endDate = DateTime(
            now.year, now.month, widget.financialStartDay - 1, 23, 59, 59);
      } else {
        // Period is from this month's financial start day to next month's day before financial start
        startDate = DateTime(now.year, now.month, widget.financialStartDay);
        endDate = DateTime(
            now.year, now.month + 1, widget.financialStartDay - 1, 23, 59, 59);
      }

      // Get financial period display string
      String financialPeriod = _getFinancialPeriodDisplay();

      // Create a PDF document
      final pdf = pw.Document();

      // Add pages to the PDF
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              // Header
              pw.Header(
                level: 0,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Cash Expense Report - ${widget.bookName}',
                        style: pw.TextStyle(
                            fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 5),
                    pw.Text('Period: $financialPeriod',
                        style: pw.TextStyle(fontSize: 14)),
                  ],
                ),
              ),

              pw.SizedBox(height: 10),

              // Summary section
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(5)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Cash In (+)'),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          'Rs ${NumberFormat('#,##0.00').format(cashIn)}',
                          style: pw.TextStyle(
                            color: PdfColors.green,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Cash Out (-)'),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          'Rs ${NumberFormat('#,##0.00').format(cashOut)}',
                          style: pw.TextStyle(
                            color: PdfColors.red,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Balance'),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          'Rs ${NumberFormat('#,##0.00').format(balance)}',
                          style: pw.TextStyle(
                            color:
                                balance >= 0 ? PdfColors.green : PdfColors.red,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Transactions table
              pw.Table.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                cellHeight: 30,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.center,
                  4: pw.Alignment.center,
                },
                headers: [
                  'Date & Time',
                  'Type',
                  'Amount',
                  'Category',
                  'Payment Mode'
                ],
                data: transactions.map((transaction) {
                  return [
                    DateFormat('dd MMM yyyy HH:mm')
                        .format(transaction.dateTime),
                    transaction.transactionTypeName,
                    'Rs ${NumberFormat('#,##0.00').format(transaction.amount)}',
                    transaction.type == 'in' ? 'Cash In' : 'Cash Out',
                    transaction.paymentMode,
                  ];
                }).toList(),
              ),

              pw.SizedBox(height: 20),

              // Footer with date
              pw.Footer(
                title: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Generated on: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())} ',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ];
          },
        ),
      );

      // Save the PDF to a file
      final output = await getTemporaryDirectory();
      final sanitizedBookName = widget.bookName.replaceAll('_', ' ');
      final formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final filePath =
          '${output.path}/Cash Expense Report - $sanitizedBookName - $formattedDate.pdf';

      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      // Show success message and share the file
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('PDF exported successfully'),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () {
              OpenFile.open(filePath);
            },
          ),
        ),
      );

      // Share the file
      await Share.shareFiles([filePath], text: 'Cash Expense Report');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting PDF: ${e.toString()}')),
      );
    }
  }

// Method to export data to Excel
  Future<void> _exportToExcel() async {
    // First check if we have permission
    if (!await _checkPermission()) {
      return;
    }

    try {
      // Calculate the start and end dates based on financial start day
      DateTime startDate;
      DateTime endDate;

      // If today is before financial start day, it's previous month's period
      final now = DateTime.now();
      if (now.day < widget.financialStartDay) {
        // Period is from previous month's financial start day to this month's day before financial start
        startDate = DateTime(now.year, now.month - 1, widget.financialStartDay);
        endDate = DateTime(
            now.year, now.month, widget.financialStartDay - 1, 23, 59, 59);
      } else {
        // Period is from this month's financial start day to next month's day before financial start
        startDate = DateTime(now.year, now.month, widget.financialStartDay);
        endDate = DateTime(
            now.year, now.month + 1, widget.financialStartDay - 1, 23, 59, 59);
      }

      // Get financial period display string
      String financialPeriod = _getFinancialPeriodDisplay();

      // Create Excel workbook and sheet
      final excel = Excel.createExcel();
      final sheet = excel['Cash Expense Report'];

      // Add headers
      final headerStyle = CellStyle(
        backgroundColorHex: getColorFromHex('#CCCCCC'),
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
      );

      // Add title
      sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('E1'));
      final titleCell = sheet.cell(CellIndex.indexByString('A1'));
      titleCell.value = TextCellValue(
        'Cash Expense Report - ${widget.bookName}',
      );
      titleCell.cellStyle = CellStyle(
        bold: true,
        fontSize: 16,
        horizontalAlign: HorizontalAlign.Center,
      );

      // Add period
      sheet.merge(CellIndex.indexByString('A2'), CellIndex.indexByString('E2'));
      final periodCell = sheet.cell(CellIndex.indexByString('A2'));
      periodCell.value = TextCellValue('Period: $financialPeriod');
      periodCell.cellStyle = CellStyle(
        fontSize: 12,
        horizontalAlign: HorizontalAlign.Center,
      );

      // Add summary section
      sheet.merge(CellIndex.indexByString('A4'), CellIndex.indexByString('B4'));
      sheet.cell(CellIndex.indexByString('A4')).value =
          TextCellValue('Cash In (+)');
      sheet.cell(CellIndex.indexByString('A5')).value =
          TextCellValue('Rs ${cashIn.toStringAsFixed(2)}');
      sheet.cell(CellIndex.indexByString('A5')).cellStyle = CellStyle(
        fontColorHex: getColorFromHex('#008000'),
        bold: true,
      );

      sheet.merge(CellIndex.indexByString('C4'), CellIndex.indexByString('D4'));
      sheet.cell(CellIndex.indexByString('C4')).value =
          TextCellValue('Cash Out (-)');
      sheet.cell(CellIndex.indexByString('C5')).value =
          TextCellValue('Rs ${cashOut.toStringAsFixed(2)}');
      sheet.cell(CellIndex.indexByString('C5')).cellStyle = CellStyle(
        fontColorHex: getColorFromHex('#FF0000'),
        bold: true,
      );

      sheet.cell(CellIndex.indexByString('E4')).value =
          TextCellValue('Balance');
      sheet.cell(CellIndex.indexByString('E5')).value =
          TextCellValue('Rs ${NumberFormat('#,##0.00').format(balance)}');
      sheet.cell(CellIndex.indexByString('E5')).cellStyle = CellStyle(
        fontColorHex: getColorFromHex(balance >= 0 ? '#008000' : '#FF0000'),
        bold: true,
      );

      // Add financial start day info
      sheet.merge(CellIndex.indexByString('A7'), CellIndex.indexByString('E7'));
      sheet.cell(CellIndex.indexByString('A7')).value =
          TextCellValue('Financial Start Day: ${widget.financialStartDay}');

      // Add header row for transactions
      final headers = [
        'Date & Time',
        'Type',
        'Amount',
        'Category',
        'Payment Mode'
      ];
      for (var i = 0; i < headers.length; i++) {
        final cell =
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 9));
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = headerStyle;
      }

      // Add transaction data
      for (var i = 0; i < transactions.length; i++) {
        final transaction = transactions[i];
        final row = i + 10; // Starting from row 10 (after headers)

        sheet
                .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
                .value =
            TextCellValue(
                DateFormat('dd MMM yyyy HH:mm').format(transaction.dateTime));

        sheet
                .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
                .value =
            TextCellValue(transaction.transactionTypeName.isEmpty
                ? 'No remark'
                : transaction.transactionTypeName);

        sheet
                .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
                .value =
            TextCellValue(
                'Rs ${NumberFormat('#,##0.00').format(transaction.amount)}');

        sheet
                .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
                .value =
            TextCellValue(transaction.type == 'in' ? 'Cash In' : 'Cash Out');

        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
            .value = TextCellValue(transaction.paymentMode);
      }

      // Auto-fit columns
      for (var i = 0; i < 5; i++) {
        sheet.setColumnWidth(i, 20);
      }

      // Save the Excel file
      final output = await getTemporaryDirectory();
      final sanitizedBookName = widget.bookName.replaceAll('_', ' ');
      final formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final filePath =
          '${output.path}/Cash Expense Report - $sanitizedBookName - $formattedDate.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(excel.encode()!);

      // Show success message and share the file
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Excel exported successfully'),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () {
              OpenFile.open(filePath);
            },
          ),
        ),
      );

      // Share the file
      await Share.shareFiles([filePath], text: 'Cash Expense Report');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting Excel: ${e.toString()}')),
      );
    }
  }

// Helper method to get financial period display string
  String _getFinancialPeriodDisplay() {
    final DateFormat monthFormat = DateFormat('MMM yyyy');
    final now = DateTime.now();

    // If financial start day is 1 (default/regular month), only show month and year
    if (widget.financialStartDay == 1) {
      return DateFormat('MMMM yyyy').format(now);
    }

    // Otherwise show the custom financial period
    DateTime startDate;
    DateTime endDate;

    if (now.day < widget.financialStartDay) {
      // Current view is previous month's period
      startDate = DateTime(now.year, now.month - 1, widget.financialStartDay);
      endDate = DateTime(now.year, now.month, widget.financialStartDay - 1);
    } else {
      // Current view is this month's period
      startDate = DateTime(now.year, now.month, widget.financialStartDay);
      endDate = DateTime(now.year, now.month + 1, widget.financialStartDay - 1);
    }

    return '${widget.financialStartDay} ${monthFormat.format(startDate)} - ${widget.financialStartDay - 1} ${monthFormat.format(endDate)}';
  }

  // Helper method to check permissions
  Future<bool> _checkPermission() async {
    bool hasPermission = false;

    if (Platform.isAndroid) {
      final sdkVersion = await _getAndroidSdkVersion();

      if (sdkVersion >= 30) {
        // Android 11+
        PermissionStatus storageStatus =
            await Permission.manageExternalStorage.status;
        if (!storageStatus.isGranted) {
          storageStatus = await Permission.manageExternalStorage.request();
        }
        hasPermission = storageStatus.isGranted;
      } else {
        // Android 10 and below
        PermissionStatus readStatus = await Permission.storage.status;
        if (!readStatus.isGranted) {
          readStatus = await Permission.storage.request();
        }
        hasPermission = readStatus.isGranted;
      }
    } else {
      // For iOS or other platforms
      hasPermission = true;
    }

    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Storage permission is required to export reports'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () {
              openAppSettings();
            },
          ),
        ),
      );
      return false;
    }

    return true;
  }

  // Helper function to convert hex color string to ExcelColor
  ExcelColor getColorFromHex(String hexString) {
    final hexColor = hexString.replaceAll('#', '');
    // Convert the hex string to an integer
    final colorInt = int.parse(hexColor, radix: 16);
    // Create ExcelColor from the integer value
    return ExcelColor.fromInt(colorInt);
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
            icon: const Icon(Icons.pie_chart),
            tooltip: 'Pie Charts',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CashPieScreen()),
              );
            },
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
                              child: TransactionListItem(
                                  transaction: transactions[index]),
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
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const CashOutScreen()),
                  );
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
