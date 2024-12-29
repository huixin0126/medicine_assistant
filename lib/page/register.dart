import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:medicine_assistant_app/class/user.dart';
import 'package:medicine_assistant_app/page/profil.dart';
import 'package:firebase_auth/firebase_auth.dart' as f_User;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  late CameraController _cameraController;
  bool _isCameraInitialized = false;
  String? _capturedFaceData;

  String _name = '';
  String _email = '';
  String _password = '';
  String _phoneNo = '';

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

  Future<void> _captureFace() async {
    if (!_isCameraInitialized) return;

    try {
      final image = await _cameraController.takePicture();
      setState(() {
        _capturedFaceData = image.path;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Face data captured')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to capture face data')),
      );
    }
  }
Future<void> _handleRegister() async {
  if (_formKey.currentState!.validate()) {
    _formKey.currentState!.save();

    try {
      // Firebase authentication logic to register the user
      f_User.UserCredential userCredential = await f_User.FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email,
        password: _password,
      );
      
      print("User registered with email: $_email");

      // Get the device token for push notifications (optional)
      String deviceToken = await FirebaseMessaging.instance.getToken() ?? '';
      print("Device Token: $deviceToken");

      // Generate a random userID (or use a unique method for user ID)
      String userID = DateTime.now().millisecondsSinceEpoch.toString();

      // Upload the face image to Firebase Storage
      String imageUrl = '';
      if (_capturedFaceData != null) {
        // Upload image to Firebase Storage
        final storageReference = FirebaseStorage.instance.ref().child('face_images/$userID.jpg');
        final uploadTask = storageReference.putFile(File(_capturedFaceData!));
        final snapshot = await uploadTask.whenComplete(() {});
        imageUrl = await snapshot.ref.getDownloadURL();
      }

      // Create a new user object to store in Firestore
      User user = User(
        userID: userID,
        name: _name,
        email: _email,
        phoneNo: _phoneNo,
        faceData: imageUrl, // Save the image URL
      );

      // Store user data in Firestore
      try {
        await FirebaseFirestore.instance.collection('User').doc(userCredential.user!.uid).set({
          'avatar': '', // This field is optional, but is required for your structure
          'deviceToken': deviceToken,
          'email': _email,
          'emergencyContact': '', // Add default if necessary
          'faceData': imageUrl, // Save the face data URL
          'guardianIDs': [],
          'name': _name,
          'phoneNo': _phoneNo,
          'seniorIDs': [],
          'userID': userCredential.user!.uid,
        });
        
        print('User data saved to Firestore with userID: $userID');
      } catch (e) {
        print('Error saving user data to Firestore: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save user data: $e'))
        );
        return; // Exit the function to prevent navigation if Firestore saving failed
      }

      // Navigate to the profile page with the user data
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ProfilePage(userID: userID),
        ),
      );
    } catch (e) {
      // Firebase authentication failure
      print('Registration failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: $e'))
      );
    }
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Register')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
                onSaved: (value) => _name = value!,
              ),
              SizedBox(height: 16),
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
              SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your phone number';
                  }
                  return null;
                },
                onSaved: (value) => _phoneNo = value!,
              ),
              SizedBox(height: 24),
              if (_isCameraInitialized) ...[
                AspectRatio(
                  aspectRatio: _cameraController.value.aspectRatio,
                  child: CameraPreview(_cameraController),
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _captureFace,
                  child: Text('Capture Face Data'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 48),
                  ),
                ),
              ],
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _handleRegister,
                child: Text('Register'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
