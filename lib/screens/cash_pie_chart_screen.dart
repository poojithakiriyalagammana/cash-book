import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
// import 'dart:math';
import '../services/database_helper.dart';

class CashPieScreen extends StatefulWidget {
  const CashPieScreen({super.key});

  @override
  _CashPieScreenState createState() => _CashPieScreenState();
}

class _CashPieScreenState extends State<CashPieScreen> {
  final dbHelper = DatabaseHelper.instance;
  String _currentView = 'in'; // Default view is cash in (income)
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _transactionData = [];
  double _totalAmount = 0;
  int _financialStartDay = 1; // Default to 1st day of month

  // Professional color palette generator
  Color _getColorForCategory(bool isIncome, int index) {
    // Professional income colors (greens and blues)
    final List<Color> incomeColors = [
      const Color(0xFF00B0FF), // Bright Blue (Vivid Sky Blue)
      const Color(0xFF1DE9B6), // Bright Teal
      const Color(0xFF00C853), // Fresh Green
      const Color(0xFF00E5FF), // Light Cyan
      const Color(0xFF00BFAE), // Turquoise Green
      const Color(0xFF4CAF50), // Standard Green
      const Color(0xFF1976D2), // Strong Blue
      const Color(0xFF1E88E5), // Light Azure
      const Color(0xFF6200EA), // Purple (Deep Violet)
      const Color(0xFF03A9F4), // Light Blue
      const Color(0xFF18FFFF), // Light Turquoise
      const Color(0xFF9C27B0), // Purple (Magenta)
      const Color(0xFF0288D1), // Ocean Blue
      const Color(0xFF00B8D4), // Aqua
      const Color(0xFF00C853), // Fresh Lime Green
    ];

    // Professional expense colors (reds, oranges and purples)
    final List<Color> expenseColors = [
      const Color(0xFFD32F2F), // Strong Red (Danger)
      const Color(0xFF7E57C2), // Lavender Purple
      const Color(0xFF757575), // Gray (Neutral Dark)
      const Color(0xFF455A64), // Charcoal (Deep Grayish Blue)
      const Color(0xFFF44336), // Bright Red (Fire Engine)
      const Color(0xFFAB47BC), // Purple (Deep Violet)
      const Color(0xFFE64A19), // Orange-Red (Alert)
      const Color(0xFFF57C00), // Amber (Orange)
      const Color(0xFF9E9D24), // Olive (Neutral Yellow-Green)
      const Color(0xFFFF7043), // Coral (Soft Red-Orange)
      const Color(0xFFEF5350), // Light Red (Warning)
      const Color(0xFF616161), // Slate Gray (Dark Gray)
      const Color(0xFFB71C1C), // Blood Red (Deep Red)
      const Color(0xFFB53D3D), // Dark Maroon
      const Color(0xFF8E24AA), // Fuchsia Purple
    ];

    final colors = isIncome ? incomeColors : expenseColors;
    return colors[index % colors.length];
  }

  @override
  void initState() {
    super.initState();
    _loadFinancialSettings();
    _refreshData();
  }

  Future<void> _refreshData() async {
    final data = await _loadTransactionData();

    setState(() {
      _transactionData = data;
      _calculateTotal();
    });
  }

  // Updated method to handle null values properly
  Future<void> _loadFinancialSettings() async {
    try {
      // Load the current active book
      final currentBook = await dbHelper.getCurrentBook();
      if (currentBook != null) {
        setState(() {
          // Use the financial start day from book or default to 1
          _financialStartDay = currentBook.financialStartDay;
        });
      }
    } catch (e) {
      print('Error loading financial settings: $e');
      // Keep using default value (1) in case of error
    }
  }

