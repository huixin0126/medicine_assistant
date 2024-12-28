import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:medicine_assistant_app/page/addReminder.dart';
import 'package:medicine_assistant_app/page/cameraPage.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:intl/intl.dart';

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
  bool showPastReminders = false; // State to toggle reminders

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
    // First, get all reminders for the user
    QuerySnapshot reminderSnapshot = await _firestore
        .collection('Reminder')
        .where('userID', isEqualTo: widget.userID)
        .get();

    if (reminderSnapshot.docs.isEmpty) {
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
      
      // Check the reminder status - Skip if we only want active reminders and this one isn't active
      String status = reminderData['status'] ?? 'Active';
      if (onlyActive && status != 'Active') {
        continue; // Skip this reminder if it's not active
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
            return reminderTime.isAfter(now.subtract(const Duration(days: 1)));
          })
          .toList();

      // Only add reminders with valid times
      if (futureTimes.isNotEmpty) {
        futureTimes.sort((a, b) {
          DateTime timeA = a is Timestamp ? a.toDate() : DateTime.parse(a.toString());
          DateTime timeB = b is Timestamp ? b.toDate() : DateTime.parse(b.toString());
          return timeA.compareTo(timeB);
        });

        final nextReminderTime = futureTimes.first is Timestamp
            ? futureTimes.first.toDate()
            : DateTime.parse(futureTimes.first.toString());

        await scheduleReminderNotification(
          reminderDoc.id, 
          reminderData['name'] ?? '', 
          nextReminderTime
        );

        reminderList.add({
          'reminderID': reminderDoc.id,
          'name': reminderData['name'] ?? '',
          'dosage': reminderData['dosage'] ?? '',
          'dose': reminderData['dose'] ?? '',
          'imageUrl': reminderData['imageUrl'] ?? '',
          'mealTiming': reminderData['mealTiming'] ?? 'Before meal',
          'times': futureTimes,
          'status': status, // Make sure to include the status
        });
      }
    }

    // Sort reminders by time
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

 void toggleReminderType(bool showPast) {
    setState(() {
      showPastReminders = showPast;
    });
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    List<Map<String, dynamic>> pastReminders = reminders.where((reminder) {
      DateTime firstTime = reminder['times'].first is Timestamp
          ? reminder['times'].first.toDate()
          : DateTime.parse(reminder['times'].first.toString());
      return firstTime.isBefore(now) &&
          firstTime.isAfter(now.subtract(const Duration(days: 1)));
    }).toList();

    List<Map<String, dynamic>> futureReminders = reminders.where((reminder) {
      DateTime firstTime = reminder['times'].first is Timestamp
          ? reminder['times'].first.toDate()
          : DateTime.parse(reminder['times'].first.toString());
      return firstTime.isAfter(now);
    }).toList();

    List<Map<String, dynamic>> currentReminders =
        showPastReminders ? pastReminders : futureReminders;

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
              : Column(
                  children: [
                    // Toggle Buttons
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => toggleReminderType(true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: showPastReminders
                                        ? Colors.blue
                                        : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Previous',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: showPastReminders
                                          ? Colors.white
                                          : Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => toggleReminderType(false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: !showPastReminders
                                        ? Colors.green
                                        : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Upcoming',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: !showPastReminders
                                          ? Colors.white
                                          : Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Reminder List
                    Expanded(
                      child: currentReminders.isEmpty
                          ? Center(
                              child: Text(
                                showPastReminders
                                    ? 'No past reminders.'
                                    : 'No upcoming reminders.',
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500),
                              ),
                            )
                          : ListView.builder(
                              itemCount: currentReminders.length,
                              itemBuilder: (context, index) {
                                final reminder = currentReminders[index];
                                return ReminderCard(
                                  name: reminder['name'],
                                  dosage: reminder['dosage'],
                                  dose: reminder['dose'],
                                  imageUrl: reminder['imageUrl'],
                                  mealTiming: reminder['mealTiming'],
                                  times: reminder['times'],
                                  reminderID: reminder['reminderID'],
                                  userID: widget.userID,
                                  onComplete: () async {
                                    await onCompleteReminder(
                                        reminder['reminderID']);
                                  }, onReload: () async { 
                                    await loadReminders();
                                   },
                                );
                              },
                            ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          setState(() {
            isLoading = true; // Set isLoading to true before navigating
          });
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddReminderScreen(userID: widget.userID),
            ),
          );
          await fetchReminders(onlyActive: true); // Reload reminders after returning
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
  final String reminderID;
  final String userID;
  final VoidCallback onComplete;
  final VoidCallback onReload; // Add reload callback

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
    required this.onReload, // Add to constructor
  }) : super(key: key);

  Future<void> _showDeleteConfirmation(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Reminder'),
          content: Text('Are you sure you want to delete the reminder for $name?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                try {
                  // Delete the reminder from Firestore
                  await FirebaseFirestore.instance
                      .collection('Reminder')
                      .doc(reminderID)
                      .delete();
                  
                  // Cancel the notification
                  await AwesomeNotifications().cancel(reminderID.hashCode);
                  
                  Navigator.of(context).pop();
                  
                  // Call reload callback after successful deletion
                  onReload();
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Reminder deleted successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  Navigator.of(context).pop();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Error deleting reminder'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rest of the build method remains the same
    final DateTime today = DateTime.now();
    final DateTime startOfTomorrow = DateTime(today.year, today.month, today.day).add(const Duration(days: 1));

    bool isForToday = times.any((time) {
      DateTime reminderDateTime;
      if (time is Timestamp) {
        reminderDateTime = time.toDate();
      } else {
        reminderDateTime = DateTime.parse(time.toString());
      }
      return reminderDateTime.isBefore(startOfTomorrow);
    });

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Stack(
        children: [
          Padding(
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
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (dosage.isNotEmpty)
                  Text(
                    'Dosage: $dosage',
                    style: const TextStyle(fontSize: 16),
                  ),
                if (dose.isNotEmpty)
                  Text(
                    'Dose: $dose',
                    style: const TextStyle(fontSize: 16),
                  ),
                Text(
                  'Timing: $mealTiming',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                if (times.isNotEmpty) ...[
                  const Text(
                    'Reminders:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  ...times.map((time) {
                    DateTime reminderDateTime;
                    if (time is Timestamp) {
                      reminderDateTime = time.toDate();
                    } else {
                      reminderDateTime = DateTime.parse(time.toString());
                    }
                    return Text(
                      '- ${DateFormat('yyyy-MM-dd HH:mm').format(reminderDateTime)}',
                      style: const TextStyle(fontSize: 16),
                    );
                  }),
                ],
                const SizedBox(height: 12),
                if (isForToday)
                  Align(
                    alignment: Alignment.bottomRight,
                    child: ElevatedButton(
                      onPressed: () async {
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
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.purple,
                      ),
                      child: const Text('Done'),
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
              onPressed: () => _showDeleteConfirmation(context),
            ),
          ),
        ],
      ),
    );
  }
}