import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:firebase_storage/firebase_storage.dart';

class CameraPage extends StatefulWidget {
  final String reminderID;
  final String userID;
  final String medicineName;

  const CameraPage({
    Key? key,
    required this.reminderID,
    required this.userID,
    required this.medicineName,
  }) : super(key: key);

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  final ImagePicker _picker = ImagePicker();
  File? _image;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> captureImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        _image = File(image.path);
      });
    }
  }

Future<void> saveImageAndSendMessage() async {
  try {
    if (_image == null) return;

    // Create the file path for the image in Firebase Storage
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final imagePath = 'medicine_complete/${widget.userID}/$timestamp.jpg';
    final storageRef = FirebaseStorage.instance.ref().child(imagePath);

    // Upload the image to Firebase Storage
    final uploadTask = await storageRef.putFile(_image!);

    // Get the downloadable URL
    final downloadURL = await storageRef.getDownloadURL();

    // Save the image metadata in Firestore
    final imageRef = _firestore.collection('medicine_complete').doc();
    await imageRef.set({
      'userID': widget.userID,
      'reminderID': widget.reminderID,
      'medicineName': widget.medicineName,
      'imagePath': imagePath, // Firebase Storage path
      'imageUrl': downloadURL, // Direct URL to access the image
      'timestamp': DateTime.now(),
    });

    // Fetch guardian IDs
    final userDoc = await _firestore.collection('User').doc(widget.userID).get();
    final guardianIDsRaw = userDoc.data()?['guardianIDs'] ?? [];
    final guardianIDs = guardianIDsRaw.map((id) {
      if (id is DocumentReference) {
        return id.id;
      } else if (id is String) {
        return id;
      } else {
        throw Exception('Unexpected type for guardianID: $id');
      }
    }).toList();

    // Notify each guardian with the uploaded image
    for (final guardianID in guardianIDs) {
      final chatQuery = await _firestore
          .collection('Chat')
          .where('participants', arrayContains: widget.userID)
          .get();

      String? chatID;

      for (var doc in chatQuery.docs) {
        final participantsRaw = doc.data()['participants'] ?? [];
        final participants = participantsRaw.map((id) {
          if (id is DocumentReference) {
            return id.id;
          } else if (id is String) {
            return id;
          } else {
            throw Exception('Unexpected type for participant: $id');
          }
        }).toList();

        if (participants.contains(guardianID)) {
          chatID = doc.id;
          break;
        }
      }

      if (chatID == null) {
        print('No chat session found for guardianID: $guardianID');
        continue;
      }

      final messageID = _generateRandomID(20);
      final userName = userDoc.data()?['name'] ?? 'Unknown User';
      await _firestore
          .collection('Chat')
          .doc(chatID)
          .collection('Messages')
          .doc(messageID)
          .set({
        'receiverID': guardianID,
        'senderID': widget.userID,
        'senderName': userName,
        'imagePath': imagePath,
        'imageUrl': downloadURL,
        'timestamp': DateTime.now(),
      });
    }

    Navigator.pop(context);
  } catch (e) {
    print('Error saving image or sending message: $e');
  }
}

// Helper function to generate a random ID
String _generateRandomID(int length) {
  const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final rand = Random();
  return List.generate(length, (index) => chars[rand.nextInt(chars.length)]).join();
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Capture Medicine Image')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _image == null
                ? const Text('No image captured.')
                : Image.file(_image!, height: 300, width: 300),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: captureImage,
              child: const Text('Capture Image'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: saveImageAndSendMessage,
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }
}
