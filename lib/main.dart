import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:medicine_assistant_app/firebase_options.dart';
import 'package:medicine_assistant_app/page/home.dart';
import 'package:medicine_assistant_app/page/login.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:telephony/telephony.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure widgets are initialized
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform); // Initialize Firebase

  // Request permissions for phone and SMS
  await Telephony.instance.requestPhoneAndSmsPermissions;

  // Initialize Firebase Messaging and retrieve device token
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  String? deviceToken = await messaging.getToken();
  debugPrint('Device Token: $deviceToken'); // Log the token for debugging

  // Initialize Awesome Notifications
  await AwesomeNotifications().initialize(
    'resource://drawable/white_notification', // Notification icon (ensure the icon is in your resources)
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

  // Request notification permissions
  if (!await AwesomeNotifications().isNotificationAllowed()) {
    await AwesomeNotifications().requestPermissionToSendNotifications();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: scaffoldMessengerKey,
      title: 'Medicine Assistant',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: LoginPage(), // Default screen (login page)
    );
  }
}
