import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/recurring_transaction.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';

class RecurringTransactionsScreen extends StatelessWidget {
  const RecurringTransactionsScreen({super.key});

  Future<List<RecurringTransaction>> _loadRecurringTransactions() async {
    return await DatabaseHelper.instance.getActiveRecurringTransactions();
  }

  Future<void> _deleteRecurringTransaction(BuildContext context, int id) async {
    await DatabaseHelper.instance.updateRecurringTransactionStatus(id, false);

    // Reschedule notifications after deletion
    await NotificationService.scheduleRecurringTransactionNotifications();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recurring transaction deleted')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recurring Transactions')),
      body: FutureBuilder<List<RecurringTransaction>>(
        future: _loadRecurringTransactions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No recurring transactions found'));
          }

          final transactions = snapshot.data!;

          return ListView.builder(
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final transaction = transactions[index];

              return Dismissible(
                key: Key(transaction.id.toString()),
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                direction: DismissDirection.endToStart,
                confirmDismiss: (direction) async {
                  return await showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text("Confirm"),
                        content: const Text(
                            "Are you sure you want to delete this recurring transaction?"),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text("CANCEL"),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text("DELETE"),
                          ),
                        ],
                      );
                    },
                  );
                },
                onDismissed: (direction) {
                  _deleteRecurringTransaction(context, transaction.id!);
                },
                child: Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          transaction.type == 'in' ? Colors.green : Colors.red,
                      child: Icon(
                        transaction.type == 'in'
                            ? Icons.arrow_downward
                            : Icons.arrow_upward,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      transaction.transactionTypeName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (transaction.note != null &&
                            transaction.note!.isNotEmpty)
                          Text(
                            transaction.note!,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        Text(
                          'Monthly on day ${transaction.dayOfMonth} ~ ${transaction.paymentMode}',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          // '${transaction.type == 'in' ? '+' : '-'} ${transaction.amount.toStringAsFixed(2)}',
                          '${transaction.type == 'in' ? '+' : '-'} Rs ${NumberFormat('#,##0.00').format(transaction.amount)}',
                          // 'Rs ${NumberFormat('#,##0.00').format(balance.)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: transaction.type == 'in'
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                        Text(
                          'Since ${DateFormat('MMM dd, yyyy').format(transaction.startDate)}',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
