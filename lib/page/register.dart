import 'dart:io';
import 'dart:core';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
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
import 'package:medicine_assistant_app/service/facenet_service.dart';

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

Future<File> resizeImageIsolate(File imageFile) async {
    final originalImage = img.decodeImage(imageFile.readAsBytesSync());
    final resizedImage = img.copyResize(originalImage!, width: 800);
    final resizedImageBytes = Uint8List.fromList(img.encodeJpg(resizedImage));
    final resizedImageFile = File(imageFile.path)..writeAsBytesSync(resizedImageBytes);
    return resizedImageFile;
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
  try {
    final capturedImage = await Navigator.push<File>(
      context,
      MaterialPageRoute(
        builder: (context) => CameraRegisterPage(
          onCapture: (File image) {}, // Empty function since we're not using it
        ),
      ),
    );

    if (capturedImage != null && mounted) {
      try {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return const Center(child: CircularProgressIndicator());
          },
        );

        // Process image
        final inputImage = InputImage.fromFile(capturedImage);
        final faces = await _faceDetector.processImage(inputImage);

        // Hide loading indicator
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        if (mounted) {
          setState(() {
            _capturedImage = capturedImage;
            _detectedFaces = faces;
          });

          if (faces.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No faces detected. Please try again.')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Face detected successfully!')),
            );
          }
        }
      } catch (e) {
        // Hide loading indicator if showing
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error processing image: ${e.toString()}')),
          );
        }
      }
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error capturing image: ${e.toString()}')),
      );
    }
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

// Future<void> _handleRegister() async {
//   if (!_formKey.currentState!.validate()) return;
  
//   if (_capturedImage == null || _detectedFaces == null || _detectedFaces!.isEmpty) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(content: Text('Please capture your face first')),
//     );
//     return;
//   }

//   _formKey.currentState!.save();

//   try {
//     // Show loading indicator
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) => const Center(child: CircularProgressIndicator()),
//     );
//
//     // Create user account
//     final userCredential = await f_User.FirebaseAuth.instance
//         .createUserWithEmailAndPassword(email: _email, password: _password);
//     final uid = userCredential.user!.uid;

//     // Get device token
//     final deviceToken = await FirebaseMessaging.instance.getToken() ?? '';

//     // Upload face image
//     final storageRef = FirebaseStorage.instance
//         .ref()
//         .child('face_images/$uid.jpg');
//     final resizedImage = await compute(resizeImageIsolate, _capturedImage!);
//     final uploadTask = storageRef.putFile(resizedImage);
//     final snapshot = await uploadTask;
//     final imageUrl = await snapshot.ref.getDownloadURL();

//     // Generate face embedding
//     final faceAuthHandler = FaceAuthHandler();
//     await faceAuthHandler.initialize();
//     final faceData = await faceAuthHandler.registerFace(_capturedImage!);
    
//     if (faceData == null) {
//       throw Exception('Failed to generate face embedding');
//     }

//     // Save user data
//     await FirebaseFirestore.instance
//         .collection('User')
//         .doc(uid)
//         .set({
//       'avatar': '',
//       'deviceToken': deviceToken,
//       'email': _email,
//       'faceImageUrl': imageUrl,
//       'faceEmbedding': faceData['embedding'],
//       'name': _name,
//       'phoneNo': _phoneNo,
//       'userID': uid,
//       'emergencyContact': '',
//       'seniorIDs': [],
//       'guardianIDs': [],
//     });

//     // Navigate to login
//     if (mounted) {
//       Navigator.pop(context); // Remove loading
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Registration successful! Please login.')),
//       );
//       await Future.delayed(const Duration(seconds: 1));
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(builder: (context) => LoginPage()),
//       );
//     }
//   } catch (e) {
//     if (mounted) {
//       Navigator.pop(context); // Remove loading
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Registration failed: ${e.toString()}')),
//       );
//     }
//   }
// }

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

// class FaceAuthHandler {
//   final FaceNetService _faceNetService = FaceNetService();
//   static const double DISTANCE_THRESHOLD = 1.0; // Adjust based on testing

//   Future<void> initialize() async {
//     await _faceNetService.loadModel();
//   }

//   Future<Map<String, dynamic>?> registerFace(File imageFile) async {
//     try {
//       List<double> embedding = _faceNetService.getFaceEmbedding(imageFile) as List<double>;
//       return {
//         'embedding': embedding,
//         'imageUrl': imageFile.path,
//       };
//     } catch (e) {
//       print('Error registering face: $e');
//       return null;
//     }
//   }

//   Future<bool> verifyFace(List<double> storedEmbedding, File currentImage) async {
//     try {
//       List<double> currentEmbedding = _faceNetService.getFaceEmbedding(currentImage) as List<double>;
//       double distance = _faceNetService.euclideanDistance(storedEmbedding, currentEmbedding);
//       return distance < DISTANCE_THRESHOLD;
//     } catch (e) {
//       print('Error verifying face: $e');
//       return false;
//     }
//   }
// }