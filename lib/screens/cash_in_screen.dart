// import 'package:cash_expense_manager/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/recurring_transaction.dart';
import '../services/database_helper.dart';
import '../widgets/custom_numpad.dart';
import 'package:cash_expense_manager/models/transaction_type.dart';

class CashInScreen extends StatefulWidget {
  final Transaction? transaction;
  final RecurringTransaction? recurringTransaction;
  const CashInScreen({super.key, this.transaction, this.recurringTransaction});

  @override
  _CashInScreenState createState() => _CashInScreenState();
}

class _CashInScreenState extends State<CashInScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _partyNameController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _paymentMode = 'Cash';
  bool _showNumpad = true;
  bool _isEditing = false;
  bool _isEditingRecurring = false;

  // Recurring transaction fields
  String _selectedTransactionType = "Other Income";
  bool _isRecurring = false;
  int _recurringDay = DateTime.now().day;
  bool _enableNotifications = true;
  int? _recurringTransactionId;

  @override
  void initState() {
    super.initState();
    // Check if we're editing an existing transaction
    if (widget.transaction != null) {
      _isEditing = true;
      _loadTransactionData();
    } else if (widget.recurringTransaction != null) {
      _isEditingRecurring = true;
      _loadRecurringTransactionData();
    }
  }

  void _loadTransactionData() async {
    final transaction = widget.transaction!;

    // Load amount
    _amountController.text = transaction.amount.toString();

    // Load note if it exists
    if (transaction.note != null && transaction.note!.isNotEmpty) {
      _noteController.text = transaction.note!;
    }

    // Load date and time
    _selectedDate = transaction.dateTime;
    _selectedTime = TimeOfDay(
      hour: transaction.dateTime.hour,
      minute: transaction.dateTime.minute,
    );

    // Load payment mode
    _paymentMode = transaction.paymentMode;

    // Load transaction type/category
    if (transaction.transactionTypeName.isNotEmpty) {
      _selectedTransactionType = transaction.transactionTypeName;
    }

    // Check if this transaction has an associated recurring transaction
    final RecurringTransaction? associatedRecurring = await DatabaseHelper
        .instance
        .getRecurringTransactionByTransactionProperties(transaction);

    if (associatedRecurring != null) {
      // Set the recurring toggle on
      setState(() {
        _isRecurring = true;
        _recurringTransactionId = associatedRecurring.id;
        _recurringDay = associatedRecurring.dayOfMonth;
        // Default notifications to true as we don't store this preference
        _enableNotifications = true;
      });
    }
  }

  void _loadRecurringTransactionData() {
    final recurringTransaction = widget.recurringTransaction!;

    // Store recurring transaction ID
    _recurringTransactionId = recurringTransaction.id;

    // Load amount
    _amountController.text = recurringTransaction.amount.toString();

    // Load note if it exists
    if (recurringTransaction.note != null &&
        recurringTransaction.note!.isNotEmpty) {
      _noteController.text = recurringTransaction.note!;
    }

    // Load date from start date
    _selectedDate = recurringTransaction.startDate;
    _selectedTime = TimeOfDay(
      hour: recurringTransaction.startDate.hour,
      minute: recurringTransaction.startDate.minute,
    );

    // Load payment mode
    _paymentMode = recurringTransaction.paymentMode;

    // Load transaction type/category
    if (recurringTransaction.transactionTypeName.isNotEmpty) {
      _selectedTransactionType = recurringTransaction.transactionTypeName;
    }

    // Set recurring fields
    _isRecurring = true;
    _recurringDay = recurringTransaction.dayOfMonth;
    // Default to true for notifications as we don't store this preference
    _enableNotifications = true;
  }

  void _resetForm() {
    setState(() {
      _amountController.clear();
      _noteController.clear();
      _partyNameController.clear();
      _selectedDate = DateTime.now();
      _selectedTime = TimeOfDay.now();
      _paymentMode = 'Cash';
      _selectedTransactionType = "Other Income";
      _isRecurring = false;
      _recurringDay = DateTime.now().day;
      _enableNotifications = true;
      _showNumpad = true;
    });
  }

  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_isInitialized && !_isEditing && !_isEditingRecurring) {
      _resetForm();
      _isInitialized = true; // prevent future resets
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing
            ? 'Edit Cash In'
            : _isEditingRecurring
                ? 'Edit Recurring Income'
                : 'Cash In Transaction'),
        backgroundColor: const Color.fromARGB(255, 24, 122, 27),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date and Time Picker
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today,
                                      color: Colors.blue[400], size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      DateFormat('dd MMM yyyy')
                                          .format(_selectedDate),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                  const Icon(Icons.arrow_drop_down, size: 18),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectTime(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.access_time,
                                      color: Colors.blue[400], size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _selectedTime.format(context),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                  const Icon(Icons.arrow_drop_down, size: 18),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Amount Input
                    TextField(
                      controller: _amountController,
                      readOnly: true,
                      onTap: () {
                        setState(() {
                          _showNumpad = true;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Enter Amount',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                        suffixIcon: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            '+ × - =',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      style: const TextStyle(fontSize: 16),
                    ),

                    const SizedBox(height: 16),

                    // Transaction Type Dropdown
                    const Text(
                      'Income Category',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<List<TransactionType>>(
                      future: DatabaseHelper.instance
                          .getTransactionTypesByCategory('in'),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        }

                        final items = snapshot.data ?? [];
                        bool otherIncomeExists =
                            items.any((item) => item.name == "Other Income");
                        final List<DropdownMenuItem<String>> dropdownItems = [
                          // Always add "Other Income" as the first item
                          DropdownMenuItem(
                            value: "Other Income",
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Other Income"),
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    // Only show dialog when pencil icon is clicked
                                    _showAddCategoryDialog();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ];

                        if (!otherIncomeExists) {
                          dropdownItems.add(const DropdownMenuItem(
                            value: "Other Income",
                            child: Text("Other Income"),
                          ));
                        }

                        dropdownItems.addAll(items
                            .where((type) => type.name != "Other Income")
                            .map((type) => DropdownMenuItem(
                                  value: type.name,
                                  child: Text(type.name),
                                )));

                        return Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: DropdownButtonFormField<String>(
                            value: _selectedTransactionType,
                            decoration: const InputDecoration(
                              contentPadding:
                                  EdgeInsets.symmetric(horizontal: 12),
                              border: InputBorder.none,
                            ),
                            items: dropdownItems,
                            onChanged: (value) {
                              setState(() {
                                _selectedTransactionType = value!;
                              });
                            },
                            isExpanded: true,
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 16),
                    // Note Input Field
                    TextField(
                      controller: _noteController,
                      decoration: InputDecoration(
                        labelText: 'Note (Optional)',
                        hintText: 'Add a note about this transaction',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      // maxLines: 20,
                      onTap: () {
                        setState(() {
                          _showNumpad = false;
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    // Payment Mode
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 1, vertical: 1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Payment mode',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _paymentMode = 'Cash';
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _paymentMode == 'Cash'
                                      ? Colors.blue
                                      : Colors.grey[300],
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  minimumSize:
                                      const Size(70, 35), // Reduced button size
                                ),
                                child: Text(
                                  'Cash',
                                  style: TextStyle(
                                    fontSize: 12, // Reduced font size
                                    color: _paymentMode == 'Cash'
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _paymentMode = 'Online';
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _paymentMode == 'Online'
                                      ? Colors.blue
                                      : Colors.grey[300],
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  minimumSize:
                                      const Size(70, 35), // Reduced button size
                                ),
                                child: Text(
                                  'Online',
                                  style: TextStyle(
                                    fontSize: 12, // Reduced font size
                                    color: _paymentMode == 'Online'
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Recurring Transaction Toggle - show for new transactions or when editing a recurring transaction
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Recurring Transaction',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Switch(
                              value: _isRecurring,
                              onChanged: (value) {
                                setState(() {
                                  _isRecurring = value;
                                });
                              },
                              activeColor: Colors.blue,
                            ),
                            const Expanded(
                              child: Text(
                                'Set as monthly recurring transaction',
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                        if (_isRecurring)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              const Text(
                                'Day of month for recurring transaction:',
                                style: TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 40,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: 31,
                                  itemBuilder: (context, index) {
                                    final day = index + 1;
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _recurringDay = day;
                                        });
                                      },
                                      child: Container(
                                        width: 35,
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 2),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _recurringDay == day
                                              ? Colors.blue
                                              : Colors.grey[200],
                                        ),
                                        child: Center(
                                          child: Text(
                                            day.toString(),
                                            style: TextStyle(
                                              color: _recurringDay == day
                                                  ? Colors.white
                                                  : Colors.black,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: Checkbox(
                                      value: _enableNotifications,
                                      onChanged: (value) {
                                        setState(() {
                                          _enableNotifications = value!;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Enable notifications',
                                      style: TextStyle(fontSize: 14)),
                                ],
                              ),
                            ],
                          ),
                      ],
                    ),

                    // Add status toggle for recurring transactions
                    if (_isEditingRecurring)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          const Text(
                            'Transaction Status',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Switch(
                                value: true, // Always active when editing
                                onChanged: null, // Can't change in edit mode
                                activeColor: Colors.blue,
                              ),
                              const Expanded(
                                child: Text(
                                  'Active',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                    const SizedBox(height: 16),

                    // Save Buttons
                    if (_isEditing)
                      ElevatedButton(
                        onPressed: _updateTransaction,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text('Update Transaction'),
                      )
                    else if (_isEditingRecurring)
                      ElevatedButton(
                        onPressed: _updateRecurringTransaction,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text('Update Recurring Transaction'),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _saveTransaction(addNew: true),
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                backgroundColor: Colors.blue[100],
                                foregroundColor: Colors.blue,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: const Text('Save & Add New'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _saveTransaction(addNew: false),
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: const Text('Save'),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Numpad (fixed at bottom)
          if (_showNumpad)
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                border: Border(
                  top: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: CustomNumpad(
                controller: _amountController,
                onSubmit: _isEditing
                    ? _updateTransaction
                    : _isEditingRecurring
                        ? _updateRecurringTransaction
                        : () => _saveTransaction(addNew: false),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _updateTransaction() async {
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    // Combine date and time
    final dateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    // Update the transaction
    final transaction = Transaction(
      id: widget.transaction!.id,
      type: 'in',
      amount: amount,
      transactionTypeName: _selectedTransactionType,
      paymentMode: _paymentMode,
      dateTime: dateTime,
      note: _noteController.text.isEmpty ? null : _noteController.text,
      bookId: widget.transaction!.bookId, // Preserve the book ID
    );
    await DatabaseHelper.instance.updateTransaction(transaction);

    // Handle recurring transaction
    if (_isRecurring) {
      // Try to find a recurring transaction with similar properties
      RecurringTransaction? existingRecurring;
      if (widget.transaction != null) {
        existingRecurring = await DatabaseHelper.instance
            .getRecurringTransactionByTransactionProperties(
                widget.transaction!);
      }

      final recurringTransaction = RecurringTransaction(
        id: existingRecurring?.id, // Use existing ID if found
        type: 'in',
        amount: amount,
        transactionTypeName: _selectedTransactionType,
        paymentMode: _paymentMode,
        startDate: dateTime,
        dayOfMonth: _recurringDay,
        isActive: true,
        note: _noteController.text.isEmpty ? null : _noteController.text,
        bookId: widget.transaction!.bookId, // Preserve the book ID
      );

      if (existingRecurring != null && existingRecurring.id != null) {
        // Update existing recurring transaction
        recurringTransaction.id = existingRecurring.id;
        await DatabaseHelper.instance
            .updateRecurringTransaction(recurringTransaction);
      } else {
        // Insert new recurring transaction
        final id = await DatabaseHelper.instance
            .insertRecurringTransaction(recurringTransaction);
        recurringTransaction.id = id;
      }

      // Handle notifications
      if (_enableNotifications) {
        // await NotificationService.checkAndRescheduleNotifications();
      }
    } else {
      // If not recurring but there was a recurring transaction with similar properties, delete it
      if (widget.transaction != null) {
        await DatabaseHelper.instance
            .deleteRecurringTransactionByTransactionProperties(
                widget.transaction!);
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transaction updated successfully')),
    );

    Navigator.pop(context);
  }

  Future<void> _updateRecurringTransaction() async {
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    // Combine date and time for start date
    final startDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    // Update the recurring transaction
    final recurringTransaction = RecurringTransaction(
      id: _recurringTransactionId,
      type: 'in',
      amount: amount,
      transactionTypeName: _selectedTransactionType,
      paymentMode: _paymentMode,
      startDate: startDate,
      dayOfMonth: _recurringDay,
      isActive: true, // Always set to active when updating
      note: _noteController.text.isEmpty ? null : _noteController.text,
      bookId: widget.recurringTransaction!.bookId, // Preserve the book ID
    );

    await DatabaseHelper.instance
        .updateRecurringTransaction(recurringTransaction);

    // Reschedule notifications if enabled
    if (_enableNotifications) {
      // await NotificationService.checkAndRescheduleNotifications();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Recurring transaction updated successfully')),
    );

    Navigator.pop(context);
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _showAddCategoryDialog() async {
    final TextEditingController categoryController = TextEditingController();

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add New Category'),
          content: TextField(
            controller: categoryController,
            decoration: const InputDecoration(
              hintText: 'Enter category name',
            ),
            autofocus: true,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
                // Reset selection to default if no valid selection
                setState(() {
                  _selectedTransactionType = "Other Income";
                });
              },
            ),
            TextButton(
              child: const Text('Save Category'),
              onPressed: () async {
                if (categoryController.text.isNotEmpty) {
                  final newType = TransactionType(
                    name: categoryController.text,
                    category: 'in',
                  );
                  await DatabaseHelper.instance.insertTransactionType(newType);

                  Navigator.of(context).pop();
                  setState(() {
                    _selectedTransactionType = categoryController.text;
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Category saved successfully')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveTransaction({required bool addNew}) async {
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    // Combine date and time
    final dateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    // Create the transaction with the note
    final transaction = Transaction(
      type: 'in',
      amount: amount,
      transactionTypeName: _selectedTransactionType,
      paymentMode: _paymentMode,
      dateTime: dateTime,
      note: _noteController.text.isEmpty ? null : _noteController.text,
    );

    await DatabaseHelper.instance.insertTransaction(transaction);

    // Save recurring transaction if enabled
    if (_isRecurring) {
      final recurringTransaction = RecurringTransaction(
        type: 'in',
        amount: amount,
        transactionTypeName: _selectedTransactionType,
        paymentMode: _paymentMode,
        startDate: dateTime,
        dayOfMonth: _recurringDay,
        isActive: true,
        note: _noteController.text.isEmpty ? null : _noteController.text,
      );

      // Insert the recurring transaction and get its ID
      final id = await DatabaseHelper.instance
          .insertRecurringTransaction(recurringTransaction);

      // Set the ID for the notification
      recurringTransaction.id = id;

      // Show immediate test notification
      if (_enableNotifications) {
        // await NotificationService.createTestNotification(recurringTransaction);
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transaction saved successfully')),
    );

    if (addNew) {
      _resetForm();
    } else {
      Navigator.pop(context);
    }
  }
}
