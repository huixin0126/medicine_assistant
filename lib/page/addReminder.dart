import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class AddReminderScreen extends StatefulWidget {
  final String userID;
  AddReminderScreen({required this.userID});

  @override
  _AddReminderScreenState createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _medicineName = "";
  String _dose = "";
  String _mealTiming = "Before meal";

  Future<void> _addReminder() async {
    final reminderTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    await FirebaseFirestore.instance.collection('Reminder').add({
      'userID': widget.userID,
      'name': _medicineName.toLowerCase(),
      'dose': _dose,
      'times': Timestamp.fromDate(reminderTime),
      'mealTiming': _mealTiming,
      'imageUrl': null, // Optional
      'status': 'Active',
    });

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Add Reminder"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextFormField(
              decoration: InputDecoration(labelText: "Medicine Name"),
              onChanged: (value) => _medicineName = value,
            ),
            TextFormField(
              decoration: InputDecoration(labelText: "Dose"),
              onChanged: (value) => _dose = value,
            ),
            ListTile(
              title: Text("Date: ${_selectedDate.toLocal()}"),
              trailing: Icon(Icons.calendar_today),
              onTap: () async {
                DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2100),
                );
                if (picked != null && picked != _selectedDate) {
                  setState(() {
                    _selectedDate = picked;
                  });
                }
              },
            ),
            ListTile(
              title: Text("Time: ${_selectedTime.format(context)}"),
              trailing: Icon(Icons.access_time),
              onTap: () async {
                TimeOfDay? picked = await showTimePicker(
                  context: context,
                  initialTime: _selectedTime,
                );
                if (picked != null && picked != _selectedTime) {
                  setState(() {
                    _selectedTime = picked;
                  });
                }
              },
            ),
            DropdownButton<String>(
              value: _mealTiming,
              items: ["Before meal", "After meal"]
                  .map((timing) => DropdownMenuItem(value: timing, child: Text(timing)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _mealTiming = value!;
                });
              },
            ),
            SizedBox(height: 20),
            ElevatedButton(
              child: Text("Add Reminder"),
              onPressed: _addReminder,
            ),
          ],
        ),
      ),
    );
  }
}
