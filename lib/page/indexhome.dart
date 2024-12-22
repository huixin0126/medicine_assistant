import 'package:flutter/material.dart';
import 'package:telephony/telephony.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class IndexHome extends StatefulWidget {
  final String userID;
  const IndexHome({super.key, required this.userID});

  @override
  _IndexHomeState createState() => _IndexHomeState();
}

class _IndexHomeState extends State<IndexHome> {
  final String guardianPhoneNumber = '';
  final String emergencyContactPhoneNumber = '';
  final Telephony telephony = Telephony.instance;

 Future<Map<String, String>> _getEmergencyContacts() async {
  try {
    // Get the current user's document
    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('User').doc(widget.userID).get();

    if (userDoc.exists) {
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

      // Extract emergency contact number
      String emergencyContactPhoneNumber = userData['emergencyContact'] ?? '';

      // Extract guardianIDs array
      List<dynamic> guardianIDs = userData['guardianIDs'] ?? [];
      
      if (guardianIDs.isEmpty) {
        throw 'No guardians linked to this user.';
      }

      // Extract guardian ID from the reference path
      // The path is in format "/User/ID" - we want just the ID
      String guardianPath = guardianIDs.first.toString();
      String guardianID = guardianPath.split('/').last;

      // Fetch the guardian's document to get their phone number
      DocumentSnapshot guardianDoc = await FirebaseFirestore.instance.collection('User').doc(guardianID).get();
      if (guardianDoc.exists) {
        String guardianPhoneNumber = (guardianDoc.data() as Map<String, dynamic>)['phoneNo'] ?? '';
        return {
          'guardianPhoneNumber': guardianPhoneNumber,
          'emergencyContactPhoneNumber': emergencyContactPhoneNumber,
        };
      } else {
        throw 'Guardian document not found.';
      }
    } else {
      throw 'User document not found.';
    }
  } catch (e) {
    print('Error fetching emergency contacts: $e');
    throw 'Failed to retrieve emergency contacts.';
  }
}

  Future<bool> _checkAndRequestPermissions() async {
    try {
      // Check and request location permissions
      var locationStatus = await Permission.location.status;
      if (!locationStatus.isGranted) {
        locationStatus = await Permission.location.request();
      }

      // Check and request SMS permissions
      var smsStatus = await Permission.sms.status;
      if (!smsStatus.isGranted) {
        smsStatus = await Permission.sms.request();
      }

      // Check and request phone call permissions
      var phoneStatus = await Permission.phone.status;
      if (!phoneStatus.isGranted) {
        phoneStatus = await Permission.phone.request();
      }

      // Print permission status for debugging
      print('Location Permission: ${locationStatus.isGranted}');
      print('SMS Permission: ${smsStatus.isGranted}');
      print('Phone Permission: ${phoneStatus.isGranted}');

      return locationStatus.isGranted && 
             smsStatus.isGranted && 
             phoneStatus.isGranted;
    } catch (e) {
      print('Permission check error: $e');
      _showErrorDialog('Error checking permissions: $e');
      return false;
    }
  }

