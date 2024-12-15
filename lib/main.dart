import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:medicine_assistant_app/firebase_options.dart';
import 'package:medicine_assistant_app/page/home.dart';
import 'package:medicine_assistant_app/page/chatbot.dart';
import 'package:medicine_assistant_app/page/chat.dart';
import 'package:medicine_assistant_app/page/chatbotapi.dart';
import 'package:medicine_assistant_app/page/chatlist.dart';
import 'package:medicine_assistant_app/page/reminder.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure bindings are initialized

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
);

// Initialize Awesome Notifications
  await AwesomeNotifications().initialize(
    'resource://drawable/white_notification', // Notification icon (add a suitable icon to your project)
    [
      NotificationChannel(
        channelKey: 'medicine_reminder',
        channelName: 'Medicine Reminders',
        channelDescription: 'Reminder for scheduled medication',
        defaultColor: const Color(0xFF9D50DD),
        ledColor: Colors.white,
        importance: NotificationImportance.Max,
        channelShowBadge: true,
        enableVibration: true,
        enableLights: true,
        playSound: true,
        soundSource: 'resource://raw/res_ringtone',
      ),
    ],
    debug: true,
  );

  // Check and request notification permissions for Android 13+
  if (await AwesomeNotifications().isNotificationAllowed() == false) {
    AwesomeNotifications().requestPermissionToSendNotifications();
  }

// await AwesomeNotifications().createNotification(
//   content: NotificationContent(
//     id: 1,
//     channelKey: 'medicine_reminder',
//     title: 'Test Notification',
//     body: 'This is a test.',
//     notificationLayout: NotificationLayout.Default,
//     customSound: 'resource://raw/res_ringtone',
//   ),
// );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const String userID = '1'; // Set the userID as "2"

    return MaterialApp(
      scaffoldMessengerKey: scaffoldMessengerKey,
      title: 'Medicine Assistant',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage(userID: userID),// Pass userID to the screen
    );
  }
}
