import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class IndexHome extends StatefulWidget {
  final String userID;
  const IndexHome({super.key, required this.userID});

  @override
  _IndexHomeState createState() => _IndexHomeState();
}

class _IndexHomeState extends State<IndexHome> with WidgetsBindingObserver{
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  final String guardianPhoneNumber = '';
  final String emergencyContactPhoneNumber = '';

  Future<Map<String, String>> _getEmergencyContacts() async {
    try {
      // Get the current user's document
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('User')
          .doc(widget.userID)
          .get();

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
        DocumentSnapshot guardianDoc = await FirebaseFirestore.instance
            .collection('User')
            .doc(guardianID)
            .get();
        if (guardianDoc.exists) {
          String guardianPhoneNumber =
              (guardianDoc.data() as Map<String, dynamic>)['phoneNo'] ?? '';
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

      // Check and request phone call permissions
      var phoneStatus = await Permission.phone.status;
      if (!phoneStatus.isGranted) {
        phoneStatus = await Permission.phone.request();
      }

      // Print permission status for debugging
      print('Location Permission: ${locationStatus.isGranted}');
      print('Phone Permission: ${phoneStatus.isGranted}');

      return locationStatus.isGranted &&
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
      await launchUrl(Uri.parse(whatsappUrl),
          mode: LaunchMode.externalApplication);
    } else {
      // Fallback: Open the link in a browser
      print("WhatsApp not available, launching in browser.");
      await launchUrl(Uri.parse(whatsappUrl),
          mode: LaunchMode.externalNonBrowserApplication);
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

  bool _shouldShowDialog = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _shouldShowDialog) {
      _shouldShowDialog = false;
      _showEmergencyConfirmationDialog();
    }
  }

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
      String emergencyContactPhoneNumber =
          contacts['emergencyContactPhoneNumber']!;

      // Show confirmation dialog
      // bool? confirmed = await showDialog<bool>(
      //   context: context,
      //   builder: (BuildContext context) {
      //     return AlertDialog(
      //       title: const Text('Emergency Alert'),
      //       content: const Text('Are you sure you want to trigger the emergency protocol?'),
      //       actions: [
      //         TextButton(
      //           child: const Text('Cancel'),
      //           onPressed: () => Navigator.of(context).pop(false),
      //         ),
      //         ElevatedButton(
      //           style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
      //           child: const Text('Confirm'),
      //           onPressed: () => Navigator.of(context).pop(true),
      //         ),
      //       ],
      //     );
      //   },
      // );

      bool? confirmed = true;

      if (confirmed == true) {
        // Get location
         try {
            final Uri callUri = Uri(scheme: 'tel', path: guardianPhoneNumber);
            await launchUrl(callUri, mode: LaunchMode.externalApplication);

            // if (await canLaunchUrl(callUri)) {
            //   await launchUrl(callUri, mode: LaunchMode.externalApplication);
            // } else {
            //   _showErrorDialog('Could not launch dialer');
            // }
          } catch (e) {
            print('Call error: $e');
            _showErrorDialog('Failed to make emergency call: $e');
          }

          // Show emergency confirmation dialog
        // WidgetsBinding.instance.addPostFrameCallback((_) {
        //   _showEmergencyConfirmationDialog();
        // });
        String location = await _getCurrentLocation();

        if (location.contains('Location')) {
         
          _showErrorDialog('Cannot proceed without location');
          return;
        } 
        
        await Future.delayed(Duration(milliseconds: 100));
        while (WidgetsBinding.instance?.lifecycleState != AppLifecycleState.resumed) {
          await Future.delayed(Duration(milliseconds: 100));
        }

         // Send WhatsApp message
          try {
            String formattedPhoneNumber =
                emergencyContactPhoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
            await launchWhatsApp(
              formattedPhoneNumber,
              'EMERGENCY: I need immediate help! My current location is: $location',
            );
          } catch (e) {
            print('WhatsApp sending error: $e');
            _showErrorDialog('Failed to send WhatsApp message: $e');
          }

          // Set the flag to show the dialog when the app resumes
        _shouldShowDialog = true;

        // // Show emergency confirmation dialog
        // WidgetsBinding.instance.addPostFrameCallback((_) {
        //   _showEmergencyConfirmationDialog();
        // });
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
          content: const Text(
              'Guardian has been called and emergency contact has been messaged.'),
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

DateTime _getNextTime(dynamic timesField) {
  // Handle the case where timesField could be either a Timestamp or a List
  List<dynamic> times;

  if (timesField is List) {
    // If it's already a list, use it
    times = timesField;
  } else if (timesField is Timestamp) {
    // If it's a single Timestamp, convert it to a list with one element
    times = [timesField];
  } else {
    // If it's not a list or a timestamp, return a default value (null or error)
    return DateTime.now(); // or handle the error
  }

  // Now times is guaranteed to be a List
  DateTime? nextTime;
  for (var time in times) {
    try {
      // Check if time is a Timestamp, then convert to DateTime
      DateTime reminderTime = time is Timestamp ? time.toDate() : DateTime.parse(time.toString());

      if (nextTime == null || reminderTime.isBefore(nextTime)) {
        nextTime = reminderTime;
      }
    } catch (e) {
      print('Error parsing time: $e');
    }
  }

  return nextTime ?? DateTime.now(); // Return the next time or now if no valid time found
}

Stream<List<QueryDocumentSnapshot>> _getUpcomingReminders() {
  DateTime now = DateTime.now();

  return FirebaseFirestore.instance
      .collection('Reminder')
      .where('userID', isEqualTo: widget.userID)
      .snapshots()
      .map((snapshot) {
        List<QueryDocumentSnapshot> upcomingReminders = snapshot.docs.where((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

          if (!data.containsKey('times') || data['times'] == null) {
            return false;
          }

          DateTime nextTime = _getNextTime(data['times']);
          
          return nextTime.isAfter(now);
        }).toList();

        // Sort reminders by the next time
        upcomingReminders.sort((a, b) {
          DateTime timeA = _getNextTime((a.data() as Map<String, dynamic>)['times']);
          DateTime timeB = _getNextTime((b.data() as Map<String, dynamic>)['times']);
          return timeA.compareTo(timeB);
        });

        return upcomingReminders.take(2).toList();
      });
}


  Stream<QuerySnapshot> _getMedicineStream() {
    return FirebaseFirestore.instance
        .collection('Medicine')
        .where('userID', isEqualTo: widget.userID)
        .snapshots();
  }

  // @override
  // Widget build(BuildContext context) {
  //   return Scaffold(
  //     appBar: AppBar(
  //       title: const Text('Home Page'),
  //     ),
  //     body: Center(
  //       child: ElevatedButton(
  //         onPressed: _triggerPanicButton,
  //         style: ElevatedButton.styleFrom(
  //           backgroundColor: Colors.red,
  //           padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
  //           textStyle: const TextStyle(
  //             fontSize: 20,
  //             fontWeight: FontWeight.bold,
  //           ),
  //         ),
  //         child: const Text('PANIC BUTTON'),
  //       ),
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    DateTime startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
    DateTime endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
    
      // Print the current date, start of day, and end of day
  print("Current Date: ${now.toString()}");
  print("Start of Today: ${startOfDay.toString()}");
  print("End of Today: ${endOfDay.toString()}");

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Home',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 25),
                // Panic Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Implement panic button functionality
                      _triggerPanicButton();
                    },
                    icon: const Icon(
                      Icons.warning_rounded,
                      color: Colors.white, // Set the icon color to white
                    ),
                    label: const Text(
                      'Panic Button',
                      style: TextStyle(color: Colors.white), // Set the text color to white
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      textStyle: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Upcoming Medication Time',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                // Upcoming Reminders
                StreamBuilder<List<QueryDocumentSnapshot>>(
                  stream: _getUpcomingReminders(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Text('Something went wrong');
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Text('No upcoming medications');
                    }

                    // Only display the first two reminders
                    return Column(
                      children: snapshot.data!.take(2).map((doc) {
                        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                        DateTime nextTime = _getNextTime(data['times']);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['name'],
                                      style: const TextStyle(
                                        color: Colors.purple,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Dose: ${data['dose']}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      DateFormat('hh:mm a').format(nextTime),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      data['mealTiming'],
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Container(
                              //   padding: const EdgeInsets.symmetric(
                              //     horizontal: 16,
                              //     vertical: 8,
                              //   ),
                              //   decoration: BoxDecoration(
                              //     color: Colors.purple,
                              //     borderRadius: BorderRadius.circular(20),
                              //   ),
                              //   child: const Text(
                              //     'Done',
                              //     style: TextStyle(
                              //       color: Colors.white,
                              //     ),
                              //   ),
                              // ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 24),
                // Stats Row
                Row(
                  children: [
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('Medicine')
                            .where('userID', isEqualTo: widget.userID)
                            .snapshots(),
                        builder: (context, snapshot) {
                          int totalMedicine = snapshot.hasData ? snapshot.data!.docs.length : 0;
                          return _buildStatsCard(
                            'Total medicine',
                            totalMedicine.toString(),
                            const Color.fromARGB(255, 222, 174, 230)!,
                            Icons.medication,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('Reminder')
                            .where('userID', isEqualTo: widget.userID)
                            // .where('status', isEqualTo: 'Active')
                            .where('times', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
                            .where('times', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return const Text('Something went wrong');
                          }

                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const CircularProgressIndicator();
                          }
                          int totalReminders = snapshot.hasData ? snapshot.data!.docs.length : 0;
                          return _buildStatsCard(
                            "Today's Reminders",
                            totalReminders.toString(),
                            const Color.fromARGB(255, 250, 199, 122)!,
                            Icons.calendar_today,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
