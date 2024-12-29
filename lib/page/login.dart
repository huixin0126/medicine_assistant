import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as f_User;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:medicine_assistant_app/class/user.dart';
import 'package:medicine_assistant_app/page/home.dart';
import 'package:medicine_assistant_app/page/profil.dart';
import 'package:medicine_assistant_app/page/register.dart';
import 'package:medicine_assistant_app/tflite_face_recognition.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:medicine_assistant_app/page/indexhome.dart';


class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isFaceLogin = false;
  late CameraController _cameraController;
  bool _isCameraInitialized = false;

  String _email = '';
  String _password = '';

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _cameraController = CameraController(
      cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      ),
      ResolutionPreset.medium,
    );

    try {
      await _cameraController.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            decoration: InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              return null;
            },
            onSaved: (value) => _email = value!,
          ),
          SizedBox(height: 16),
          TextFormField(
            decoration: InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              return null;
            },
            onSaved: (value) => _password = value!,
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: _handleLogin,
            child: Text('Login'),
            style: ElevatedButton.styleFrom(
              minimumSize: Size(double.infinity, 48),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaceLogin() {
    if (!_isCameraInitialized) {
      return Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        AspectRatio(
          aspectRatio: _cameraController.value.aspectRatio,
          child: CameraPreview(_cameraController),
        ),
        SizedBox(height: 16),
        ElevatedButton(
          onPressed: _handleFaceLogin,
          child: Text('Authenticate with Face'),
          style: ElevatedButton.styleFrom(
            minimumSize: Size(double.infinity, 48),
          ),
        ),
      ],
    );
  }

void _handleLogin() async {
  if (_formKey.currentState!.validate()) {
    _formKey.currentState!.save();

    try {
      // Authenticate the user with Firebase
      f_User.UserCredential userCredential = await f_User.FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email,
        password: _password,
      );

      String firebaseUID = userCredential.user!.uid;

      // Fetch user details from Firestore using the UID
      DocumentSnapshot userSnapshot =
          await FirebaseFirestore.instance.collection('User').doc(firebaseUID).get();

      if (userSnapshot.exists) {
        // Map Firestore data to User object
        User user = User(
          userID: userSnapshot['userID'], // Use the userID from Firestore
          name: userSnapshot['name'],
          email: userSnapshot['email'],
          phoneNo: userSnapshot['phoneNo'],
          emergencyContact: userSnapshot['emergencyContact'] ?? '',
          faceData: userSnapshot['faceData'] ?? '',
          guardianIDs: List<String>.from(userSnapshot['guardianIDs'] ?? []),
          seniorIDs: List<String>.from(userSnapshot['seniorIDs'] ?? []),
        );

        // Navigate to ProfilePage with the fetched user data
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomePage(userID: user.userID, user: user),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User data not found in Firestore.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    }
  }
}

//   void _handleFaceLogin() async {
//   try {
//     if (!_isCameraInitialized) {
//       throw Exception("Camera not initialized");
//     }

//     // Capture the image from the camera
//     final image = await _cameraController.takePicture();

//     // TODO: Implement face recognition logic here
//     // Example: Send the image to your face recognition backend or use a local model to authenticate the user

//     // Simulate a successful face recognition response with a recognized Firebase UID
//     String recognizedUID = "exampleFirebaseUID"; // Replace with actual UID after recognition

//     // Fetch user details from Firestore using the recognized UID
//     DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
//         .collection('User')
//         .doc(recognizedUID)
//         .get();

//     if (userSnapshot.exists) {
//       // Map Firestore data to User object
//       User user = User(
//         userID: userSnapshot['userID'], // Use the userID from Firestore
//         name: userSnapshot['name'],
//         email: userSnapshot['email'],
//         phoneNo: userSnapshot['phoneNo'],
//         faceData: userSnapshot['faceData'] ?? '',
//         guardianIDs: List<String>.from(userSnapshot['guardianIDs'] ?? []),
//         seniorIDs: List<String>.from(userSnapshot['seniorIDs'] ?? []),
//       );

