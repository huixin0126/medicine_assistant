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
  String _confirmPassword = '';
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

  final TextEditingController _phoneController = TextEditingController();
  bool _showPassword = false;
  bool _showConfirmPassword = false;

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
  _phoneController.dispose();
  super.dispose();
}

// Add validation functions
  String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your name';
    }
    if (value.length < 2) {
      return 'Name must be at least 2 characters long';
    }
    if (value.length > 50) {
      return 'Name cannot exceed 50 characters';
    }
    // Check if name contains only letters, spaces, and common special characters
    if (!RegExp(r"^[a-zA-Z\s.'()-]+$").hasMatch(value)) {
      return 'Name can only contain letters, spaces, and basic punctuation';
    }
    return null;
  }

  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    // More comprehensive email validation
    if (!RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least 1 uppercase letter';
    }
    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least 1 lowercase letter';
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least 1 number';
    }
    if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Password must contain at least 1 special character';
    }
    return null;
  }

  String? validatePhone(String? value) {
  if (value == null || value.isEmpty) {
    return 'Please enter your phone number';
  }
  
  // Remove any non-digit characters
  String cleanPhone = value.replaceAll(RegExp(r'[^\d]'), '');
  
  // // Check if the number starts with 60
  // if (!cleanPhone.startsWith('60')) {
  //   return 'Phone number must start with 60';
  // }
  
  // // Remove the '60' prefix for length validation
  // cleanPhone = cleanPhone.substring(2);
  
  // Validate that it starts with valid Malaysian prefixes
  if (!cleanPhone.startsWith(RegExp(r'^(1[0-9])'))) {
    return 'Invalid Malaysian phone number prefix';
  }
  
  // Check total length (excluding 60): should be 9-10 digits
  if (cleanPhone.length < 9 || cleanPhone.length > 10) {
    return 'Phone number must be 9-10 digits (excluding 60)';
  }
  
  return null;
}

void _formatPhoneNumber(String value) {
  // Remove any non-digit characters
  String digits = value.replaceAll(RegExp(r'[^\d]'), '');

  // Remove leading 0 if present
  if (digits.startsWith('0')) {
    digits = digits.substring(1);
  }

  // Limit the total length to 10 digits (including 60)
  if (digits.length > 10) {
    digits = digits.substring(0, 10);
  }

  // Format the phone number based on length
  String formatted = '';
  if (digits.isNotEmpty) {
    // Add the first group (60)
    formatted += ' ${digits.substring(0, min(digits.length, 2))}';

    if (digits.length > 2) {
      if (digits.length <= 6) {
        // For 6 digits: Add all digits after the first 2 as a single group
        formatted += ' ${digits.substring(2)}';
      } else if (digits.length <= 9) {
        // For 9 digits: Format as 60 123 4567
        formatted += ' ${digits.substring(2, 5)}'; // Add '123'
        formatted += ' ${digits.substring(5)}';    // Add '4567'
      } else {
        // For 10 digits: Format as 60 1234 56789
        formatted += ' ${digits.substring(2, 6)}'; // Add '1234'
        formatted += ' ${digits.substring(6)}';    // Add '56789'
      }
    }
  }

  // Ensure the cursor position is valid (last character in the string)
  int cursorPosition = formatted.length > 0 ? formatted.trim().length : 0;

  // Update the controller with the formatted phone number and set the correct cursor position
  _phoneController.value = TextEditingValue(
    text: formatted.trim(),
    selection: TextSelection.collapsed(offset: cursorPosition),
  );
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

// Future<void> _handleRegister() async {
//   if (!_formKey.currentState!.validate()) return;

//   if (_capturedImage == null) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(content: Text('Please capture your face image first.')),
//     );
//     return;
//   }

//   // Show loading indicator at the start of registration
//   showDialog(
//     context: context,
//     barrierDismissible: false,
//     builder: (BuildContext context) {
//       return const Center(
//         child: CircularProgressIndicator(),
//       );
//     },
//   );

//   _formKey.currentState!.save();

//   try {
//     // Process face detection if not already done
//     if (_detectedFaces == null) {
//       try {
//         final inputImage = InputImage.fromFile(_capturedImage!);
//         _detectedFaces = await _faceDetector.processImage(inputImage);
//       } catch (e) {
//         // Close loading dialog
//         if (mounted && Navigator.canPop(context)) {
//           Navigator.pop(context);
//         }
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Failed to process face image. Please try capturing again.')),
//         );
//         return;
//       }
//     }

//     // Verify face detection results
//     if (_detectedFaces == null || _detectedFaces!.isEmpty) {
//       // Close loading dialog
//       if (mounted && Navigator.canPop(context)) {
//         Navigator.pop(context);
//       }
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('No face detected. Please capture your face clearly.')),
//       );
//       return;
//     }

