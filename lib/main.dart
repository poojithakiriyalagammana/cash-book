import 'package:cash_expense_manager/screens/book_view_screen.dart';
import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
// import 'screens/cash_book_screen.dart';
import 'screens/recurring_transactions_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notifications
  await NotificationService.initialize();

  // Check and reschedule notifications for all recurring transactions
  await NotificationService.checkAndRescheduleNotifications();

  runApp(const CashFlowApp());
}

class CashFlowApp extends StatefulWidget {
  const CashFlowApp({super.key});

  @override
  State<CashFlowApp> createState() => _CashFlowAppState();
}

class _CashFlowAppState extends State<CashFlowApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();

    // Add observer for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);

    // Set up notification action listener
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: _onNotificationAction,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // App lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came to foreground - check for any pending notifications
      NotificationService.checkAndRescheduleNotifications();
    }
  }

  // Define this static method to handle notification actions
  static Future<void> _onNotificationAction(
      ReceivedAction receivedAction) async {
    // Check if the payload contains the screen key and its value
    if (receivedAction.payload != null &&
        receivedAction.payload!.containsKey('screen') &&
        receivedAction.payload!['screen'] == 'recurring_transactions') {
      // Navigate to RecurringTransactionsScreen
      navigatorKey.currentState?.push(MaterialPageRoute(
          builder: (_) => const RecurringTransactionsScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MoniApp',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const BookViewScreen(),
    );
  }
}

// Global navigator key for navigation from outside of context
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
