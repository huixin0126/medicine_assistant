import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:core';

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
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isFaceLogin = false;
  late CameraController _cameraController;
  bool _isCameraInitialized = false;
  File? _capturedImage;

  String _email = '';
  String _password = '';
  bool _isProcessing = false;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      enableClassification: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _faceDetector.close();
    if (_isCameraInitialized) {
      _cameraController.dispose();
    }
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      _cameraController = CameraController(
        cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        ),
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      print('Error initializing camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize camera: $e')),
        );
      }
    }
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
  return Column(
    children: [
      if (_capturedImage != null)
        Container(
          height: 200,
          width: double.infinity,
          child: Image.file(
            _capturedImage!,
            fit: BoxFit.cover,
          ),
        ),
      SizedBox(height: 16),
      ElevatedButton(
        onPressed: _captureImage,
        child: Text('Take Picture'),
        style: ElevatedButton.styleFrom(
          minimumSize: Size(double.infinity, 48),
        ),
      ),
      SizedBox(height: 16),
      ElevatedButton(
        onPressed: _capturedImage != null ? _handleFaceLogin : null,
        child: Text('Login with Face'),
        style: ElevatedButton.styleFrom(
          minimumSize: Size(double.infinity, 48),
          // Button will be disabled if no image is captured
          backgroundColor: _capturedImage != null ? null : Colors.grey,
        ),
      ),
    ],
  );
}


Future<void> _handleTakePicture() async {
    try {
      if (!_isCameraInitialized) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera not initialized')),
        );
        return;
      }

      final image = await _cameraController.takePicture();
      await _processImage(image.path);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error taking picture: $e')),
      );
    }
  }

  Future<void> _handleSelectImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        await _processImage(pickedFile.path);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No image selected')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting image: $e')),
      );
    }
  }

  Future<void> _captureImage() async {
  final picker = ImagePicker();
  try {
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _capturedImage = File(pickedFile.path);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No image captured')),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error capturing image: $e')),
    );
  }
}

  Future<void> _processImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        throw Exception('No face detected in the image');
      }

      // Get face landmarks for comparison
      final face = faces.first;
      final currentLandmarks = {
        'leftEye': [
          face.landmarks[FaceLandmarkType.leftEye]?.position.x,
          face.landmarks[FaceLandmarkType.leftEye]?.position.y,
        ],
        'rightEye': [
          face.landmarks[FaceLandmarkType.rightEye]?.position.x,
          face.landmarks[FaceLandmarkType.rightEye]?.position.y,
        ],
        'nose': [
          face.landmarks[FaceLandmarkType.noseBase]?.position.x,
          face.landmarks[FaceLandmarkType.noseBase]?.position.y,
        ],
        'leftMouth': [
          face.landmarks[FaceLandmarkType.leftMouth]?.position.x,
          face.landmarks[FaceLandmarkType.leftMouth]?.position.y,
        ],
        'rightMouth': [
          face.landmarks[FaceLandmarkType.rightMouth]?.position.x,
          face.landmarks[FaceLandmarkType.rightMouth]?.position.y,
        ],
      };
      print('Current Landmarks: $currentLandmarks');


      // Query Firestore for matching face data
      final querySnapshot = await FirebaseFirestore.instance
          .collection('User')
          .get();

      String? matchedUserId;
      double bestMatch = 0;
      
      // Compare with stored face data
      for (var doc in querySnapshot.docs) {
        final storedFaceData = doc.data()['faceData'];
        if (storedFaceData != null) {
          try {
            Map<String, dynamic> storedFaceMap = Map<String, dynamic>.from(storedFaceData);
            final similarity = FaceRecognitionUtils.calculateFaceSimilarity(currentLandmarks, storedFaceMap);
            if (FaceRecognitionUtils.isFaceMatch(similarity)) {
              bestMatch = similarity;
              matchedUserId = doc.id;
            }
          } catch (e) {
            print('Error processing stored face data: $e');
            continue;
          }
        }
      }

      if (matchedUserId != null) {
        // Fetch user data and navigate
        DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
            .collection('User')
            .doc(matchedUserId)
            .get();

        User user = User(
          userID: userSnapshot['userID'],
          name: userSnapshot['name'],
          email: userSnapshot['email'],
          phoneNo: userSnapshot['phoneNo'],
          faceData: userSnapshot['faceImageUrl'] ?? '',
          guardianIDs: List<String>.from(userSnapshot['guardianIDs'] ?? []),
          seniorIDs: List<String>.from(userSnapshot['seniorIDs'] ?? []),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomePage(userID: user.userID, user: user),
          ),
        );
      } else {
        throw Exception("No matching user found");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Face authentication failed: $e')),
      );
    }
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
        // Convert DocumentSnapshot to Map<String, dynamic>
        Map<String, dynamic> userData = userSnapshot.data() as Map<String, dynamic>;
        
        // Use the factory constructor to create User object
        User user = User.fromJson(userData);

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

 Future<File> _resizeImage(File imageFile) async {
  final originalImage = img.decodeImage(imageFile.readAsBytesSync());
  final resizedImage = img.copyResize(originalImage!, width: 800);

  final resizedImageBytes = Uint8List.fromList(img.encodeJpg(resizedImage));
  final resizedImageFile = File(imageFile.path)..writeAsBytesSync(resizedImageBytes);

  return resizedImageFile;
}


