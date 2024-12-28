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
  bool _isLoading = false;

  Future<void> captureImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        _image = File(image.path);
      });
    }
  }

   Future<void> saveImageAndSendMessage() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_image == null) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('No Image Captured'),
              content: const Text('Please capture an image before proceeding.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
        return;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final imagePath = 'medicine_complete/${widget.userID}/$timestamp.jpg';
      final storageRef = FirebaseStorage.instance.ref().child(imagePath);

      // Upload with error handling
      try {
        await storageRef.putFile(_image!);
      } catch (e) {
        print('Error uploading file: $e');
        throw Exception('Failed to upload image');
      }

      // Get URL with error handling
      String downloadURL;
      try {
        downloadURL = await storageRef.getDownloadURL();
      } catch (e) {
        print('Error getting download URL: $e');
        throw Exception('Failed to get image URL');
      }

      // Save metadata with error handling
      try {
        final imageRef = _firestore.collection('medicine_complete').doc();
        await imageRef.set({
          'userID': widget.userID,
          'reminderID': widget.reminderID,
          'medicineName': widget.medicineName,
          'imagePath': imagePath,
          'imageUrl': downloadURL,
          'timestamp': FieldValue.serverTimestamp(), // Use server timestamp
        });
      } catch (e) {
        print('Error saving metadata: $e');
        throw Exception('Failed to save image metadata');
      }

      // Fetch guardian IDs with error handling
      // List<String> guardianIDs = [];
      // try {
      //   final userDoc = await _firestore.collection('User').doc(widget.userID).get();
      //   final guardianIDsRaw = userDoc.data()?['guardianIDs'] ?? [];
      //   guardianIDs = guardianIDsRaw.map((id) => id is DocumentReference ? id.id : id.toString()).toList();
      // } catch (e) {
      //   print('Error fetching guardian IDs: $e');
      //   throw Exception('Failed to fetch guardian IDs');
      // }

      List<String> guardianIDs = [];
      try {
        final userDoc = await _firestore.collection('User').doc(widget.userID).get();
        final guardianIDsRaw = userDoc.data()?['guardianIDs'] ?? [];
        
        // Handle different types of guardian ID references
        guardianIDs = guardianIDsRaw.map<String>((id) {
          if (id is DocumentReference) {
            return id.id;
          } else if (id is String) {
            // Handle full paths like "/User/mdYq0XZsXHfCc6IHGsHLMzHc2S72"
            return id.startsWith('/User/') ? id.split('/').last : id;
          }
          return id.toString();
        }).toList();

        if (guardianIDs.isEmpty) {
          print('Warning: No guardian IDs found for user');
        }
      } catch (e) {
        print('Error fetching guardian IDs: $e');
        throw Exception('Failed to fetch guardian IDs');
      }

      // Send messages to guardians
      for (final guardianID in guardianIDs) {
        try {
          String? chatID = await _findOrCreateChat(guardianID);
          if (chatID != null) {
            await _sendMessageToGuardian(chatID, guardianID, downloadURL);
          }
        } catch (e) {
          print('Error processing guardian $guardianID: $e');
          // Continue with other guardians even if one fails
          continue;
        }
      }

      Navigator.pop(context);
    } catch (e) {
      print('Error in saveImageAndSendMessage: $e');
      // Show error dialog
      showDialog(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Error'),
          content: Text('Failed to process image: ${e.toString()}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<String?> _findOrCreateChat(String guardianID) async {
    final chatQuery = await _firestore
        .collection('Chat')
        .where('participants', arrayContains: widget.userID)
        .get();

    for (var doc in chatQuery.docs) {
      final participants = List<String>.from(doc.data()['participants'] ?? []);
      if (participants.contains(guardianID)) {
        return doc.id;
      }
    }

    // Create new chat if none exists
    final newChatRef = _firestore.collection('Chat').doc();
    await newChatRef.set({
      'participants': [widget.userID, guardianID],
      'createdAt': FieldValue.serverTimestamp(),
    });
    return newChatRef.id;
  }

  Future<void> _sendMessageToGuardian(String chatID, String guardianID, String imageUrl) async {
    final messageID = _generateRandomID(20);
    final userDoc = await _firestore.collection('User').doc(widget.userID).get();
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
      'imageUrl': imageUrl,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

//   Future<void> saveImageAndSendMessage() async {
//   setState(() {
//     _isLoading = true;
//   });

//   try {
//     // Check if the image is null
//     if (_image == null) {
//       // Show an alert dialog if no image is captured
//       showDialog(
//         context: context,
//         builder: (BuildContext context) {
//           return AlertDialog(
//             title: const Text('No Image Captured'),
//             content: const Text('Please capture an image before proceeding.'),
//             actions: [
//               TextButton(
//                 onPressed: () {
//                   Navigator.of(context).pop(); // Close the dialog
//                 },
//                 child: const Text('OK'),
//               ),
//             ],
//           );
//         },
//       );
//       return;
//     }

//     // Proceed with saving the image and sending the message as usual
//     // Create the file path for the image in Firebase Storage
//     final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
//     final imagePath = 'medicine_complete/${widget.userID}/$timestamp.jpg';
//     final storageRef = FirebaseStorage.instance.ref().child(imagePath);

//     // Upload the image to Firebase Storage
//     await storageRef.putFile(_image!);

//     // Get the downloadable URL
//     final downloadURL = await storageRef.getDownloadURL();

//     // Save the image metadata in Firestore
//     final imageRef = _firestore.collection('medicine_complete').doc();
//     await imageRef.set({
//       'userID': widget.userID,
//       'reminderID': widget.reminderID,
//       'medicineName': widget.medicineName,
//       'imagePath': imagePath, // Firebase Storage path
//       'imageUrl': downloadURL, // Direct URL to access the image
//       'timestamp': DateTime.now(),
//     });

//     // Fetch guardian IDs
//     final userDoc = await _firestore.collection('User').doc(widget.userID).get();
//     final guardianIDsRaw = userDoc.data()?['guardianIDs'] ?? [];
//     final guardianIDs = guardianIDsRaw.map((id) {
//       if (id is DocumentReference) {
//         return id.id;
//       } else if (id is String) {
//         return id;
//       } else {
//         throw Exception('Unexpected type for guardianID: $id');
//       }
//     }).toList();

//     // Notify each guardian with the uploaded image
//     for (final guardianID in guardianIDs) {
//       final chatQuery = await _firestore
//           .collection('Chat')
//           .where('participants', arrayContains: widget.userID)
//           .get();

//       String? chatID;

//       for (var doc in chatQuery.docs) {
//         final participantsRaw = doc.data()['participants'] ?? [];
//         final participants = participantsRaw.map((id) {
//           if (id is DocumentReference) {
//             return id.id;
//           } else if (id is String) {
//             return id;
//           } else {
//             throw Exception('Unexpected type for participant: $id');
//           }
//         }).toList();

//         if (participants.contains(guardianID)) {
//           chatID = doc.id;
//           break;
//         }
//       }

//       if (chatID == null) {
//         print('No chat session found for guardianID: $guardianID');
//         continue;
//       }

//       final messageID = _generateRandomID(20);
//       final userName = userDoc.data()?['name'] ?? 'Unknown User';
//       await _firestore
//           .collection('Chat')
//           .doc(chatID)
//           .collection('Messages')
//           .doc(messageID)
//           .set({
//         'receiverID': guardianID,
//         'senderID': widget.userID,
//         'senderName': userName,
//         'imagePath': imagePath,
//         'imageUrl': downloadURL,
//         'timestamp': DateTime.now(),
//       });
//     }

//     Navigator.pop(context);
//   } catch (e) {
//     print('Error saving image or sending message: $e');
//   } finally {
//     setState(() {
//       _isLoading = false;
//     });
//   }
// }


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
      body: Stack(
        children: [
          Center(
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
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