  Future<String> _getCurrentLocation() async {
    try {
      // Check location service availability
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showErrorDialog('Location services are disabled');
        return 'Location services disabled';
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showErrorDialog('Location permissions are denied');
          return 'Location permission denied';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showErrorDialog('Location permissions are permanently denied');
        return 'Location permissions permanently denied';
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      );

      return 'https://www.google.com/maps?q=${position.latitude},${position.longitude}';
    } catch (e) {
      print('Location error: $e');
      _showErrorDialog('Could not retrieve location: $e');
      return 'Location could not be determined';
    }
  }

  // Future<void> _triggerPanicButton() async {
  //   try {
  //     // First, check and request all necessary permissions
  //     bool permissionsGranted = await _checkAndRequestPermissions();

  //     if (!permissionsGranted) {
  //       _showErrorDialog('Please grant all required permissions');
  //       return;
  //     }

  //     // Show confirmation dialog
  //     bool? confirmed = await showDialog<bool>(
  //       context: context,
  //       builder: (BuildContext context) {
  //         return AlertDialog(
  //           title: const Text('Emergency Alert'),
  //           content: const Text('Are you sure you want to trigger the emergency protocol?'),
  //           actions: [
  //             TextButton(
  //               child: const Text('Cancel'),
  //               onPressed: () => Navigator.of(context).pop(false),
  //             ),
  //             ElevatedButton(
  //               style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
  //               child: const Text('Confirm'),
  //               onPressed: () => Navigator.of(context).pop(true),
  //             ),
  //           ],
  //         );
  //       },
  //     );

  //     // Proceed only if confirmed
  //     if (confirmed == true) {
  //       // Get location
  //       String location = await _getCurrentLocation();

  //       // Prevent proceeding with invalid location
  //       if (location.contains('Location')) {
  //         _showErrorDialog('Cannot proceed without location');
  //         return;
  //       }

  //       // Attempt to call guardian
  //       try {
  //         final Uri callUri = Uri(scheme: 'tel', path: guardianPhoneNumber);
  //         if (await canLaunchUrl(callUri)) {
  //           await launchUrl(callUri);
  //         } else {
  //           _showErrorDialog('Could not launch dialer');
  //         }
  //       } catch (e) {
  //         print('Call error: $e');
  //         _showErrorDialog('Failed to make emergency call: $e');
  //       }

  //       // Attempt to send SMS
  //       try {
  //         await telephony.sendSms(
  //           to: emergencyContactPhoneNumber,
  //           message: 'EMERGENCY: I need immediate help! My current location is: $location',
  //         );
  //         print('Emergency SMS sent');
  //       } catch (e) {
  //         print('SMS sending error: $e');
  //         _showErrorDialog('Failed to send emergency SMS: $e');
  //       }

  //       // Show confirmation
  //       _showEmergencyConfirmationDialog();
  //     }
  //   } catch (e) {
  //     print('Panic button trigger error: $e');
  //     _showErrorDialog('Emergency protocol failed: $e');
  //   }
  // }

// Launch WhatsApp URL in web browser
Future<void> launchWhatsApp(String phone, String message) async {
  final whatsappUrl = 'https://wa.me/$phone?text=$message';
  if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
    await launchUrl(Uri.parse(whatsappUrl), mode: LaunchMode.externalApplication);
  } else {
    // Fallback: Open the link in a browser
    print("WhatsApp not available, launching in browser.");
    await launchUrl(Uri.parse(whatsappUrl), mode: LaunchMode.externalNonBrowserApplication);
  }
}


//   // Trigger panic button
// Future<void> _triggerPanicButton() async {
//   try {
//     // Check and request all necessary permissions
//     bool permissionsGranted = await _checkAndRequestPermissions();

//     if (!permissionsGranted) {
//       _showErrorDialog('Please grant all required permissions');
//       return;
//     }

//     // Show confirmation dialog
//     bool? confirmed = await showDialog<bool>(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: const Text('Emergency Alert'),
//           content: const Text('Are you sure you want to trigger the emergency protocol?'),
//           actions: [
//             TextButton(
//               child: const Text('Cancel'),
//               onPressed: () => Navigator.of(context).pop(false),
//             ),
//             ElevatedButton(
//               style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//               child: const Text('Confirm'),
//               onPressed: () => Navigator.of(context).pop(true),
//             ),
//           ],
//         );
//       },
//     );

//     if (confirmed == true) {
//       // Get location
//       String location = await _getCurrentLocation();

//       if (location.contains('Location')) {
//         _showErrorDialog('Cannot proceed without location');
//         return;
//       }

//       // Send WhatsApp message first
//       try {
//         String formattedPhoneNumber = emergencyContactPhoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
//         await launchWhatsApp(
//           formattedPhoneNumber,
//           'EMERGENCY: I need immediate help! My current location is: $location',
//         );
//       } catch (e) {
//         print('WhatsApp sending error: $e');
//         _showErrorDialog('Failed to send WhatsApp message: $e');
//       }