Future<void> _handleFaceLogin() async {
  if (!mounted || _capturedImage == null || _isProcessing) return;
  
  setState(() => _isProcessing = true);
  
  try {
    // Show loading indicator
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 20),
                  Text("Verifying face..."),
                ],
              ),
            ),
          );
        },
      );
    }
    
    // Resize the captured image
    final resizedImage = await _resizeImage(_capturedImage!);

    // Process the resized image for face detection
    final inputImage = InputImage.fromFile(resizedImage);
    final faces = await _faceDetector.processImage(inputImage);

    if (faces.isEmpty) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _showError("No face detected. Please try again.");
      return;
    }

    final face = faces.first;
    final currentLandmarks = _extractFaceLandmarks(face);

    print('Current Landmarks: $currentLandmarks');

    if (currentLandmarks == null) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _showError("Could not detect facial features clearly");
      return;
    }

    // Query Firestore with proper null safety
    QuerySnapshot querySnapshot;
    try {
      querySnapshot = await FirebaseFirestore.instance
          .collection('User')
          .get()
          .timeout(Duration(seconds: 10));
    } on TimeoutException {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _showError("Connection timeout. Please check your internet and try again.");
      return;
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _showError("Failed to connect to database: ${e.toString()}");
      return;
    }

    String? matchedUserId;
    double bestMatch = 0;
    
    // Compare with stored face data with proper null checking
    for (var doc in querySnapshot.docs) {
      if (!mounted) return;

      // Safely cast document data to a Map<String, dynamic>
      final data = doc.data() as Map<String, dynamic>?; // Ensure data is a map
      if (data == null) continue; // Skip if data is null

      // Safely access and cast 'faceData'
      final storedFaceData = data['faceData'];
      if (storedFaceData != null && storedFaceData is Map<String, dynamic>) {
        try {
          print('Stored Face Data for ${doc.id}: $storedFaceData');
          // Process the face data if it's valid
          double similarity = _calculateFaceSimilarity(currentLandmarks, storedFaceData);
          print('Similarity for ${doc.id}: $similarity');
          if (similarity > 80 && similarity > bestMatch) {
            bestMatch = similarity;
            matchedUserId = doc.id;
          }
        } catch (e) {
          print('Error processing stored face data for doc ${doc.id}: $e');
          continue;
        }
      } else {
        print('Invalid or missing face data for doc ${doc.id}');
      }
    }

    if (!mounted) return;

    if (matchedUserId == null) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _showError("Face not recognized. Please try again or use manual login.");
      return;
    }

    // Fetch user data with proper null safety
    DocumentSnapshot userDoc;
    try {
      userDoc = await FirebaseFirestore.instance
          .collection('User')
          .doc(matchedUserId)
          .get()
          .timeout(Duration(seconds: 5));
    } on TimeoutException {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _showError("Failed to fetch user data. Please check your internet and try again.");
      return;
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _showError("Error fetching user data: ${e.toString()}");
      return;
    }

    if (!mounted) return;

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    if (!userDoc.exists) {
      _showError("User data not found.");
      return;
    }

    try {
  // Safe access to document data with null checking
  final userData = userDoc.data() as Map<String, dynamic>?; // Ensure the data is cast to a map
  if (userData == null) {
    _showError("Invalid user data format.");
    return;
  }

  // Create user object with null safety
  User user = User(
    userID: userData['userID'] as String? ?? '',
    name: userData['name'] as String? ?? '',
    email: userData['email'] as String? ?? '',
    phoneNo: userData['phoneNo'] as String? ?? '',
    faceData: userData['faceData'] != null
        ? Map<String, dynamic>.from(userData['faceData'])
        : null, // Ensure faceData is properly cast to a Map
    guardianIDs: userData['guardianIDs'] != null
        ? List<String>.from(userData['guardianIDs'])
        : [], // Handle null for guardianIDs
    seniorIDs: userData['seniorIDs'] != null
        ? List<String>.from(userData['seniorIDs'])
        : [], // Handle null for seniorIDs
  );

  if (mounted) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomePage(userID: user.userID, user: user),
      ),
    );
  }
} catch (e) {
  _showError("Error processing user data: ${e.toString()}");
}


  } catch (e) {
    if (mounted) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _showError(e.toString());
    }
  } finally {
    if (mounted) {
      setState(() => _isProcessing = false);
    }
  }
}

