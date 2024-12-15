import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class HelpAddReminderScreen extends StatefulWidget {
  final String? userID;
  final String? name;
  final String? medicine;
  final String? dose;
  final String? dateTime;
  final String? mealTiming;

  const HelpAddReminderScreen({
    this.userID,
    this.name,
    this.medicine,
    this.dose,
    this.dateTime,
    this.mealTiming,
    Key? key,
  }) : super(key: key);

  @override
  _HelpAddReminderScreen createState() => _HelpAddReminderScreen();
}

class _HelpAddReminderScreen extends State<HelpAddReminderScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _medicineName = "";
  String _dose = "";
  String _mealTiming = "Before meal";
  File? _medicineImage;
  final ImagePicker _picker = ImagePicker();

  // New variables for name and user lookup
  final TextEditingController _nameController = TextEditingController();
  String? _selectedUserID;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // If no name is provided in the constructor, fetch the user name from Firestore using userID
    if (widget.name != null) {
      _nameController.text = widget.name!;
      _selectedUserID = widget.userID;
    } else if (widget.userID != null) {
      _fetchUserName(widget.userID!);
    }

    // Set initial values for other fields
    if (widget.medicine != null) _medicineName = widget.medicine!;
    if (widget.dose != null) _dose = widget.dose!;
    if (widget.dateTime != null) {
      try {
        DateTime parsedDateTime = DateFormat('yyyy-MM-dd HH:mm').parse(widget.dateTime!);
        _selectedDate = parsedDateTime;
        _selectedTime = TimeOfDay(hour: parsedDateTime.hour, minute: parsedDateTime.minute);
      } catch (e) {
        print("Error parsing dateTime: $e");
      }
    }
  if (widget.mealTiming != null) _mealTiming = widget.mealTiming!;
    
  }

  // Function to fetch user name by userID
  Future<void> _fetchUserName(String userID) async {
    setState(() {
      _isLoading = true;
    });

    try {
      DocumentSnapshot userDoc = await _firestore.collection('User').doc(userID).get();
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>?;
        if (userData != null && userData['name'] != null) {
          setState(() {
            _nameController.text = userData['name'];
            _selectedUserID = userDoc.id;
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("User not found")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching user name: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _findUserByName(String currentUserID) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Your async code to find the user.
      DocumentSnapshot currentUserDoc = await _firestore
          .collection('User')
          .doc(currentUserID)
          .get();

      if (!currentUserDoc.exists) {
        throw Exception("Current user not found.");
      }

      List<dynamic> seniorIDs = [];
      final currentUserData = currentUserDoc.data() as Map<String, dynamic>?;

      if (currentUserData != null) {
        seniorIDs = currentUserData['seniorIDs'] ?? [];
      } else {
        // Handle the case where the document data is null.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Current user data is not found.")),
        );
        return;
      }

      String? foundUserID;
      // Iterate through connected seniors
      for (var seniorRef in seniorIDs) {
        if (seniorRef is DocumentReference) {
          DocumentSnapshot seniorDoc = await seniorRef.get();
          final seniorData = seniorDoc.data() as Map<String, dynamic>?;

          if (seniorData != null) {
            String seniorName = seniorData['name']?.toLowerCase() ?? '';
            if (seniorName == _nameController.text.trim().toLowerCase()) {
              foundUserID = seniorDoc.id;
              break; // Stop once the matching user is found
            }
          }
        }
      }

      if (foundUserID != null) {
        setState(() {
          _selectedUserID = foundUserID;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("User found: ${_nameController.text}")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No connected user found with name: ${_nameController.text}")),
        );
        setState(() {
          _selectedUserID = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error finding user: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

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

Future<void> _addReminder() async {
  if (_selectedUserID == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Please find and select a user first")),
    );
    return;
  }

  if (_medicineName.isEmpty || _dose.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Please fill in Medicine Name and Dose")),
    );
    return;
  }

  final reminderTime = DateTime(
    _selectedDate.year,
    _selectedDate.month,
    _selectedDate.day,
    _selectedTime.hour,
    _selectedTime.minute,
  );

  String? imageUrl = await _uploadImage();

  try {
    await _firestore.collection('Reminder').add({
      'userID': _selectedUserID,
      'name': _medicineName.toLowerCase(),
      'dose': _dose,
      'times': Timestamp.fromDate(reminderTime),
      'mealTiming': _mealTiming,
      'imageUrl': imageUrl,
      'status': 'Active',
    });

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Reminder added successfully!"),
        duration: Duration(seconds: 5),  // Specify duration here
      ),
    );

    Navigator.pop(context); // Navigate back after adding the reminder
  } catch (e) {
    // Show error message if adding reminder fails
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error adding reminder: $e"),
      duration: Duration(seconds: 5),),
    );
  }
}


   @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Add Reminder"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: "Senior's Name",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: _isLoading 
                      ? CircularProgressIndicator() 
                      : Icon(Icons.search),
                    onPressed: () async {
                    if (widget.userID != null) {
                        await _findUserByName(widget.userID!); // Ensure widget.userID is not null
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("User ID is null")),
                        );
                    }
                  },
                  ),
                ],
              ),
              
              // Show selected user ID if found
              if (_selectedUserID != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    "Selected User ID: $_selectedUserID",
                    style: TextStyle(color: Colors.green),
                  ),
                ),
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
                initialValue: _medicineName,
                decoration: InputDecoration(labelText: "Medicine Name"),
                onChanged: (value) => _medicineName = value,
              ),
              TextFormField(
                initialValue: _dose,
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
                    .map((timing) => DropdownMenuItem(value: timing, child: Text(timing)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _mealTiming = value!;
                  });
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                child: Text("Add Reminder"),
                onPressed: _addReminder,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