  Future<List<Map<String, dynamic>>> _loadTransactionData() async {
    // Calculate financial month start and end dates based on selected date
    DateTime firstDay;
    DateTime lastDay;

    // If selected day is before financial start day, it's previous month's period
    if (_selectedDate.day < _financialStartDay) {
      // Period is from previous month's financial start day to this month's day before financial start
      firstDay = DateTime(
          _selectedDate.year, _selectedDate.month - 1, _financialStartDay);
      lastDay = DateTime(
          _selectedDate.year, _selectedDate.month, _financialStartDay - 1);
    } else {
      // Period is from this month's financial start day to next month's day before financial start
      firstDay =
          DateTime(_selectedDate.year, _selectedDate.month, _financialStartDay);
      lastDay = DateTime(
          _selectedDate.year, _selectedDate.month + 1, _financialStartDay - 1);
    }

    // Get all transactions for the selected financial month
    final allTransactions = await dbHelper.getTransactionCounts(
      startDate: firstDay,
      endDate: lastDay,
    );

    // Check if allTransactions is null or empty, if so return an empty list
    if (allTransactions == []) {
      return [];
    }

    // Filter transactions by type (in/out)
    final filteredTransactions =
        allTransactions.where((txn) => txn['type'] == _currentView).toList();

    // Group transactions by type and calculate totals
    final Map<int, Map<String, dynamic>> groupedData = {};

    for (var txn in filteredTransactions) {
      final typeId = txn['transaction_type_id'];
      final typeName = txn['transactionTypeName'];
      final amount = txn['amount'] as double;

      if (groupedData.containsKey(typeId)) {
        groupedData[typeId]!['amount'] += amount;
      } else {
        groupedData[typeId] = {
          'transaction_type_id': typeId,
          'typeName': typeName,
          'amount': amount,
          'color': null, // Will be assigned later
        };
      }
    }
    // Convert to list and sort by amount
    final result = groupedData.values.toList();
    result.sort(
        (a, b) => (b['amount'] as double).compareTo(a['amount'] as double));

    // Assign colors based on index
    for (int i = 0; i < result.length; i++) {
      result[i]['color'] = _getColorForCategory(_currentView == 'in', i);
    }

    return result;
  }

  void _calculateTotal() {
    _totalAmount = _transactionData.fold(
        0, (sum, item) => sum + (item['amount'] as double? ?? 0));
  }

  void _changeView(String view) {
    if (_currentView != view) {
      setState(() {
        _currentView = view;
      });
      _refreshData();
    }
  }

  void _previousMonth() {
    setState(() {
      _selectedDate = DateTime(
          _selectedDate.year, _selectedDate.month - 1, _selectedDate.day);
    });
    _refreshData();
  }

  void _nextMonth() {
    final nextMonth = DateTime(
        _selectedDate.year, _selectedDate.month + 1, _selectedDate.day);

    // Don't allow selecting future months beyond current date
    if (!nextMonth.isAfter(DateTime.now())) {
      setState(() {
        _selectedDate = nextMonth;
      });
      _refreshData();
    }
  }

  // Function to dynamically adjust font size based on text length
  double _getResponsiveFontSize(String text, double baseSize) {
    if (text.length > 10) {
      return baseSize * 0.8;
    } else if (text.length > 15) {
      return baseSize * 0.7;
    }
    return baseSize;
  }

