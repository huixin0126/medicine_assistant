import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:medicine_assistant_app/page/addReminder.dart';
import 'package:medicine_assistant_app/page/cameraPage.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';

class MedicationReminderScreen extends StatefulWidget {
  final String userID;
  const MedicationReminderScreen({required this.userID, Key? key}) : super(key: key);

  @override
  _MedicationReminderScreenState createState() =>
      _MedicationReminderScreenState();
}

class _MedicationReminderScreenState extends State<MedicationReminderScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> reminders = [];
  bool isLoading = true; // Flag to track loading state
  bool noReminders = false; // Flag for no reminders found

  @override
  void initState() {
    super.initState();
    loadReminders();
  }

Future<void> loadReminders() async {
  final activeReminders = await fetchReminders(onlyActive: true);
  setState(() {
    reminders = activeReminders;
    isLoading = false; // Ensure the loading state is updated
    noReminders = activeReminders.isEmpty; // Handle no reminders case
  });
}

//   Future<void> onCompleteReminder(String reminderID) async {
//     // Update reminder status to "Complete"
//     await updateReminderStatus(reminderID);

//     // Reload reminders to remove completed ones
//     await loadReminders();
//   }

//   Future<void> updateReminderStatus(String reminderID) async {
//   try {
//     await _firestore.collection('Reminder').doc(reminderID).update({
//       'status': 'Complete',
//     });
//   } catch (e) {
//     print('Error updating reminder status: $e');
//   }
// }

  Future<void> onCompleteReminder(String reminderID) async {
    // Vibrate the device
    if (await Vibrate.canVibrate) {  // Check if device can vibrate
      Vibrate.vibrate();  // Trigger vibration
    }
    
    // Update reminder status to "Complete"
    await updateReminderStatus(reminderID);

    // Reload reminders to remove completed ones
    await loadReminders();
  }

  Future<void> updateReminderStatus(String reminderID) async {
  try {
    await _firestore.collection('Reminder').doc(reminderID).update({
      'status': 'Complete',
    });
  } catch (e) {
    print('Error updating reminder status: $e');
  }
}

Future<List<Map<String, dynamic>>> fetchReminders({bool onlyActive = false}) async {
  try {
    QuerySnapshot reminderSnapshot = await _firestore
        .collection('Reminder')
        .where('userID', isEqualTo: widget.userID)
        .get();

    if (reminderSnapshot.docs.isEmpty) {
      // No reminders found
      setState(() {
        reminders = [];
        isLoading = false;
        noReminders = true;
      });
      return [];
    }

    List<Map<String, dynamic>> reminderList = [];
    final now = DateTime.now();

    for (var reminderDoc in reminderSnapshot.docs) {
      var reminderData = reminderDoc.data() as Map<String, dynamic>;

      if (onlyActive && (reminderData['status'] ?? 'Active') != 'Active') {
        continue;
      }

      QuerySnapshot medicineSnapshot = await _firestore
          .collection('Medicine')
          .where('name', isEqualTo: reminderData['name'])
          .get();

      if (medicineSnapshot.docs.isEmpty) {
        continue;
      }

      var medicineData = medicineSnapshot.docs.first.data() as Map<String, dynamic>;

      dynamic seniorIDValue = medicineData['seniorID'];
      String? seniorID;

      if (seniorIDValue is DocumentReference) {
        seniorID = seniorIDValue.path;
      } else if (seniorIDValue is String) {
        seniorID = seniorIDValue;
      }

      if (seniorID != null && seniorID != 'User/${widget.userID}') {
        continue;
      }

      List<dynamic> timesList = [];
      dynamic timesData = reminderData['times'];

      if (timesData is Timestamp) {
        timesList = [timesData];
      } else if (timesData is List) {
        timesList = timesData;
      }

      List<dynamic> futureTimes = timesList
          .where((time) {
            DateTime reminderTime = time is Timestamp
                ? time.toDate()
                : DateTime.parse(time.toString());
            return reminderTime.isAfter(now);
          })
          .toList();

      if (futureTimes.isEmpty) {
        continue;
      }

      futureTimes.sort((a, b) {
        DateTime timeA = a is Timestamp ? a.toDate() : DateTime.parse(a.toString());
        DateTime timeB = b is Timestamp ? b.toDate() : DateTime.parse(b.toString());
        return timeA.compareTo(timeB);
      });

      if (futureTimes.isNotEmpty) {
        final nextReminderTime = futureTimes.first is Timestamp
            ? futureTimes.first.toDate()
            : DateTime.parse(futureTimes.first.toString());

        await scheduleReminderNotification(reminderDoc.id, reminderData['name'] ?? '', nextReminderTime);
      }

      reminderList.add({
        'reminderID': reminderDoc.id,
        'name': reminderData['name'] ?? '',
        'dosage': medicineData['dosage'] ?? '',
        'dose': reminderData['dose'] ?? '',
        'imageUrl': medicineData['imageData'] ?? '',
        'mealTiming': reminderData['mealTiming'] ?? 'Before meal',
        'times': futureTimes,
        'status': reminderData['status'] ?? 'Active',
      });
    }

    reminderList.sort((a, b) {
      DateTime timeA = a['times'].first is Timestamp
          ? a['times'].first.toDate()
          : DateTime.parse(a['times'].first.toString());
      DateTime timeB = b['times'].first is Timestamp
          ? b['times'].first.toDate()
          : DateTime.parse(b['times'].first.toString());
      return timeA.compareTo(timeB);
    });

    setState(() {
      reminders = reminderList;
      isLoading = false;
      noReminders = reminderList.isEmpty;
    });

    return reminderList;
  } catch (e) {
    print('Error fetching reminders: $e');
    setState(() {
      isLoading = false;
      noReminders = true;
    });
    return [];
  }
}