//     // Create user account
//     final userCredential = await f_User.FirebaseAuth.instance
//         .createUserWithEmailAndPassword(email: _email, password: _password);

//     String deviceToken = await FirebaseMessaging.instance.getToken() ?? '';

//     // Upload face image
//     final storageReference = FirebaseStorage.instance
//         .ref()
//         .child('face_images/${userCredential.user!.uid}.jpg');
    
//     // Resize image before upload to reduce storage usage
//     final resizedImage = await compute(resizeImageIsolate, _capturedImage!);
//     final uploadTask = storageReference.putFile(resizedImage);
//     final snapshot = await uploadTask.whenComplete(() {});
//     final imageUrl = await snapshot.ref.getDownloadURL();

//     // Prepare face data with null safety
//     final faceData = _detectedFaces!.first;
//     final landmarks = {
//       'leftEye': [
//         faceData.landmarks[FaceLandmarkType.leftEye]?.position.x ?? 0.0,
//         faceData.landmarks[FaceLandmarkType.leftEye]?.position.y ?? 0.0,
//       ],
//       'rightEye': [
//         faceData.landmarks[FaceLandmarkType.rightEye]?.position.x ?? 0.0,
//         faceData.landmarks[FaceLandmarkType.rightEye]?.position.y ?? 0.0,
//       ],
//       'nose': [
//         faceData.landmarks[FaceLandmarkType.noseBase]?.position.x ?? 0.0,
//         faceData.landmarks[FaceLandmarkType.noseBase]?.position.y ?? 0.0,
//       ],
//       'leftMouth': [
//         faceData.landmarks[FaceLandmarkType.leftMouth]?.position.x ?? 0.0,
//         faceData.landmarks[FaceLandmarkType.leftMouth]?.position.y ?? 0.0,
//       ],
//       'rightMouth': [
//         faceData.landmarks[FaceLandmarkType.rightMouth]?.position.x ?? 0.0,
//         faceData.landmarks[FaceLandmarkType.rightMouth]?.position.y ?? 0.0,
//       ],
//     };

//     // Verify landmarks data
//     bool hasValidLandmarks = landmarks.values.every((point) => 
//       point[0] != 0.0 || point[1] != 0.0
//     );

//     if (!hasValidLandmarks) {
//       // Delete the created user if face data is invalid
//       await userCredential.user?.delete();
//       throw Exception('Invalid face landmarks detected. Please try capturing again.');
//     }

//     // Save user data to Firestore
//     await FirebaseFirestore.instance
//         .collection('User')
//         .doc(userCredential.user!.uid)
//         .set({
//       'avatar': '',
//       'deviceToken': deviceToken,
//       'email': _email,
//       'faceData': landmarks,
//       'faceImageUrl': imageUrl,
//       'name': _name,
//       'phoneNo': _phoneNo,
//       'userID': userCredential.user!.uid,
//       'emergencyContact': '',
//       'seniorIDs': [],
//       'guardianIDs': [],
//     });

//     // Close loading dialog
//     if (mounted && Navigator.canPop(context)) {
//       Navigator.pop(context);
//     }

//     // Show success message
//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Registration successful! Please login.')),
//       );
//     }

//     // Wait for snackbar to be visible
//     await Future.delayed(const Duration(seconds: 1));

