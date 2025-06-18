import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import '../models/recurring_transaction.dart';
import '../services/database_helper.dart';
import 'package:intl/intl.dart';

class NotificationService {
  static const String recurringTransactionChannelKey =
      'recurring_transaction_channel';
  static const String recurringTransactionGroupKey =
      'recurring_transaction_notifications';

  static Future<void> initialize() async {
    await AwesomeNotifications().initialize(
      null, // no icon on null for default app icon
      [
        NotificationChannel(
          channelKey: recurringTransactionChannelKey,
          channelName: 'Recurring Transaction Notifications',
          channelDescription:
              'Notifications for upcoming recurring transactions',
          defaultColor: Colors.blue,
          ledColor: Colors.blue,
          importance: NotificationImportance.High,
          locked: true, // Lock notification to prevent user dismissal
          criticalAlerts: true, // Enable critical alerts to bypass DND settings
        )
      ],
    );

    // Request permission including critical alerts
    await AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
      if (!isAllowed) {
        AwesomeNotifications().requestPermissionToSendNotifications(
          channelKey: recurringTransactionChannelKey,
          permissions: [
            NotificationPermission.Alert,
            NotificationPermission.Sound,
            NotificationPermission.Badge,
            NotificationPermission.Vibration,
            NotificationPermission.Light,
            NotificationPermission.CriticalAlert,
            NotificationPermission.FullScreenIntent
          ],
        );
      }
    });

    // Register background callback to reschedule notifications on reboot
    AwesomeNotifications().setListeners(
      onNotificationCreatedMethod: onNotificationCreatedMethod,
      onNotificationDisplayedMethod: onNotificationDisplayedMethod,
      onActionReceivedMethod: onActionReceivedMethod,
      onDismissActionReceivedMethod: onDismissActionReceivedMethod,
    );
  }

  // Notification lifecycle callbacks
  static Future<void> onNotificationCreatedMethod(
      ReceivedNotification receivedNotification) async {}

  static Future<void> onNotificationDisplayedMethod(
      ReceivedNotification receivedNotification) async {}

  static Future<void> onActionReceivedMethod(
      ReceivedAction receivedAction) async {}

  static Future<void> onDismissActionReceivedMethod(
      ReceivedAction receivedAction) async {}

  // Create an immediate test notification when a recurring transaction is added
  static Future<void> createTestNotification(
      RecurringTransaction transaction) async {
    final formattedAmount = transaction.amount.toStringAsFixed(2);
    final transactionType = transaction.type == 'in' ? 'Income' : 'Expense';

    // Calculate the next occurrence date correctly
    final nextOccurrenceDate = _getNextOccurrenceDate(transaction.dayOfMonth);
    final daysTillNextOccurrence =
        _calculateDaysBetween(DateTime.now(), nextOccurrenceDate);

    final daysText =
        daysTillNextOccurrence == 1 ? '1 day' : '$daysTillNextOccurrence days';

    // Immediate notification
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
          id: _generateUniqueId(transaction.id!, 100),
          channelKey: recurringTransactionChannelKey,
          title: 'New Recurring Transaction Added',
          body:
              '${transaction.transactionTypeName} ($transactionType of $formattedAmount) will be due on day ${transaction.dayOfMonth} every month',
          notificationLayout: NotificationLayout.Default,
          category: NotificationCategory.Reminder,
          groupKey: '${recurringTransactionGroupKey}_immediate', // Different group key
          wakeUpScreen: true,
          criticalAlert: true,
          payload: {'screen': 'recurring_transactions'}),
    );

    // Scheduled notification (30 seconds later)
    await AwesomeNotifications().createNotification(
      schedule: NotificationCalendar(
        second: DateTime.now().add(const Duration(seconds: 30)).second,
        minute: DateTime.now().add(const Duration(seconds: 30)).minute,
        hour: DateTime.now().add(const Duration(seconds: 30)).hour,
        day: DateTime.now().add(const Duration(seconds: 30)).day,
        month: DateTime.now().add(const Duration(seconds: 30)).month,
        year: DateTime.now().add(const Duration(seconds: 30)).year,
        allowWhileIdle: true,
        repeats: false,
        preciseAlarm: true,
      ),
      content: NotificationContent(
          id: _generateUniqueId(transaction.id!, 101),
          channelKey: recurringTransactionChannelKey,
          title: 'Upcoming Transaction Reminder',
          body:
              'Your ${transaction.transactionTypeName} ($transactionType of $formattedAmount) will be due in $daysText',
          notificationLayout: NotificationLayout.Default,
          category: NotificationCategory.Reminder,
          wakeUpScreen: true,
          criticalAlert: true,
          groupKey: '${recurringTransactionGroupKey}_scheduled', // Different group key
          payload: {'screen': 'recurring_transactions'}),
    );
  }

  // Helper function to get adjusted date considering month end days
  static DateTime _getAdjustedDate(int year, int month, int dayOfMonth) {
    // Get the last day of the specified month
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;

    // If the specified day exceeds the last day of the month, use the last day
    final adjustedDay =
        dayOfMonth > lastDayOfMonth ? lastDayOfMonth : dayOfMonth;

    return DateTime(year, month, adjustedDay);
  }

  // Get the next occurrence date considering month transitions
  static DateTime _getNextOccurrenceDate(int dayOfMonth) {
    final now = DateTime.now();

    // First, check the current month
    final thisMonthDate = _getAdjustedDate(now.year, now.month, dayOfMonth);

    // If the date in current month is still in the future, use it
    if (thisMonthDate.isAfter(now)) {
      return thisMonthDate;
    }

    // Otherwise, look at next month
    return _getAdjustedDate(now.year, now.month + 1, dayOfMonth);
  }

  // Calculate days between two dates, ignoring time components
  static int _calculateDaysBetween(DateTime startDate, DateTime endDate) {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return end.difference(start).inDays;
  }

  // Fixed function to calculate days until next occurrence
  // static int _getDaysTillNextOccurrence(int dayOfMonth) {
  //   final nextOccurrenceDate = _getNextOccurrenceDate(dayOfMonth);
  //   return _calculateDaysBetween(DateTime.now(), nextOccurrenceDate);
  // }

  static Future<void> scheduleRecurringTransactionNotifications() async {
    // Clear existing notifications first
    await AwesomeNotifications()
        .cancelNotificationsByGroupKey(recurringTransactionGroupKey);

    // Get all active recurring transactions
    final transactions =
        await DatabaseHelper.instance.getActiveRecurringTransactions();

    for (var transaction in transactions) {
      await _scheduleNotificationsForTransaction(transaction);
    }
  }

  static Future<void> _scheduleNotificationsForTransaction(
      RecurringTransaction transaction) async {
    // final now = DateTime.now();

    // Calculate the upcoming date for this transaction
    DateTime upcomingDate = _getNextOccurrenceDate(transaction.dayOfMonth);

    // Get notifications for next occurrence
    await _scheduleAllReminders(transaction, upcomingDate);

    // Also schedule notifications for the following month's due date
    DateTime followingMonthDate;

    // Calculate the following month's date correctly
    if (upcomingDate.month == 12) {
      followingMonthDate =
          _getAdjustedDate(upcomingDate.year + 1, 1, transaction.dayOfMonth);
    } else {
      followingMonthDate = _getAdjustedDate(
          upcomingDate.year, upcomingDate.month + 1, transaction.dayOfMonth);
    }

    await _scheduleAllReminders(transaction, followingMonthDate);
  }

  static Future<void> _scheduleAllReminders(
      RecurringTransaction transaction, DateTime dueDate) async {
    final now = DateTime.now();

    // Calculate reminder dates with safety checks
    DateTime fiveDaysBefore = dueDate.subtract(const Duration(days: 5));
    DateTime twoDaysBefore = dueDate.subtract(const Duration(days: 2));
    DateTime oneDayBefore = dueDate.subtract(const Duration(days: 1));

    // 5 days before
    if (fiveDaysBefore.isAfter(now)) {
      await _scheduleNotification(
          transaction, dueDate, fiveDaysBefore, '5 days');
    }

    // 2 days before
    if (twoDaysBefore.isAfter(now)) {
      await _scheduleNotification(
          transaction, dueDate, twoDaysBefore, '2 days');
    }

    // 1 day before (tomorrow)
    if (oneDayBefore.isAfter(now)) {
      await _scheduleNotification(transaction, dueDate, oneDayBefore, '1 day');
    }

    // On the due date
    if (dueDate.isAfter(now)) {
      await _scheduleNotification(transaction, dueDate, dueDate, 'today');
    }
  }

  static Future<void> _scheduleNotification(RecurringTransaction transaction,
      DateTime dueDate, DateTime notificationDate, String daysRemaining) async {
    final formattedAmount = transaction.amount.toStringAsFixed(2);
    final transactionType = transaction.type == 'in' ? 'Income' : 'Expense';
    final formattedDate = DateFormat('MMM dd, yyyy').format(dueDate);

    String message;
    if (daysRemaining == 'today') {
      message = 'is due today';
    } else if (daysRemaining == '1 day') {
      message = 'is due tomorrow';
    } else {
      message = 'is due in $daysRemaining';
    }

    final notificationId =
        _generateUniqueId(transaction.id!, _getOffsetForMessage(daysRemaining));

    final now = DateTime.now();
    final notificationTime = DateTime(
        notificationDate.year,
        notificationDate.month,
        notificationDate.day,
        9,
        0,
        0); // Always at 9 AM

    // If notification time is in the past but still today, schedule for 30 seconds from now
    if (notificationTime.isBefore(now) &&
        notificationTime.day == now.day &&
        notificationTime.month == now.month &&
        notificationTime.year == now.year) {
      final scheduleTime = now.add(const Duration(seconds: 30));

      await AwesomeNotifications().createNotification(
        content: NotificationContent(
            id: notificationId,
            channelKey: recurringTransactionChannelKey,
            title: '${transaction.transactionTypeName} $message',
            body:
                '$transactionType of $formattedAmount ${transaction.type == 'in' ? 'to receive' : 'to pay'} on $formattedDate',
            notificationLayout: NotificationLayout.Default,
            category: NotificationCategory.Reminder,
            wakeUpScreen: true,
            criticalAlert: true,
            groupKey: recurringTransactionGroupKey,
            payload: {'screen': 'recurring_transactions'}),
        schedule: NotificationCalendar(
          second: scheduleTime.second,
          minute: scheduleTime.minute,
          hour: scheduleTime.hour,
          day: scheduleTime.day,
          month: scheduleTime.month,
          year: scheduleTime.year,
          allowWhileIdle: true,
          repeats: false,
          preciseAlarm: true,
        ),
      );
    }
    // Otherwise schedule for 9 AM on the notification date
    else if (notificationTime.isAfter(now)) {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
            id: notificationId,
            channelKey: recurringTransactionChannelKey,
            title: '${transaction.transactionTypeName} $message',
            body:
                '$transactionType of $formattedAmount ${transaction.type == 'in' ? 'to receive' : 'to pay'} on $formattedDate',
            notificationLayout: NotificationLayout.Default,
            category: NotificationCategory.Reminder,
            wakeUpScreen: true,
            criticalAlert: true,
            groupKey: recurringTransactionGroupKey,
            payload: {'screen': 'recurring_transactions'}),
        schedule: NotificationCalendar(
          second: 0,
          minute: 0,
          hour: 9, // Always at 9 AM
          day: notificationDate.day,
          month: notificationDate.month,
          year: notificationDate.year,
          allowWhileIdle: true,
          repeats: false,
          preciseAlarm: true,
        ),
      );
    }
    // We don't schedule if the notification time is completely in the past
  }

  static int _getOffsetForMessage(String daysRemaining) {
    if (daysRemaining == '5 days') return 1;
    if (daysRemaining == '2 days') return 2;
    if (daysRemaining == '1 day') return 3;
    if (daysRemaining == 'today') return 4;
    return 0;
  }

  // Generate a unique ID for each notification to avoid conflicts
  static int _generateUniqueId(int transactionId, int offset) {
    return (transactionId * 1000) + offset;
  }

  // Check and reschedule notifications (call this on app start/resume)
  static Future<void> checkAndRescheduleNotifications() async {
    await scheduleRecurringTransactionNotifications();
  }
}