// Future<void> scheduleReminderNotification(
//     String reminderID, String medicineName, DateTime reminderTime) async {
//   try {
//     if (reminderTime.isBefore(DateTime.now())) return;

//     await AwesomeNotifications().createNotification(
//       content: NotificationContent(
//         id: reminderID.hashCode,
//         channelKey: 'medicine_reminder',
//         title: 'Medicine Reminder',
//         body: 'It\'s time to take your medicine: $medicineName.',
//         notificationLayout: NotificationLayout.Default,
//       ),
//       schedule: NotificationCalendar(
//         year: reminderTime.year,
//         month: reminderTime.month,
//         day: reminderTime.day,
//         hour: reminderTime.hour,
//         minute: reminderTime.minute,
//         second: 0,
//         preciseAlarm: true,
//       ),
//     );
//   } catch (e) {
//     print('Error scheduling notification: $e');
//   }
// }

Future<void> scheduleReminderNotification(
    String reminderID, String medicineName, DateTime reminderTime) async {
  try {
    if (reminderTime.isBefore(DateTime.now())) return;

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: reminderID.hashCode,
        channelKey: 'medicine_reminder',
        title: 'Medicine Reminder',
        body: 'It\'s time to take your medicine: $medicineName.',
        notificationLayout: NotificationLayout.Default,
        displayOnBackground: true,
        customSound: 'resource://raw/res_ringtone',
      ),
      schedule: NotificationCalendar(
        year: reminderTime.year,
        month: reminderTime.month,
        day: reminderTime.day,
        hour: reminderTime.hour,
        minute: reminderTime.minute,
        second: 0,
        preciseAlarm: true,
      ),
    );
  } catch (e) {
    print('Error scheduling notification: $e');
  }
}


Future<void> vibrateOnAction() async {
  if (await Vibrate.canVibrate) {
    Vibrate.vibrate();
  } else {
    print("Device does not support vibration");
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medication Reminder'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : noReminders
              ? const Center(
                  child: Text(
                    'No reminders found.',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                )
              : ListView.builder(
                  itemCount: reminders.length,
                  itemBuilder: (context, index) {
                    final reminder = reminders[index];
                    return ReminderCard(
                      name: reminder['name'],
                      dosage: reminder['dosage'],
                      dose: reminder['dose'],
                      imageUrl: reminder['imageUrl'],
                      mealTiming: reminder['mealTiming'],
                      times: reminder['times'],
                      reminderID: reminder['reminderID'],
                      userID: widget.userID,
                      onComplete: ()async {await onCompleteReminder(reminder['reminderID']);},
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddReminderScreen(userID: widget.userID),
            ),
          ).then((_) => fetchReminders());
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class ReminderCard extends StatelessWidget {
  final String name;
  final String dosage;
  final String dose;
  final String imageUrl;
  final String mealTiming;
  final List<dynamic> times;
  final String reminderID; // Add reminderID for identification
  final String userID;     // Add userID for linking with guardians
  final VoidCallback onComplete;

  const ReminderCard({
    Key? key,
    required this.name,
    required this.dosage,
    required this.dose,
    required this.imageUrl,
    required this.mealTiming,
    required this.times,
    required this.reminderID,
    required this.userID,
    required this.onComplete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (imageUrl.isNotEmpty)
                  Image.network(
                    imageUrl,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.medication);
                    },
                  ),
                const SizedBox(width: 12),
                Text(
                  name,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (dosage.isNotEmpty) Text('Dosage: $dosage'),
            if (dose.isNotEmpty) Text('Dose: $dose'),
            Text('Timing: $mealTiming'),
            const SizedBox(height: 8),
            if (times.isNotEmpty) ...[
              const Text(
                'Reminders:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...times.map((time) => Text(
                    '- ${time is Timestamp 
                        ? time.toDate().toString() 
                        : DateTime.parse(time.toString()).toString()}',
                  )),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.bottomRight,
              child: ElevatedButton(
                onPressed: () async{
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CameraPage(
                        reminderID: reminderID,
                        userID: userID,
                        medicineName: name,
                      ),
                    ),
                  );

                  onComplete();
                },
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// class ReminderCard extends StatelessWidget {
//   final String name;
//   final String dosage;
//   final String dose;
//   final String imageUrl;
//   final String mealTiming;
//   final List<dynamic> times;

//   const ReminderCard({
//     Key? key,
//     this.name = 'Unknown Medicine',
//     this.dosage = '',
//     this.dose = '',
//     this.imageUrl = '',
//     this.mealTiming = 'Before meal',
//     this.times = const [],
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 if (imageUrl.isNotEmpty)
//                   Image.network(
//                     imageUrl,
//                     width: 40,
//                     height: 40,
//                     fit: BoxFit.cover,
//                     errorBuilder: (context, error, stackTrace) {
//                       return Icon(Icons.medication);
//                     },
//                   ),
//                 const SizedBox(width: 12),
//                 Text(
//                   name,
//                   style: const TextStyle(
//                       fontSize: 18, fontWeight: FontWeight.bold),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 8),
//             if (dosage.isNotEmpty) Text('Dosage: $dosage'),
//             if (dose.isNotEmpty) Text('Dose: $dose'),
//             Text('Timing: $mealTiming'),
//             const SizedBox(height: 8),
//             if (times.isNotEmpty) ...[
//               const Text(
//                 'Reminders:',
//                 style: TextStyle(fontWeight: FontWeight.bold),
//               ),
//               ...times.map((time) => Text(
//                     '- ${time is Timestamp 
//                         ? time.toDate().toString() 
//                         : DateTime.parse(time.toString()).toString()}',
//                   )),
//             ],
//           ],
//         ),
//       ),
//     );
//   }
// }