//     // Navigate to login page
//     if (mounted) {
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(
//           builder: (context) => LoginPage(),
//         ),
//       );
//     }
//   } catch (e) {
//     // Close loading dialog
//     if (mounted && Navigator.canPop(context)) {
//       Navigator.pop(context);
//     }

//     print('Registration failed: $e');
//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             'Registration failed: ${e.toString().contains('Exception:') 
//               ? e.toString().split('Exception: ')[1] 
//               : 'Please try again.'}'
//           ),
//         ),
//       );
//     }
//   }
// }

Future<void> _handleRegister() async {
  if (!_formKey.currentState!.validate()) return;

  // Show loading indicator at the start of registration
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    },
  );

  _formKey.currentState!.save();

  try {
    // Create user account
    final userCredential = await f_User.FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: _email, password: _password);

    String deviceToken = await FirebaseMessaging.instance.getToken() ?? '';

    // Initialize variables for face data
    String? imageUrl;
    Map<String, List<num>>? landmarks;

    // Process face data only if image was captured
    if (_capturedImage != null) {
      try {
        // Upload face image
        final storageReference = FirebaseStorage.instance
            .ref()
            .child('face_images/${userCredential.user!.uid}.jpg');
        
        // Resize image before upload to reduce storage usage
        final resizedImage = await compute(resizeImageIsolate, _capturedImage!);
        final uploadTask = storageReference.putFile(resizedImage);
        final snapshot = await uploadTask.whenComplete(() {});
        imageUrl = await snapshot.ref.getDownloadURL();

        // Process face landmarks if faces were detected
        if (_detectedFaces != null && _detectedFaces!.isNotEmpty) {
          final faceData = _detectedFaces!.first;
          landmarks = {
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
        }
      } catch (e) {
        print('Warning: Failed to process face data: $e');
        // Continue with registration even if face processing fails
      }
    }

    // Save user data to Firestore
    await FirebaseFirestore.instance
        .collection('User')
        .doc(userCredential.user!.uid)
        .set({
      'avatar': '',
      'deviceToken': deviceToken,
      'email': _email,
      'faceData': landmarks, // Can be null
      'faceImageUrl': imageUrl ?? '', // Empty string if no image
      'name': _name,
      'phoneNo': _phoneNo,
      'userID': userCredential.user!.uid,
      'emergencyContact': '',
      'seniorIDs': [],
      'guardianIDs': [],
    });

    // Close loading dialog
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration successful! Please login.')),
      );
    }

    // Wait for snackbar to be visible
    await Future.delayed(const Duration(seconds: 1));

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
    // Close loading dialog
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    print('Registration failed: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Registration failed: ${e.toString().contains('Exception:') 
              ? e.toString().split('Exception: ')[1] 
              : 'Please try again.'}'
          ),
        ),
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
    appBar: AppBar(
      title: const Text('Register'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
            padding: EdgeInsets.all(5),
            child: Center(  // Center the image horizontally
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 80,
                  width: 80,  // This will now work because it's centered
                  child: Image.asset(
                    'assets/logo/logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
            SizedBox(height: 32),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(Icons.person_outline, color: Theme.of(context).primaryColor),
                filled: true,
                fillColor: Colors.grey[50],
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).primaryColor),
                ),
                hintText: 'Enter your full name',
              ),
              validator: validateName,
              onSaved: (value) => _name = value!.trim(),
              textInputAction: TextInputAction.next,
            ),
            SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(Icons.email_outlined, color: Theme.of(context).primaryColor),
                filled: true,
                fillColor: Colors.grey[50],
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).primaryColor),
                ),
                hintText: 'Enter your email address',
              ),
              validator: validateEmail,
              onSaved: (value) => _email = value!.trim(),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(Icons.lock_outline, color: Theme.of(context).primaryColor),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showPassword ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _showPassword = !_showPassword;
                    });
                  },
                ),
                filled: true,
                fillColor: Colors.grey[50],
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).primaryColor),
                ),
                hintText: 'Enter your password',
                helperText: 'At least 8 characters, (including uppercase, lowercase, number, special character)',
                helperMaxLines: 2,
              ),
              obscureText: !_showPassword,
              validator: validatePassword,
              onSaved: (value) => _password = value!,
              onChanged: (value) => _password = value,
              textInputAction: TextInputAction.next,
            ),
            SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(Icons.lock_outline, color: Theme.of(context).primaryColor),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showConfirmPassword ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _showConfirmPassword = !_showConfirmPassword;
                    });
                  },
                ),
                filled: true,
                fillColor: Colors.grey[50],
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).primaryColor),
                ),
                hintText: 'Re-enter your password',
              ),
              obscureText: !_showConfirmPassword,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please confirm your password';
                }
                if (value != _password) {
                  return 'Passwords do not match';
                }
                return null;
              },
              onSaved: (value) => _confirmPassword = value!,
              textInputAction: TextInputAction.next,
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(Icons.phone_outlined, color: Theme.of(context).primaryColor),
                filled: true,
                fillColor: Colors.grey[50],
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).primaryColor),
                ),
                prefixText: '+60 ',
                hintText: 'Enter your phone number',
              ),
              keyboardType: TextInputType.phone,
              validator: validatePhone,
              onChanged: _formatPhoneNumber,
              onSaved: (value) {
                if (value != null) {
                  String cleanPhone = value.replaceAll(RegExp(r'[^\d]'), '');
                  if (cleanPhone.startsWith('0')) {
                    cleanPhone = cleanPhone.substring(1);
                  }
                  _phoneNo = '60$cleanPhone';
                }
              },
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _openCamera,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Open Camera'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
            SizedBox(height: 16),
            if (_capturedImage != null)
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.file(
                  _capturedImage!,
                  fit: BoxFit.cover,
                ),
              ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _handleRegister,
              icon: const Icon(Icons.app_registration),
              label: const Text('Register', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
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