import 'dart:io';
import 'dart:core';
import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:medicine_assistant_app/class/user.dart';
import 'package:medicine_assistant_app/page/profil.dart';
import 'package:firebase_auth/firebase_auth.dart' as f_User;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:medicine_assistant_app/page/cameraRegister.dart';
import 'package:medicine_assistant_app/page/login.dart';

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

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      enableClassification: true,
      enableTracking: true,
      // minFaceSize: 0.1, // Change the minimum face size if needed
    ),
  );
  
  File? _capturedImage;
  List<Face>? _detectedFaces;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<File> _resizeImage(File imageFile) async {
  final originalImage = img.decodeImage(imageFile.readAsBytesSync());
  final resizedImage = img.copyResize(originalImage!, width: 800);

  final resizedImageBytes = Uint8List.fromList(img.encodeJpg(resizedImage));
  final resizedImageFile = File(imageFile.path)..writeAsBytesSync(resizedImageBytes);

  return resizedImageFile;
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
  if (_isCameraInitialized) {
    _cameraController.dispose();
  }
  _faceDetector.close();
  super.dispose();
}

Future<void> _openCamera() async {
  // Open the camera page and capture the image
  final capturedImage = await Navigator.push<File>(
    context,
    MaterialPageRoute(
      builder: (context) => CameraRegisterPage(
        onCapture: (File image) {
          setState(() {
            _capturedImage = image;
          });
        },
      ),
    ),
  );

  if (capturedImage != null) {
    try {
      // Delay the image resizing operation to avoid blocking the main thread
      await Future.delayed(Duration(milliseconds: 100)); // Adjust delay as necessary

      // Resize the captured image
      final resizedImage = await _resizeImage(capturedImage);

      // Process the resized image for face detection
      final inputImage = InputImage.fromFile(resizedImage);
      final faces = await _faceDetector.processImage(inputImage);

      // Update the state with the detected faces
      setState(() {
        _capturedImage = resizedImage;
        _detectedFaces = faces;
      });

      if (faces.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No faces detected. Please try again.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Faces detected!')),
        );
      }
    } catch (e) {
      print('Error during face detection: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Face detection failed: $e')),
      );
    }
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No image captured. Please try again.')),
    );
  }
}


//  Future<void> _captureFace() async {
//   if (!_isCameraInitialized) return;

//   try {
//     // Capture the image from the camera
//     final image = await _cameraController.takePicture();
//     final inputImage = InputImage.fromFilePath(image.path);

//     // Process the image with the face detector
//     final faces = await _faceDetector.processImage(inputImage);

//     if (faces.isEmpty) {
//       // Notify the user if no face is detected
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('No face detected. Please try again.')),
//       );
//       return;
//     }

//     // Update the state with the captured image and detected faces
//     setState(() {
//       _capturedImage = File(image.path);
//       _detectedFaces = faces;
//     });

//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Face captured successfully.')),
//     );
//   } catch (e) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Failed to capture face: $e')),
//     );
//   }
// }

Future<void> _handleRegister() async {
  if (_formKey.currentState!.validate()) {
    if (_capturedImage == null || _detectedFaces == null || _detectedFaces!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please capture your face first.')),
      );
      return;
    }

    _formKey.currentState!.save();

    try {
      f_User.UserCredential userCredential = await f_User.FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: _email, password: _password);

      String deviceToken = await FirebaseMessaging.instance.getToken() ?? '';

      final storageReference = FirebaseStorage.instance
          .ref()
          .child('face_images/${userCredential.user!.uid}.jpg');
      final uploadTask = storageReference.putFile(_capturedImage!);

      // Await for upload completion
      final snapshot = await uploadTask.whenComplete(() {});

      // Get the download URL
      final imageUrl = await snapshot.ref.getDownloadURL();

      // Prepare face data for Firestore
      final faceData = _detectedFaces!.first;
      final landmarks = {
        'leftEye': [
          faceData.landmarks[FaceLandmarkType.leftEye]?.position.x ?? 0.0,
          faceData.landmarks[FaceLandmarkType.leftEye]?.position.y ?? 0.0,
        ],
        'rightEye': [
          faceData.landmarks[FaceLandmarkType.rightEye]?.position.x ?? 0.0,
          faceData.landmarks[FaceLandmarkType.rightEye]?.position.y ?? 0.0,
        ],
        'nose': [
          faceData.landmarks[FaceLandmarkType.noseBase]?.position.x ?? 0.0,
          faceData.landmarks[FaceLandmarkType.noseBase]?.position.y ?? 0.0,
        ],
        'leftMouth': [
          faceData.landmarks[FaceLandmarkType.leftMouth]?.position.x ?? 0.0,
          faceData.landmarks[FaceLandmarkType.leftMouth]?.position.y ?? 0.0,
        ],
        'rightMouth': [
          faceData.landmarks[FaceLandmarkType.rightMouth]?.position.x ?? 0.0,
          faceData.landmarks[FaceLandmarkType.rightMouth]?.position.y ?? 0.0,
        ],
      };

      // Save data to Firestore
      await FirebaseFirestore.instance
          .collection('User')
          .doc(userCredential.user!.uid)
          .set({
        'avatar': '',
        'deviceToken': deviceToken,
        'email': _email,
        'faceData': landmarks,
        'faceImageUrl': imageUrl,
        'name': _name,
        'phoneNo': _phoneNo,
        'userID': userCredential.user!.uid,
        'emergencyContact': '',
        'seniorIDs': [],
        'guardianIDs': [],
      });

      // Remove loading indicator
      Navigator.pop(context);

      // Show success message before navigation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration successful! Please login.')),
      );

      // Wait for snackbar to be visible before navigation
      await Future.delayed(Duration(seconds: 1));

      // Navigate to login page
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LoginPage(),
          ),
        );
      }
    } catch (e) {
      print('Registration failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: $e')),
      );
    }
  }
}


  void handleCapturedImage(XFile image) {
  // Process the captured image
  print('Captured image path: ${image.path}');
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
                decoration: InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                onSaved: (value) => _name = value!,
              ),
              SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                onSaved: (value) => _email = value!,
              ),
              SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                onSaved: (value) => _password = value!,
                obscureText: true,
              ),
              SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()),
                onSaved: (value) => _phoneNo = value!,
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _openCamera,
                child: const Text('Open Camera'),
              ),
              SizedBox(height: 16),
              if (_capturedImage != null)
                Container(
                  height: 200,
                  width: double.infinity,
                  child: Image.file(
                    _capturedImage!,
                    fit: BoxFit.cover,
                  ),
                ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _handleRegister,
                child: Text('Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
