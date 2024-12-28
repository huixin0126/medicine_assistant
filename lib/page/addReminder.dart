import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

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
  File? _medicineImage;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) {
      setState(() {
        _medicineImage = File(image.path);
      });
    }
  }

  Future<void> _showImageSourceOptions() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt),
              title: Text("Take Photo"),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library),
              title: Text("Choose from Gallery"),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _uploadImage() async {
    if (_medicineImage == null) return null;

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final imagePath = 'medicine_images/${widget.userID}/$timestamp.jpg';
      final storageRef = FirebaseStorage.instance.ref().child(imagePath);

      await storageRef.putFile(_medicineImage!);

      return await storageRef.getDownloadURL();
    } catch (e) {
      print("Error uploading image: $e");
      return null;
    }
  }

  // Future<void> _addReminder() async {
  //   final reminderTime = DateTime(
  //     _selectedDate.year,
  //     _selectedDate.month,
  //     _selectedDate.day,
  //     _selectedTime.hour,
  //     _selectedTime.minute,
  //   );

  //   String? imageUrl = await _uploadImage();

  //   await FirebaseFirestore.instance.collection('Reminder').add({
  //     'userID': widget.userID,
  //     'name': _medicineName.toLowerCase(),
  //     'dose': _dose,
  //     'times': Timestamp.fromDate(reminderTime),
  //     'mealTiming': _mealTiming,
  //     'imageUrl': imageUrl, // Save the image URL in Firestore
  //     'status': 'Active',
  //   });

  //   Navigator.pop(context);
  // }

  Future<void> saveMedicineIfNotExists({
    required String userID,
    required String name,
    required String? imageData,
  }) async {
    try {
      final medicineCollection = FirebaseFirestore.instance.collection('Medicine');
      final querySnapshot = await medicineCollection
          .where('userID', isEqualTo: userID)
          .where('name', isEqualTo: name.toLowerCase())
          .get();

      if (querySnapshot.docs.isEmpty) {
        await medicineCollection.add({
          'userID': userID,
          'name': name.toLowerCase(),
          'imageData': imageData ?? '',
        });
        print('Medicine saved successfully.');
      } else {
        print('Medicine already exists.');
      }
    } catch (e) {
      print('Error saving medicine: $e');
      throw e;
    }
  }

  Future<void> _addReminder() async {
    if (_medicineName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter medicine name")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final reminderTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      // Upload the image and get the URL
      String? imageUrl = await _uploadImage();

      // Save medicine if not already saved
      await saveMedicineIfNotExists(
        userID: widget.userID,
        name: _medicineName,
        imageData: imageUrl,
      );

      // Add reminder to Firestore
      await FirebaseFirestore.instance.collection('Reminder').add({
        'userID': widget.userID,
        'name': _medicineName.toLowerCase(),
        'dose': _dose,
        'times': Timestamp.fromDate(reminderTime),
        'mealTiming': _mealTiming,
        'imageUrl': imageUrl,
        'status': 'Active',
      });

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error adding reminder: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text("Add Reminder"),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _showImageSourceOptions,
                    child: _medicineImage == null
                        ? Container(
                            height: 150,
                            width: 150,
                            color: Colors.grey[300],
                            child: Icon(Icons.add_a_photo, size: 50),
                          )
                        : Image.file(
                            _medicineImage!,
                            height: 150,
                            width: 150,
                            fit: BoxFit.cover,
                          ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: InputDecoration(labelText: "Medicine Name"),
                    onChanged: (value) => _medicineName = value,
                  ),
                  TextFormField(
                    decoration: InputDecoration(labelText: "Dose"),
                    onChanged: (value) => _dose = value,
                  ),
                  ListTile(
                    title: Text(
                      "Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}",
                    ),
                    trailing: Icon(Icons.calendar_today),
                    onTap: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
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
                      if (picked != null) {
                        setState(() {
                          _selectedTime = picked;
                        });
                      }
                    },
                  ),
                  DropdownButton<String>(
                    value: _mealTiming,
                    items: ["Before meal", "After meal"]
                        .map((timing) => DropdownMenuItem(
                              value: timing,
                              child: Text(timing),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _mealTiming = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _addReminder,
                    child: Text("Add Reminder"),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Colors.white,
                  ),
                  SizedBox(height: 16),
                  Text(
                    "Adding reminder...",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
