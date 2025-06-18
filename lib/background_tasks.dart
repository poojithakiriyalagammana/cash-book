// import 'package:workmanager/workmanager.dart';
// import './services/notification_service.dart';

// // This must be a top-level function
// void callbackDispatcher() {
//   Workmanager().executeTask((task, inputData) async {
//     print("Background task executed: $task");
//     try {
//       NotificationService.backgroundNotificationHandler();
//       return Future.value(true);
//     } catch (e) {
//       print("Error in background task: $e");
//       return Future.value(false);
//     }
//   });
// }
