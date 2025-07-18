import 'package:cash_expense_manager/screens/cash_in_screen.dart';
// import 'package:cash_expense_manager/screens/cash_out_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/recurring_transaction.dart';
import '../services/database_helper.dart';

class TransactionListItem extends StatelessWidget {
  final Transaction transaction;
  final Function? onDelete;
  final Function? onRefresh;

  const TransactionListItem({
    super.key,
    required this.transaction,
    this.onDelete,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(transaction.id?.toString() ?? UniqueKey().toString()),
      background: Container(
        color: Colors.green,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: Row(
          children: const [
            Icon(Icons.edit, color: Colors.white),
            SizedBox(width: 10),
            Text(
              'Update',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: const [
            Text(
              'Delete',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            SizedBox(width: 10),
            Icon(Icons.delete, color: Colors.white),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          // Delete confirmation
          return await showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text("Confirm"),
                content: const Text(
                    "Are you sure you want to delete this transaction?"),
                actions: <Widget>[
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
        } else if (direction == DismissDirection.startToEnd) {
          _navigateToEditScreen(context);
          return false;
        }
        return false;
      },
      onDismissed: (direction) async {
        if (direction == DismissDirection.endToStart) {
          // Delete transaction
          await DatabaseHelper.instance.deleteTransaction(transaction.id!);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transaction deleted')),
          );
          if (onDelete != null) onDelete!();
          if (onRefresh != null) onRefresh!();
        }
      },
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.3,
        DismissDirection.endToStart: 0.3,
      },
      direction: DismissDirection.horizontal,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Transaction Type and Amount
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  transaction.transactionTypeName.isEmpty
                      ? 'No remark'
                      : transaction.transactionTypeName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Rs ${NumberFormat('#,##0.00').format(transaction.amount)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: transaction.type == 'in' ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),

            // Payment Mode
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    transaction.paymentMode,
                    style: const TextStyle(color: Colors.blue),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),

            // Note and DateTime
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Note
                Expanded(
                  child: transaction.note == null || transaction.note!.isEmpty
                      ? const SizedBox.shrink()
                      : Text(
                          transaction.note!.length > 25
                              ? 'Note: ${transaction.note!.substring(0, 25)}...'
                              : 'Note: ${transaction.note}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: transaction.note!.isEmpty ||
                                    transaction.note!.length > 50
                                ? 12.0
                                : 12.0,
                          ),
                        ),
                ),

                // Date
                Text(
                  DateFormat(
                    'dd MMM yyyy \'at\' HH:mm',
                  ).format(transaction.dateTime),
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToEditScreen(BuildContext context) {
    if (transaction.type == 'in') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CashInScreen(transaction: transaction),
        ),
      ).then((_) {
        if (onRefresh != null) onRefresh!();
      });
    } else {}
  }
}
