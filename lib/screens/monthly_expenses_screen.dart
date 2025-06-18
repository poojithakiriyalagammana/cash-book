import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expense_cap.dart';
import '../services/database_helper.dart';
// import '../models/transaction.dart';

class MonthlyExpensesScreen extends StatefulWidget {
  const MonthlyExpensesScreen({super.key});

  @override
  _MonthlyExpensesScreenState createState() => _MonthlyExpensesScreenState();
}

class _MonthlyExpensesScreenState extends State<MonthlyExpensesScreen> {
  final dbHelper = DatabaseHelper.instance;
  final TextEditingController _expenseCapController = TextEditingController();
  double _monthlyExpenseCap = 0;
  double _currentMonthExpenses = 0;
  double _currentMonthIncome = 0;
  double _totalBalance = 0;
  bool _isLoading = true;
  bool _isEditing = false;
  late DateTime _currentMonth;
  int _financialStartDay = 1; // Default to 1st day of month

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _loadFinancialSettings().then((_) => _loadData());
  }

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

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    // Load monthly expense cap
    final expenseCap = await dbHelper.getExpenseCap();

    // Calculate the start and end dates based on financial start day
    DateTime startOfMonth;
    DateTime endOfMonth;

    // Get current date for more accurate calculations
    final now = DateTime.now();

    if (_financialStartDay == 1) {
      // Regular month calculation (1st to end of month)
      startOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
      endOfMonth =
          DateTime(_currentMonth.year, _currentMonth.month + 1, 0, 23, 59, 59);
    } else {
      // Financial month calculation
      // We need to determine which financial period the selected month represents

      // If current month view is less than current actual month, or same month but we're after financial start day
      if (_currentMonth.month < now.month ||
          (_currentMonth.month == now.month && now.day >= _financialStartDay)) {
        // Current month's financial period:
        // From current month's financial start day to next month's day before financial start
        startOfMonth = DateTime(
            _currentMonth.year, _currentMonth.month, _financialStartDay);
        endOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1,
            _financialStartDay - 1, 23, 59, 59);
      } else {
        // Previous month's financial period:
        // From previous month's financial start day to current month's day before financial start
        startOfMonth = DateTime(
            _currentMonth.year, _currentMonth.month - 1, _financialStartDay);
        endOfMonth = DateTime(_currentMonth.year, _currentMonth.month,
            _financialStartDay - 1, 23, 59, 59);
      }
    }

    // Debug prints - can be removed in production
    print('Financial Start Day: $_financialStartDay');
    print(
        'Current Month View: ${DateFormat('MMM yyyy').format(_currentMonth)}');
    print(
        'Date Range: ${DateFormat('yyyy-MM-dd').format(startOfMonth)} to ${DateFormat('yyyy-MM-dd').format(endOfMonth)}');

    // Use these dates for retrieving transactions
    final expenses = await dbHelper.getTransactionsByTypeAndDateRange(
        'out', startOfMonth, endOfMonth);
    final totalExpenses = expenses.fold(0.0, (sum, item) => sum + item.amount);

    // Get current month income (cash in)
    final income = await dbHelper.getTransactionsByTypeAndDateRange(
        'in', startOfMonth, endOfMonth);
    final totalIncome = income.fold(0.0, (sum, item) => sum + item.amount);

    // Get total balance
    final balance = await dbHelper.getBalance();

    setState(() {
      _monthlyExpenseCap = expenseCap.amount;
      _expenseCapController.text = _monthlyExpenseCap.toString();
      _currentMonthExpenses = totalExpenses;
      _currentMonthIncome = totalIncome;
      _totalBalance = balance;
      _isLoading = false;
    });
  }

  Future<void> _updateExpenseCap() async {
    if (_expenseCapController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    final double newCap = double.tryParse(_expenseCapController.text) ?? 0.0;

    // Get the current expense cap to preserve its ID
    final currentCap = await dbHelper.getExpenseCap();

    // Update expense cap in the database with the preserved ID
    final expenseCap = ExpenseCap(id: currentCap.id, amount: newCap);
    await dbHelper.updateExpenseCap(expenseCap);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Monthly expense cap updated successfully')),
    );

    setState(() {
      _isEditing = false;
    });

    _loadData();
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
    _loadData();
  }

  void _nextMonth() {
    final now = DateTime.now();
    // Don't allow going beyond the current month
    if (_currentMonth.year < now.year ||
        (_currentMonth.year == now.year && _currentMonth.month < now.month)) {
      setState(() {
        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
      });
      _loadData();
    }
  }

  String _getFinancialPeriodDisplay() {
    final DateFormat monthFormat = DateFormat('MMM yyyy');

    // If financial start day is 1 (default/regular month), only show month and year
    if (_financialStartDay == 1) {
      return DateFormat('MMMM yyyy').format(_currentMonth);
    }

    // Otherwise show the custom financial period
    DateTime startDate;
    DateTime endDate;

    // Get current date for more accurate calculations
    final now = DateTime.now();

    // If current month view is less than current actual month, or same month but we're after financial start day
    if (_currentMonth.month < now.month ||
        (_currentMonth.month == now.month && now.day >= _financialStartDay)) {
      // Current month's financial period
      startDate =
          DateTime(_currentMonth.year, _currentMonth.month, _financialStartDay);
      endDate = DateTime(
          _currentMonth.year, _currentMonth.month + 1, _financialStartDay - 1);
    } else {
      // Previous month's financial period
      startDate = DateTime(
          _currentMonth.year, _currentMonth.month - 1, _financialStartDay);
      endDate = DateTime(
          _currentMonth.year, _currentMonth.month, _financialStartDay - 1);
    }

    return '${DateFormat('d').format(startDate)} ${monthFormat.format(startDate)} - ${DateFormat('d').format(endDate)} ${monthFormat.format(endDate)}';
  }

  Widget _buildFormulaPresentation(
      String formulaTitle, String numerator, String denominator,
      {bool multiply = true}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          formulaTitle,
          style: const TextStyle(
            fontSize: 10,
            color: Color.fromARGB(255, 79, 79, 79),
          ),
        ),
        const SizedBox(width: 4),
        const Text(
          "=",
          style:
              TextStyle(fontSize: 10, color: Color.fromARGB(255, 79, 79, 79)),
        ),
        const SizedBox(width: 4),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                numerator,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            Container(
              height: 1,
              width: 100,
              color: Colors.grey.shade700,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                denominator,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
        if (multiply)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              "× 100",
              style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate Cap Utilization - (Monthly Expenses / Monthly Expense Cap) * 100
    final double capUtilization = _monthlyExpenseCap > 0
        ? (_currentMonthExpenses / _monthlyExpenseCap) * 100
        : 0;

    // Calculate Net Income Percentage - (Monthly Net / Monthly Income) * 100
    final double monthlyNet = _currentMonthIncome - _currentMonthExpenses;
    final double netIncomePercentage =
        _currentMonthIncome > 0 ? (monthlyNet / _currentMonthIncome) * 100 : 0;

    // ignore: unused_local_variable
    final bool isOverBudget =
        _monthlyExpenseCap > 0 && _currentMonthExpenses > _monthlyExpenseCap;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Expenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Month Navigation
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: _previousMonth,
                        ),
                        Text(
                          _getFinancialPeriodDisplay(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: _nextMonth,
                        ),
                      ],
                    ),
                  ),

                  // Financial Summary Card with Gradient
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.blue.shade700,
                          const Color.fromARGB(255, 54, 7, 98),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.5),
                          spreadRadius: 2,
                          blurRadius: 7,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Card(
                      elevation: 0,
                      color: Colors.transparent,
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Financial Summary',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildSummaryItemGradient(
                              'Monthly Income',
                              _currentMonthIncome,
                              const Color.fromARGB(255, 0, 255, 72),
                              valueTextColor: Colors.white,
                            ),
                            _buildSummaryItemGradient(
                              'Monthly Expenses',
                              _currentMonthExpenses,
                              const Color.fromARGB(255, 255, 21, 0),
                              valueTextColor: Colors.white,
                            ),
                            _buildSummaryItemGradient(
                              'Monthly Net',
                              monthlyNet,
                              monthlyNet >= 0
                                  ? const Color.fromARGB(255, 0, 255, 72)
                                  : const Color.fromARGB(255, 255, 21, 0),
                              valueTextColor: Colors.white,
                            ),
                            const Divider(color: Colors.white54, thickness: 1),
                            _buildSummaryItemGradient(
                              'Overall Balance',
                              _totalBalance,
                              _totalBalance >= 0
                                  ? const Color.fromARGB(255, 0, 255, 72)
                                  : const Color.fromARGB(255, 255, 21, 0),
                              isBold: true,
                              valueTextColor: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  //Net Income Percentage Card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white,
                            Colors.greenAccent.withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Net Income Percentage',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // New Formula display with vertical fraction
                            Center(
                              child: _buildFormulaPresentation(
                                'Net Income Percentage',
                                'Monthly Net',
                                'Monthly Income',
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Progress bar for Net Income Percentage
                            LinearProgressIndicator(
                              value: netIncomePercentage > 0
                                  ? netIncomePercentage / 100
                                  : 0,
                              minHeight: 20,
                              backgroundColor: Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                netIncomePercentage >= 0
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Net Income: Rs ${NumberFormat('#,##0.00').format(monthlyNet)} (${netIncomePercentage.toStringAsFixed(1)}% of income)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: netIncomePercentage >= 0
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Analysis
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green[200]!),
                              ),
                              child: const Text(
                                'Analysis: This shows you what percentage of your income is left after expenses. The higher the percentage, the more financial freedom you have.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  // Cap Utilization Card (Previously Monthly Expense Cap)
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.lightBlue.shade50,
                            Colors.deepPurple.shade50,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Cap Utilization',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.indigo,
                                  ),
                                ),
                                if (!_isEditing)
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.indigo),
                                    onPressed: () {
                                      setState(() {
                                        _isEditing = true;
                                      });
                                    },
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Formula display
                            Center(
                              child: _buildFormulaPresentation(
                                'Cap Utilization',
                                'Monthly Expenses',
                                'Monthly Expense Cap',
                              ),
                            ),

                            const SizedBox(height: 16),
                            if (_isEditing)
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _expenseCapController,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Enter Monthly Budget',
                                        border: OutlineInputBorder(),
                                        prefixText: 'Rs ',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  ElevatedButton(
                                    onPressed: _updateExpenseCap,
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.indigo,
                                        foregroundColor: Colors.white),
                                    child: const Text('Save'),
                                  ),
                                ],
                              )
                            else
                              Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Monthly Expense Cap:'),
                                      Text(
                                        'Rs ${NumberFormat('#,##0.00').format(_monthlyExpenseCap)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color.fromARGB(255, 0, 0, 0),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Current Utilization:'),
                                      Text(
                                        '${capUtilization.toStringAsFixed(1)}%',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: capUtilization > 90
                                              ? const Color.fromARGB(
                                                  255, 255, 17, 0)
                                              : const Color.fromARGB(
                                                  255, 0, 118, 22),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.deepPurple.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.deepPurple.shade200),
                                    ),
                                    child: const Text(
                                      'Analysis: This measures how much of your expense cap you are using. If the result is close to 100%, you\'re close to or exceeding your planned limit. If it\'s much lower, you\'re well within your set expenses.',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryItemGradient(
      String title, double amount, Color indicatorColor,
      {bool isBold = false, Color valueTextColor = Colors.white}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: indicatorColor,
                  shape: BoxShape.circle,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
          Text(
            'Rs ${NumberFormat('#,##0.00').format(amount)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: valueTextColor,
            ),
          ),
        ],
      ),
    );
  }
}