//       // Navigate to HomePage with the fetched user data
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(
//           builder: (context) => HomePage(userID: user.userID, user: user),
//         ),
//       );
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Face authentication successful, but user data not found.')),
//       );
//     }
//   } catch (e) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Face authentication failed: $e')),
//     );
//   }
// }
void _handleFaceLogin() async {
  try {
    // Ensure the model is loaded before performing face recognition
    if (!isModelLoaded) {
      await loadModel(); // Load the model if not loaded yet
    }
    
    if (!_isCameraInitialized) {
      throw Exception("Camera not initialized");
    }

    // Capture the image from the camera
    final image = await _cameraController.takePicture();

    // Load the image as bytes
    final imageData = await image.readAsBytes();

    // Preprocess the image for the model (resize and normalize)
    final preprocessedImage = preprocessImage(imageData);

    // Run inference to get face embeddings
    final embeddings = runModel(preprocessedImage);

    // Authenticate with the embeddings by comparing with stored embeddings in Firestore
    final recognizedUID = await authenticateWithEmbeddings(embeddings);

    if (recognizedUID != null) {
      // Fetch user details from Firestore using the recognized UID
      DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('User')
          .doc(recognizedUID)
          .get();

      if (userSnapshot.exists) {
        // Map Firestore data to User object
        User user = User(
          userID: userSnapshot['userID'],
          name: userSnapshot['name'],
          email: userSnapshot['email'],
          phoneNo: userSnapshot['phoneNo'],
          faceData: userSnapshot['faceData'] ?? '',
          guardianIDs: List<String>.from(userSnapshot['guardianIDs'] ?? []),
          seniorIDs: List<String>.from(userSnapshot['seniorIDs'] ?? []),
        );

        // Navigate to HomePage with the fetched user data
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomePage(userID: user.userID, user: user),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Face authentication successful, but user data not found.')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Face authentication failed: Unable to match face.')),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Face authentication failed: $e')),
    );
  }
}


// Example: Preprocessing function to resize and normalize image
Uint8List preprocessImage(Uint8List imageData) {
  // Implement preprocessing logic here (resize, normalize, etc.)
  // For now, we're just returning the original image data
  return imageData;
}

// Run the model to extract embeddings
List<double> runModel(Uint8List input) {
  var output = List<double>.filled(128, 0); // Assuming 128-dimensional embeddings
  interpreter.run(input, output);  // 'interpreter' should be the inference engine you're using
  return output;
}

// Authenticate face by comparing embeddings with stored ones in Firestore
Future<String?> authenticateWithEmbeddings(List<double> embeddings) async {
  // Fetch stored embeddings from Firestore and compare with the given embeddings
  final storedEmbeddings = await fetchStoredEmbeddingsFromFirestore();

  if (storedEmbeddings != null) {
    // Calculate similarity (cosine similarity, Euclidean distance, etc.)
    double similarity = calculateSimilarity(embeddings, storedEmbeddings);

    // If similarity is above a threshold, return recognized UID
    if (similarity > 0.8) {  // Threshold can be adjusted
      return "recognizedUID";  // Replace with the actual UID after face matching
    }
  }

  return null;  // No match found
}

// Fetch stored embeddings from Firestore (for a given user)
Future<List<double>?> fetchStoredEmbeddingsFromFirestore() async {
  // Fetch user embeddings stored in Firestore
  // Example: Fetch the faceData or embeddings of a user from Firestore
  DocumentSnapshot snapshot = await FirebaseFirestore.instance
      .collection('User')
      .doc('userID')  // Replace with actual userID if available
      .get();

  if (snapshot.exists && snapshot.data() != null) {
    return List<double>.from(snapshot['faceData']);
  }

  return null;
}

// Calculate similarity between two embeddings (cosine similarity)
double calculateSimilarity(List<double> embedding1, List<double> embedding2) {
  double dotProduct = 0;
  double norm1 = 0;
  double norm2 = 0;

  for (int i = 0; i < embedding1.length; i++) {
    dotProduct += embedding1[i] * embedding2[i];
    norm1 += embedding1[i] * embedding1[i];
    norm2 += embedding2[i] * embedding2[i];
  }

  return dotProduct / (sqrt(norm1) * sqrt(norm2));
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  label: Text('Manual Login'),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Face Login'),
                ),
              ],
              selected: {_isFaceLogin},
              onSelectionChanged: (Set<bool> selected) {
                setState(() {
                  _isFaceLogin = selected.first;
                });
              },
            ),
            SizedBox(height: 24),
            _isFaceLogin ? _buildFaceLogin() : _buildLoginForm(),
            SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => RegisterPage()),
                );
              },
              child: Text("Don't have an account? Register"),
            ),
          ],
        ),
      ),
    );
  }
}
