import 'package:cash_expense_manager/screens/cash_book_screen.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';

class ExpenseTrendScreen extends StatefulWidget {
  const ExpenseTrendScreen({super.key});

  @override
  State<ExpenseTrendScreen> createState() => _ExpenseTrendScreenState();
}

class _ExpenseTrendScreenState extends State<ExpenseTrendScreen> {
  final dbHelper = DatabaseHelper.instance;
  String _currentPeriod = '3M'; // Default view is 3 months
  List<Map<String, dynamic>> _expenseData = [];
  double _totalExpense = 0;
  double _maxMonthlyExpense = 0;
  DateTime _endDate = DateTime.now();
  List<Color> _monthColors = [];
  bool _isLoading = true;
  int _financialStartDay = 1; // Default to 1st day of month
  bool _showIncome = true; // Default to showing income

  // Professional color palette for months
  final List<Color> _colorPalette = [
    const Color(0xFF4A6FF3), // Blue
    const Color(0xFF9747FF), // Purple
    const Color(0xFFFA5F8B), // Pink
    const Color(0xFFFF8D5C), // Orange
    const Color(0xFF3CD856), // Green
    const Color(0xFF2BCDF0), // Cyan
    const Color(0xFFFFC107), // Amber
    const Color(0xFF607D8B), // Blue Gray
    const Color(0xFF795548), // Brown
    const Color(0xFF9C27B0), // Deep Purple
    const Color(0xFF00BCD4), // Light Blue
    const Color(0xFFE91E63), // Deep Pink
  ];

  @override
  void initState() {
    super.initState();
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

    // Calculate dates based on selected period
    DateTime startDate;
    DateTime endDate = DateTime(_endDate.year, _endDate.month, _endDate.day);

    // Calculate start date based on selected period similar to CashPieScreen approach
    switch (_currentPeriod) {
      case '3M':
        // Last 3 months
        if (endDate.day < _financialStartDay) {
          // If current day is before financial start day, start from 3 months ago
          startDate =
              DateTime(endDate.year, endDate.month - 3, _financialStartDay);
        } else {
          // If current day is on or after financial start day, start from 2 months ago
          startDate =
              DateTime(endDate.year, endDate.month - 2, _financialStartDay);
        }
        break;
      case '6M':
        // Last 6 months
        if (endDate.day < _financialStartDay) {
          // If current day is before financial start day, start from 6 months ago
          startDate =
              DateTime(endDate.year, endDate.month - 6, _financialStartDay);
        } else {
          // If current day is on or after financial start day, start from 5 months ago
          startDate =
              DateTime(endDate.year, endDate.month - 5, _financialStartDay);
        }
        break;
      case '1Y':
        // Last 12 months
        if (endDate.day < _financialStartDay) {
          // If current day is before financial start day, start from 12 months ago
          startDate =
              DateTime(endDate.year - 1, endDate.month, _financialStartDay);
        } else {
          // If current day is on or after financial start day, start from 11 months ago
          startDate =
              DateTime(endDate.year - 1, endDate.month + 1, _financialStartDay);
        }
        break;
      default:
        // Default to 3 months
        startDate =
            DateTime(endDate.year, endDate.month - 2, _financialStartDay);
    }

    // Last day of current month for end date calculation
    final lastDayOfMonth = DateTime(_endDate.year, _endDate.month + 1, 0);

    // If current day is before financial start day, adjust end date to previous month's financial end
    if (endDate.day < _financialStartDay) {
      endDate = DateTime(endDate.year, endDate.month, _financialStartDay - 1);
    } else {
      // Otherwise, end date is the financial end of the current month
      endDate =
          DateTime(endDate.year, endDate.month + 1, _financialStartDay - 1);
    }

    // Get monthly data based on whether we're showing income or expenses
    final monthlyData = _showIncome
        ? await _getMonthlyIncomeData(startDate, lastDayOfMonth)
        : await _getMonthlyExpenseData(startDate, lastDayOfMonth);

    // Calculate total and maximum monthly amount
    double total = 0;
    double maxMonthly = 0;

    for (var data in monthlyData) {
      total += data['amount'];
      if (data['amount'] > maxMonthly) {
        maxMonthly = data['amount'];
      }
    }
    final filteredData =
        monthlyData.where((item) => item['amount'] > 0).toList();

    // Generate colors for each month
    final List<Color> monthColors = [];
    for (int i = 0; i < monthlyData.length; i++) {
      monthColors.add(_colorPalette[i % _colorPalette.length]);
    }

    // Ensure we have at least some value for maxMonthly to avoid division by zero
    if (maxMonthly == 0) {
      maxMonthly = 1000;
    }

    setState(() {
      _expenseData = filteredData;
      _totalExpense = total;
      _maxMonthlyExpense = maxMonthly;
      _monthColors = monthColors;
      _isLoading = false;
    });
  }

