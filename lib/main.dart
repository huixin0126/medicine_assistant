import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:medicine_assistant_app/firebase_options.dart';
import 'package:medicine_assistant_app/page/home.dart';
import 'package:medicine_assistant_app/page/login.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'class/user.dart';

//hello
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

// SharedPreferences keys
const String USER_ID_KEY = 'userID';
const String KEEP_SIGNED_IN_KEY = 'keepSignedIn';
const String FACE_USER_ID_KEY = 'faceLoginUserID';
const String KEEP_SIGNED_IN_KEY_FACE = 'keepSignedInFace';

Future<void> requestPermissions(BuildContext? context) async {
  try {
    // Request necessary permissions
    await Permission.microphone.request();
    await Permission.location.request();
    await Permission.notification.request();
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
  bool _isLoading = true;
  bool _keepSignedIn = false;
  bool _keepSignedInFace = false;
  String? _userID;
  String? _faceUserID;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Load user session details
      final prefs = await SharedPreferences.getInstance();
      _userID = prefs.getString(USER_ID_KEY);
      _keepSignedIn = prefs.getBool(KEEP_SIGNED_IN_KEY) ?? false;
      _faceUserID = prefs.getString(FACE_USER_ID_KEY);
      _keepSignedInFace = prefs.getBool(KEEP_SIGNED_IN_KEY_FACE) ?? false;

      setState(() {
        _isLoading = false;
      });

      // Request permissions after initialization
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await requestPermissions(context);
      });
    } catch (e) {
      debugPrint('Error during initialization: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<User?> _getUserDetails() async {
    try {
      if (_userID == null || _userID!.isEmpty) {
        debugPrint('No user ID found in session.');
        return null;
      }

      // Fetch user details from Firestore
      final userDoc = await FirebaseFirestore.instance.collection('User').doc(_userID).get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        return User(
          userID: userDoc.id,
          name: data['name'] ?? '',
          email: data['email'] ?? '',
          phoneNo: data['phoneNo'] ?? '',
          avatar: data['avatar'] ?? '',
          deviceToken: data['deviceToken'] ?? '',
          faceImageUrl: data['faceImageUrl'] ?? '',
          emergencyContact: data['emergencyContact'] ?? '',
          guardianIDs: List<String>.from(data['guardianIDs'] ?? []),
          seniorIDs: List<String>.from(data['seniorIDs'] ?? []),
          faceData: Map<String, dynamic>.from(data['faceData'] ?? {}),
        );
      } else {
        debugPrint('User document not found.');
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching user details: $e');
      return null;
    }
  }

  // Fetch user details for face login
  Future<User?> _getFaceUserDetails() async {
    try {
      if (_faceUserID == null || _faceUserID!.isEmpty) {
        debugPrint('No face user ID found in session.');
        return null;
      }

      // Fetch face-based user details from Firestore
      final userDoc = await FirebaseFirestore.instance.collection('User').doc(_faceUserID).get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        return User(
          userID: userDoc.id,
          name: data['name'] ?? '',
          email: data['email'] ?? '',
          phoneNo: data['phoneNo'] ?? '',
          avatar: data['avatar'] ?? '',
          deviceToken: data['deviceToken'] ?? '',
          faceImageUrl: data['faceImageUrl'] ?? '',
          emergencyContact: data['emergencyContact'] ?? '',
          guardianIDs: List<String>.from(data['guardianIDs'] ?? []),
          seniorIDs: List<String>.from(data['seniorIDs'] ?? []),
          faceData: Map<String, dynamic>.from(data['faceData'] ?? {}),
        );
      } else {
        debugPrint('User document not found.');
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching face user details: $e');
      return null;
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
      home: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _keepSignedInFace
              ? FutureBuilder<User?>(
                  future: _getFaceUserDetails(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError || !snapshot.hasData) {
                      return LoginPage();
                    }
                    final user = snapshot.data!;
                    return HomePage(
                      userID: user.userID,
                      user: user,
                    );
                  },
                )
              : _keepSignedIn
                  ? FutureBuilder<User?>(
                      future: _getUserDetails(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError || !snapshot.hasData) {
                          return LoginPage();
                        }
                        final user = snapshot.data!;
                        return HomePage(
                          userID: user.userID,
                          user: user,
                        );
                      },
                    )
                  : LoginPage(),
    );
  }
}

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Firebase
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    // Initialize Firebase Messaging
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    try {
      String? deviceToken = await messaging.getToken();
      debugPrint('Device Token: $deviceToken');
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }

    // Initialize notifications
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

    // Request notification permissions
    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }

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