// Helper method to show errors
void _showError(String message) {
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// Helper method to check if dialog is showing
bool _isDialogShowing(BuildContext context) {
  return ModalRoute.of(context)?.isCurrent != true;
}

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Verifying face...'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _dismissLoadingDialog() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

Map<String, List<int>>? _extractFaceLandmarks(Face face) {
    try {
      final landmarks = {
        'leftEye': [
          face.landmarks[FaceLandmarkType.leftEye]?.position.x ?? 0,
          face.landmarks[FaceLandmarkType.leftEye]?.position.y ?? 0,
        ],
        'rightEye': [
          face.landmarks[FaceLandmarkType.rightEye]?.position.x ?? 0,
          face.landmarks[FaceLandmarkType.rightEye]?.position.y ?? 0,
        ],
        'nose': [
          face.landmarks[FaceLandmarkType.noseBase]?.position.x ?? 0,
          face.landmarks[FaceLandmarkType.noseBase]?.position.y ?? 0,
        ],
        'leftMouth': [
          face.landmarks[FaceLandmarkType.leftMouth]?.position.x ?? 0,
          face.landmarks[FaceLandmarkType.leftMouth]?.position.y ?? 0,
        ],
        'rightMouth': [
          face.landmarks[FaceLandmarkType.rightMouth]?.position.x ?? 0,
          face.landmarks[FaceLandmarkType.rightMouth]?.position.y ?? 0,
        ],
      };

      // Validate that we have valid coordinates
      bool hasValidLandmarks = landmarks.values.every((points) => 
        points[0] != 0 && points[1] != 0
      );

      return hasValidLandmarks ? landmarks : null;
    } catch (e) {
      print('Error extracting face landmarks: $e');
      return null;
    }
  }

// double _calculateFaceSimilarity(
//     Map<String, List<int>> currentLandmarks,
//     Map<String, dynamic> storedFaceData,
//     {int imageWidth = 800, int imageHeight = 800}) {
//   double totalDistance = 0;
//   int featureCount = 0;

//   try {
//     for (var key in storedFaceData.keys) {
//       if (currentLandmarks.containsKey(key) &&
//           storedFaceData[key] is List<dynamic>) {
//         final currentPoints = currentLandmarks[key]!;
//         final storedPoints = List<int>.from(storedFaceData[key]);

//         // Normalize points
//         final normalizedCurrent = currentPoints.map((p) => p.toDouble() / imageWidth).toList();
//         final normalizedStored = storedPoints.map((p) => p.toDouble() / imageWidth).toList();

//         // Ensure both points have the same length
//         if (normalizedCurrent.length == normalizedStored.length) {
//           for (int i = 0; i < normalizedCurrent.length; i++) {
//             totalDistance += (normalizedCurrent[i] - normalizedStored[i]) *
//                 (normalizedCurrent[i] - normalizedStored[i]);
//           }
//           featureCount++;
//         }
//       }
//     }
//   } catch (e) {
//     print('Error in similarity calculation: $e');
//     return 0.0; // Return 0.0 if there’s any error
//   }

//   // Avoid division by zero
//   if (featureCount == 0) return 0.0;

//   // Calculate the final similarity score
//   double averageDistance = totalDistance / featureCount;
//   double similarity = (1 - averageDistance.clamp(0.0, 1.0)) * 100; // Scale to percentage
//   return similarity;
// }

double _calculateFaceSimilarity(
  Map<String, List<int>> currentLandmarks,
  Map<String, dynamic> storedFaceData,
  {int imageWidth = 800, int imageHeight = 800}) {
  double weightedDistanceSum = 0.0;
  double totalWeight = 0.0;

  try {
    final featureWeights = {
      'leftEye': 2.0,
      'rightEye': 2.0,
      'nose': 1.5,
      'leftMouth': 1.0,
      'rightMouth': 1.0
    };

    // Validate input
    if (currentLandmarks.isEmpty || storedFaceData.isEmpty) {
      print("Empty or missing landmarks data.");
      return 0.0;
    }

    for (var key in featureWeights.keys) {
      if (currentLandmarks.containsKey(key) && storedFaceData.containsKey(key)) {
        final currentPoints = currentLandmarks[key]!;
        final storedPoints = List<int>.from(storedFaceData[key]);

        // Normalize coordinates to a range [0, 1]
        final normalizedCurrentX = currentPoints[0].toDouble() / imageWidth;
        final normalizedCurrentY = currentPoints[1].toDouble() / imageHeight;

        final normalizedStoredX = storedPoints[0].toDouble() / imageWidth;
        final normalizedStoredY = storedPoints[1].toDouble() / imageHeight;

        // Calculate Euclidean distance
        final distance = sqrt(
          pow(normalizedCurrentX - normalizedStoredX, 2) +
              pow(normalizedCurrentY - normalizedStoredY, 2),
        );

        // Apply weight to the distance
        final weight = featureWeights[key] ?? 1.0;
        weightedDistanceSum += weight * distance;
        totalWeight += weight;
      } else {
        print("Key $key is missing in currentLandmarks or storedFaceData.");
      }
    }
  } catch (e) {
    print('Error in similarity calculation: $e');
    return 0.0;
  }

  if (totalWeight == 0) {
    print("Total weight is zero. No valid features to compare.");
    return 0.0;
  }

  // Normalize the similarity score
  double averageWeightedDistance = weightedDistanceSum / totalWeight;
  double similarity = 1 - averageWeightedDistance; // Normalize to [0, 1]

  // Clamp similarity to [0, 100]
  similarity = similarity.clamp(0.0, 1.0) * 100;

  print("Weighted Distance Sum: $weightedDistanceSum, Total Weight: $totalWeight, Similarity: $similarity");

  return similarity;
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

class FaceRecognitionUtils {
  static Map<String, List<double>> normalizeFaceLandmarks(Map<String, List<dynamic>> landmarks) {
    // Find the center point of the face using nose position
    List<dynamic> nosePoint = landmarks['nose'] ?? [0, 0];
    double centerX = nosePoint[0].toDouble();
    double centerY = nosePoint[1].toDouble();
    
    // Calculate the face scale using eye distance
    List<dynamic> leftEye = landmarks['leftEye'] ?? [0, 0];
    List<dynamic> rightEye = landmarks['rightEye'] ?? [0, 0];
    double eyeDistance = sqrt(
      pow(leftEye[0].toDouble() - rightEye[0].toDouble(), 2) +
      pow(leftEye[1].toDouble() - rightEye[1].toDouble(), 2)
    );
    
    Map<String, List<double>> normalizedLandmarks = {};
    
    // Normalize each landmark relative to face center and scale
    landmarks.forEach((key, points) {
      double x = points[0].toDouble();
      double y = points[1].toDouble();
      
      // Normalize coordinates relative to nose position and eye distance
      double normalizedX = (x - centerX) / eyeDistance;
      double normalizedY = (y - centerY) / eyeDistance;
      
      normalizedLandmarks[key] = [normalizedX, normalizedY];
    });
    
    return normalizedLandmarks;
  }

  static double calculateFaceSimilarity(
    Map<String, List<dynamic>> face1, 
    Map<String, dynamic> face2
  ) {
    try {
      // Normalize both face landmarks
      Map<String, List<double>> normalizedFace1 = normalizeFaceLandmarks(face1);
      
      // Convert and normalize face2 data
      Map<String, List<dynamic>> face2Converted = {};
      face2.forEach((key, value) {
        if (value is List) {
          face2Converted[key] = value;
        }
      });
      Map<String, List<double>> normalizedFace2 = normalizeFaceLandmarks(face2Converted);
      
      double totalSimilarity = 0;
      int count = 0;
      
      // Compare normalized landmarks
      normalizedFace1.forEach((key, points1) {
        if (normalizedFace2.containsKey(key)) {
          List<double> points2 = normalizedFace2[key]!;
          
          // Calculate Euclidean distance between normalized points
          double distance = sqrt(
            pow(points1[0] - points2[0], 2) + 
            pow(points1[1] - points2[1], 2)
          );
          
          // Convert distance to similarity score (closer to 1 means more similar)
          double similarity = 1 / (1 + distance);
          totalSimilarity += similarity;
          count++;
        }
      });
      
      if (count == 0) return 0;
      
      // Calculate average similarity across all landmarks
      double avgSimilarity = totalSimilarity / count;
      
      // Add additional checks for more reliable matching
      if (count < 4) { // If we couldn't match enough landmarks
        return 0;
      }
      
      return avgSimilarity;
    } catch (e) {
      print('Error calculating face similarity: $e');
      return 0;
    }
  }

  static bool isFaceMatch(double similarity) {
    // Adjust this threshold based on testing
    const double SIMILARITY_THRESHOLD = 0.75;
    return similarity > SIMILARITY_THRESHOLD;
  }
}