  Future<List<Map<String, dynamic>>> _getMonthlyExpenseData(
      DateTime startDate, DateTime endDate) async {
    final List<Map<String, dynamic>> monthlyData = [];

    // Start with financial month that includes the start date
    DateTime current;
    if (startDate.day < _financialStartDay) {
      // We're in the previous month's financial period
      current =
          DateTime(startDate.year, startDate.month - 1, _financialStartDay);
    } else {
      // We're in the current month's financial period
      current = DateTime(startDate.year, startDate.month, _financialStartDay);
    }

    // Iterate through financial months until end date
    while (current.isBefore(endDate)) {
      final monthStartDate = current;
      final monthEndDate = DateTime(
          current.year, current.month + 1, _financialStartDay - 1, 23, 59, 59);

      // Query database for sum of expenses in this financial month
      final expenses = await dbHelper.getTotalExpenseForPeriod(
        startDate: monthStartDate,
        endDate: monthEndDate,
      );

      // Format the month label to indicate financial month
      String monthLabel;
      if (_financialStartDay == 1) {
        // Regular calendar month
        monthLabel = DateFormat('MMM yyyy').format(current);
      } else {
        // Financial month spanning two calendar months
        final monthEndFormatted = DateFormat('dd MMM').format(monthEndDate);
        monthLabel =
            '${DateFormat('dd MMM').format(current)} - $monthEndFormatted';
      }

      String shortMonthLabel;
      if (_financialStartDay == 1) {
        // Regular calendar month
        shortMonthLabel = DateFormat('MMM').format(current);
      } else {
        // Financial month - show abbreviated format
        shortMonthLabel = DateFormat('dd/MM').format(current);
      }

      monthlyData.add({
        'month': monthLabel,
        'shortMonth': shortMonthLabel,
        'amount': expenses,
        'date': monthStartDate,
        'endDate': monthEndDate,
      });

      // Move to next financial month
      current =
          DateTime(monthEndDate.year, monthEndDate.month, monthEndDate.day + 1);
    }

    return monthlyData;
  }

  // New method for getting monthly income data
  Future<List<Map<String, dynamic>>> _getMonthlyIncomeData(
      DateTime startDate, DateTime endDate) async {
    final List<Map<String, dynamic>> monthlyData = [];

    // Start with financial month that includes the start date
    DateTime current;
    if (startDate.day < _financialStartDay) {
      // We're in the previous month's financial period
      current =
          DateTime(startDate.year, startDate.month - 1, _financialStartDay);
    } else {
      // We're in the current month's financial period
      current = DateTime(startDate.year, startDate.month, _financialStartDay);
    }

    // Iterate through financial months until end date
    while (current.isBefore(endDate)) {
      final monthStartDate = current;
      final monthEndDate = DateTime(
          current.year, current.month + 1, _financialStartDay - 1, 23, 59, 59);

      // Query database for sum of income in this financial month
      final income = await dbHelper.getTotalIncomeForPeriod(
        startDate: monthStartDate,
        endDate: monthEndDate,
      );

      // Format the month label to indicate financial month
      String monthLabel;
      if (_financialStartDay == 1) {
        // Regular calendar month
        monthLabel = DateFormat('MMM yyyy').format(current);
      } else {
        // Financial month spanning two calendar months
        final monthEndFormatted = DateFormat('dd MMM').format(monthEndDate);
        monthLabel =
            '${DateFormat('dd MMM').format(current)} - $monthEndFormatted';
      }

      String shortMonthLabel;
      if (_financialStartDay == 1) {
        // Regular calendar month
        shortMonthLabel = DateFormat('MMM').format(current);
      } else {
        // Financial month - show abbreviated format
        shortMonthLabel = DateFormat('dd/MM').format(current);
      }

      monthlyData.add({
        'month': monthLabel,
        'shortMonth': shortMonthLabel,
        'amount': income,
        'date': monthStartDate,
        'endDate': monthEndDate,
      });

      // Move to next financial month
      current =
          DateTime(monthEndDate.year, monthEndDate.month, monthEndDate.day + 1);
    }

    return monthlyData;
  }