//       // Attempt to make a phone call
//       try {
//         final Uri callUri = Uri(scheme: 'tel', path: guardianPhoneNumber);
//         if (await canLaunchUrl(callUri)) {
//           // Ensure the app doesn't terminate during/after the call
//           await launchUrl(callUri, mode: LaunchMode.externalApplication);
//         } else {
//           _showErrorDialog('Could not launch dialer');
//         }
//       } catch (e) {
//         print('Call error: $e');
//         _showErrorDialog('Failed to make emergency call: $e');
//       }

//       // Ensure the app is active after the call
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         _showEmergencyConfirmationDialog();
//       });
//     }
//   } catch (e) {
//     print('Panic button trigger error: $e');
//     _showErrorDialog('Emergency protocol failed: $e');
//   }
// }

Future<void> _triggerPanicButton() async {
  try {
    // Check and request all necessary permissions
    bool permissionsGranted = await _checkAndRequestPermissions();

    if (!permissionsGranted) {
      _showErrorDialog('Please grant all required permissions');
      return;
    }

    // Fetch emergency contact information
    Map<String, String> contacts = await _getEmergencyContacts();
    String guardianPhoneNumber = contacts['guardianPhoneNumber']!;
    String emergencyContactPhoneNumber = contacts['emergencyContactPhoneNumber']!;

    // Show confirmation dialog
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Emergency Alert'),
          content: const Text('Are you sure you want to trigger the emergency protocol?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Confirm'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      // Get location
      String location = await _getCurrentLocation();

      if (location.contains('Location')) {
        _showErrorDialog('Cannot proceed without location');
        return;
      }

      // Send WhatsApp message
      try {
        String formattedPhoneNumber = emergencyContactPhoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
        await launchWhatsApp(
          formattedPhoneNumber,
          'EMERGENCY: I need immediate help! My current location is: $location',
        );
      } catch (e) {
        print('WhatsApp sending error: $e');
        _showErrorDialog('Failed to send WhatsApp message: $e');
      }

      // Make a phone call to the guardian
      try {
        final Uri callUri = Uri(scheme: 'tel', path: guardianPhoneNumber);
        if (await canLaunchUrl(callUri)) {
          await launchUrl(callUri, mode: LaunchMode.externalApplication);
        } else {
          _showErrorDialog('Could not launch dialer');
        }
      } catch (e) {
        print('Call error: $e');
        _showErrorDialog('Failed to make emergency call: $e');
      }

      // Show emergency confirmation dialog
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showEmergencyConfirmationDialog();
      });
    }
  } catch (e) {
    print('Panic button trigger error: $e');
    _showErrorDialog('Emergency protocol failed: $e');
  }
}


  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  // void _showEmergencyConfirmationDialog() {
  //   showDialog(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         title: const Text('Emergency Alert Sent'),
  //         content: const Text('Guardian has been called and emergency contact has been messaged.'),
  //         actions: [
  //           TextButton(
  //             child: const Text('OK'),
  //             onPressed: () => Navigator.of(context).pop(),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

  void _showEmergencyConfirmationDialog() {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Emergency Alert Sent'),
        content: const Text('Guardian has been called and emergency contact has been messaged.'),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          // ElevatedButton(
          //   style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          //   child: const Text('Open WhatsApp Link'),
          //   onPressed: () async {
          //     // Construct WhatsApp URL
          //     String formattedPhoneNumber = guardianPhoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
          //     final Uri whatsappUrl = Uri.parse(
          //       'https://wa.me/$formattedPhoneNumber?text=EMERGENCY: I need immediate help! My current location is: [location]'
          //     );

          //     try {
          //       // Launch WhatsApp URL
          //       if (await canLaunchUrl(whatsappUrl)) {
          //         await launchUrl(whatsappUrl);
          //       } else {
          //         print('Could not launch WhatsApp link');
          //         _showErrorDialog('Failed to open WhatsApp link');
          //       }
          //     } catch (e) {
          //       print('WhatsApp launch error: $e');
          //       _showErrorDialog('Failed to launch WhatsApp link');
          //     }
          //   },
          // ),
        ],
      );
    },
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Page'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: _triggerPanicButton,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
            textStyle: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          child: const Text('PANIC BUTTON'),
        ),
      ),
    );
  }
}