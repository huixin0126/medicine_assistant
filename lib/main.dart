import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:medicine_assistant_app/firebase_options.dart';
import 'package:medicine_assistant_app/page/home.dart';
import 'package:medicine_assistant_app/page/login.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> requestPermissions(BuildContext? context) async {
  try {
    // Request microphone permission
    PermissionStatus microphoneStatus = await Permission.microphone.request();
    if (microphoneStatus.isDenied) {
      debugPrint('Microphone permission denied');
    }

    // Request location permissions
    PermissionStatus locationStatus = await Permission.location.request();
    if (locationStatus.isDenied) {
      debugPrint('Location permission denied');
    } else if (locationStatus.isPermanentlyDenied) {
      debugPrint('Location permission permanently denied');
    }

    // Request notification permission
    PermissionStatus notificationStatus = await Permission.notification.request();
    if (notificationStatus.isDenied) {
      debugPrint('Notification permission denied');
    }
  } catch (e) {
    debugPrint('Error requesting permissions: $e');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Schedule permission request for after the widget is built
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Request permissions safely
        await requestPermissions(context);
      });
    } catch (e) {
      debugPrint('Error in initialization: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
    scaffoldMessengerKey: scaffoldMessengerKey,
     title: 'Medicine Assistant',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: LoginPage(),
    );
  }
}

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Initialize Firebase
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    
    // Initialize Firebase Messaging with error handling
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    try {
      String? deviceToken = await messaging.getToken();
      debugPrint('Device Token: $deviceToken');
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }

    // Initialize notifications with error handling
    try {
      await AwesomeNotifications().initialize(
        'resource://drawable/white_notification',
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
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }

    await AwesomeNotifications().isNotificationAllowed().then((isAllowed) async {
      if (!isAllowed) {
        // Prompt user to allow notifications
        await AwesomeNotifications().requestPermissionToSendNotifications();
      }
    });

    runApp(const MyApp());
  } catch (e) {
    debugPrint('Error in main: $e');
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Error initializing app: $e'),
          ),
        ),
      ),
    );
  }
}