  bool isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  void _changePeriod(String period) {
    if (_currentPeriod != period) {
      setState(() {
        _currentPeriod = period;
      });
      _loadData();
    }
  }

  // New method to toggle between income and expense view
  void _toggleView(bool showIncome) {
    if (_showIncome != showIncome) {
      setState(() {
        _showIncome = showIncome;
      });
      _loadData();
    }
  }

  String _formatLargeAmount(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return amount.toStringAsFixed(0);
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,##,##0');
    return 'Rs ${formatter.format(amount)}';
  }

  // financial period display
  String _getFinancialPeriodFormatted(Map<String, dynamic> data) {
    if (_financialStartDay == 1) {
      // Regular calendar month
      return data['month'];
    } else {
      // Financial month
      final startDate = data['date'] as DateTime;
      final endDate = data['endDate'] as DateTime;
      // return '${DateFormat('dd MMM yyyy').format(startDate)} - ${DateFormat('dd MMM yyyy').format(endDate)}';
      return '${_financialStartDay} ${DateFormat('MMM').format(startDate)} - ${_financialStartDay - 1} ${DateFormat('MMM').format(endDate)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _showIncome ? 'Income Trends' : 'Expense Trends',
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black54),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Income/Expense toggle buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      _buildViewToggle(true, 'Income'),
                      const SizedBox(width: 10),
                      _buildViewToggle(false, 'Expenses'),
                    ],
                  ),
                ),

                // Period selector
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Row(
                    children: [
                      _buildPeriodToggle('3M', 'Last 3 Months'),
                      const SizedBox(width: 10),
                      _buildPeriodToggle('6M', 'Last 6 Months'),
                      const SizedBox(width: 10),
                      _buildPeriodToggle('1Y', 'Last Year'),
                    ],
                  ),
                ),

                // Total card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildTotalCard(),
                ),

                const SizedBox(height: 24),

                // Chart title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        'Monthly Breakdown',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Tap bars for details',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                _expenseData.isEmpty
                    ? SizedBox(
                        height: 300,
                        child: _buildEmptyState(),
                      )
                    : _buildChartSection(constraints.maxWidth),

                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  // New method to build income/expense toggle buttons
  Widget _buildViewToggle(bool isIncome, String label) {
    final isActive = _showIncome == isIncome;

    return Expanded(
      child: InkWell(
        onTap: () => _toggleView(isIncome),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive
                ? (isIncome
                    ? const Color(0xFF2E7D32) // Green for Income
                    : const Color(0xFFD32F2F)) // Red for Expense
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: (isIncome
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFD32F2F))
                          .withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.black54,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodToggle(String value, String label) {
    final isActive = _currentPeriod == value;
    final activeColor = _showIncome
        ? const Color(0xFF2E7D32) // Green for Income
        : const Color(0xFFD32F2F); // Red for Expense

    return Expanded(
      child: InkWell(
        onTap: () => _changePeriod(value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive
                ? activeColor.withOpacity(0.9)
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: activeColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.black54,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTotalCard() {
    // Get period display text based on selected period
    String periodText;
    switch (_currentPeriod) {
      case '3M':
        periodText = 'Last 3 Months';
        break;
      case '6M':
        periodText = 'Last 6 Months';
        break;
      case '1Y':
        periodText = 'Last 12 Months';
        break;
      default:
        periodText = 'Last 3 Months';
    }

    // Set gradient colors based on income or expense view
    List<Color> gradientColors = _showIncome
        ? [
            const Color(0xFF2E7D32), // Dark Green
            const Color(0xFF4CAF50), // Light Green
          ]
        : [
            const Color(0xFFD32F2F), // Dark Red
            const Color(0xFFE57373), // Light Red
          ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _financialStartDay == 1
                    ? (_currentPeriod == '1Y'
                        ? 'Yearly ${_showIncome ? "Income" : "Expense"}'
                        : 'Period ${_showIncome ? "Income" : "Expense"}')
                    : 'Financial Period ${_showIncome ? "Income" : "Expense"}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  periodText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _formatCurrency(_totalExpense),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Avg: ${_formatCurrency(_expenseData.isEmpty ? 0 : _totalExpense / _expenseData.length)} per month',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection(double screenWidth) {
    // Calculate appropriate bar width based on screen width and number of months
    double barWidth = (screenWidth - 80) / _expenseData.length;
    barWidth = barWidth.clamp(15.0, 30.0); // Min 15, max 30

    final double chartHeight = 300.0;

    return Column(
      children: [
        // Chart
        Container(
          height: chartHeight,
          padding: const EdgeInsets.only(top: 10, right: 16, left: 16),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: _maxMonthlyExpense * 1.2,
              minY: 0,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  tooltipBgColor: Colors.blueGrey.shade800,
                  tooltipPadding: const EdgeInsets.all(8),
                  tooltipMargin: 8,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      _getFinancialPeriodFormatted(_expenseData[groupIndex]) +
                          '\n',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      children: [
                        TextSpan(
                          text: _formatCurrency(
                              _expenseData[groupIndex]['amount']),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                touchCallback: (FlTouchEvent event, barTouchResponse) {},
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value < 0 || value >= _expenseData.length) {
                        return const SizedBox();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _expenseData[value.toInt()]['shortMonth'],
                          style: const TextStyle(
                            color: Colors.black54,
                            fontWeight: FontWeight.w500,
                            fontSize: 8,
                          ),
                        ),
                      );
                    },
                    reservedSize: 30,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 55,
                    interval: _calculateOptimalInterval(_maxMonthlyExpense),
                    getTitlesWidget: (value, meta) {
                      if (value == 0) {
                        return const SizedBox();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          _formatLargeAmount(value),
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border(
                  left: BorderSide(color: Colors.grey.withOpacity(0.2)),
                  bottom: BorderSide(color: Colors.grey.withOpacity(0.2)),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval:
                    _calculateOptimalInterval(_maxMonthlyExpense),
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey.withOpacity(0.15),
                    strokeWidth: 1,
                  );
                },
              ),
              barGroups: List.generate(_expenseData.length, (index) {
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: _expenseData[index]['amount'],
                      color: _monthColors[index],
                      width: barWidth,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(6),
                        topRight: Radius.circular(6),
                      ),
                    ),
                  ],
                );
              }),
            ),
            swapAnimationDuration: const Duration(milliseconds: 300),
          ),
        ),

        // Month legend with totals - horizontally scrollable
        Container(
          height: 120,
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _expenseData.length,
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _monthColors[index],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _getFinancialPeriodFormatted(_expenseData[index]),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatCurrency(_expenseData[index]['amount']),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _monthColors[index],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(_expenseData[index]['amount'] / _totalExpense * 100).toStringAsFixed(1)}% of total',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Calculate optimal interval for Y-axis grid lines
  double _calculateOptimalInterval(double maxValue) {
    if (maxValue <= 0) return 1000;

    final double rawInterval = maxValue / 5; // Aim for ~5 intervals

    // Round to appropriate magnitude
    if (rawInterval >= 1000000) {
      return (rawInterval / 1000000).ceil() * 1000000;
    } else if (rawInterval >= 100000) {
      return (rawInterval / 100000).ceil() * 100000;
    } else if (rawInterval >= 10000) {
      return (rawInterval / 10000).ceil() * 10000;
    } else if (rawInterval >= 1000) {
      return (rawInterval / 1000).ceil() * 1000;
    } else if (rawInterval >= 100) {
      return (rawInterval / 100).ceil() * 100;
    } else {
      return (rawInterval / 10).ceil() * 10;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.bar_chart,
              size: 70,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Transaction data available',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'We\'ll show your Transaction trends here once you add transactions',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5E35B1),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              // Get the current active book
              final currentBook = await dbHelper.getCurrentBook();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CashBookScreen(
                    bookName: currentBook?.name ?? '',
                  ),
                ),
              );
            },
            child: const Text(
              'Add Transaction',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