  @override
  Widget build(BuildContext context) {
    // final screenWidth = MediaQuery.of(context).size.width;
    // final isSmallScreen = screenWidth < 360;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cash Summary'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: Column(
        children: [
          // View toggle buttons (Cash In / Cash Out)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: _buildToggleButton(
                    'CASH IN',
                    'in',
                    const Color(0xFF4CAF50),
                    Colors.green.withOpacity(0.1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildToggleButton(
                    'CASH OUT',
                    'out',
                    const Color(0xFFE53935),
                    Colors.red.withOpacity(0.1),
                  ),
                ),
              ],
            ),
          ),

          // Date navigation
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _previousMonth,
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      _getFinancialPeriodDisplay(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _nextMonth,
                ),
              ],
            ),
          ),

          // Pie Chart Section
          Expanded(
            child: _transactionData.isEmpty
                ? _buildEmptyState()
                : Column(
                    children: [
                      // Pie Chart
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.3,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 70,
                                borderData: FlBorderData(show: false),
                                sections: _getPieChartSections(),
                                pieTouchData: PieTouchData(
                                  touchCallback: (event, pieTouchResponse) {
                                    // Handle touch events if needed
                                  },
                                ),
                              ),
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Rs ${NumberFormat('#,##0.00').format(_totalAmount)}',
                                    style: TextStyle(
                                      fontSize: _getResponsiveFontSize(
                                          _totalAmount.toString(), 20),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _currentView == 'in'
                                        ? Colors.green.withOpacity(0.1)
                                        : Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _currentView == 'in' ? 'Income' : 'Expense',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _currentView == 'in'
                                          ? Colors.green[700]
                                          : Colors.red[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Legend title
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Row(
                          children: [
                            Text(
                              _currentView == 'in'
                                  ? 'Income Categories'
                                  : 'Expense Categories',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Text(
                                'LIST VIEW',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Divider(height: 1),

                      // Category List
                      Expanded(
                        child: ListView.builder(
                          itemCount: _transactionData.length,
                          itemBuilder: (context, index) {
                            final item = _transactionData[index];
                            final double percentage =
                                (item['amount'] / _totalAmount) * 100;
                            final amountText =
                                'Rs ${NumberFormat('#,##0.00').format(item['amount'])}';
                            final percentText =
                                '${percentage.toStringAsFixed(1)}%';

                            return ListTile(
                              leading: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: item['color'],
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: item['color'].withOpacity(0.4),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                              title: Text(
                                item['typeName'] ?? 'Other',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    percentText,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    amountText,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: _getResponsiveFontSize(
                                          amountText, 16),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(
      String text, String value, Color activeColor, Color activeBgColor) {
    final isActive = _currentView == value;

    return Material(
      color: isActive ? activeBgColor : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _changeView(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? activeColor : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isActive ? activeColor : Colors.grey[600],
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _currentView == 'in'
                ? Icons.account_balance_wallet
                : Icons.shopping_cart,
            size: 60,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No ${_currentView == 'in' ? 'income' : 'expense'} data available',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Transactions added this month will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _getPieChartSections() {
    return List.generate(_transactionData.length, (index) {
      final item = _transactionData[index];
      final double percentage = (item['amount'] / _totalAmount) * 100;

      // Show percentage label only for sections larger than 5%
      final showTitle = percentage >= 5.0;

      return PieChartSectionData(
        color: item['color'],
        value: item['amount'].toDouble(),
        title: showTitle ? '${percentage.toStringAsFixed(0)}%' : '',
        radius: 45,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: [
            Shadow(
              offset: Offset(0, 1),
              blurRadius: 2,
              color: Color(0x80000000),
            ),
          ],
        ),
        badgeWidget: percentage < 5.0 ? const SizedBox.shrink() : null,
        badgePositionPercentageOffset: 0.8,
      );
    });
  }

  String _getFinancialPeriodDisplay() {
    final DateFormat monthFormat = DateFormat('MMM yyyy');

    // If financial start day is 1 (default/regular month), only show month and year
    if (_financialStartDay == 1) {
      return DateFormat('MMMM yyyy').format(_selectedDate);
    }

    // Otherwise show the custom financial period
    DateTime startDate;
    DateTime endDate;

    if (_selectedDate.day < _financialStartDay) {
      // Current view is previous month's period
      startDate = DateTime(
          _selectedDate.year, _selectedDate.month - 1, _financialStartDay);
      endDate = DateTime(
          _selectedDate.year, _selectedDate.month, _financialStartDay - 1);
    } else {
      // Current view is this month's period
      startDate =
          DateTime(_selectedDate.year, _selectedDate.month, _financialStartDay);
      endDate = DateTime(
          _selectedDate.year, _selectedDate.month + 1, _financialStartDay - 1);
    }

    return '${_financialStartDay} ${monthFormat.format(startDate)} - ${_financialStartDay - 1} ${monthFormat.format(endDate)}';
  }
}
