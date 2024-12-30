// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';

// class ScanPage extends StatefulWidget {
//   final String userID;

//   ScanPage({required this.userID});

//   @override
//   _ScanPageState createState() => _ScanPageState();
// }

// class _ScanPageState extends State<ScanPage> {
//   String _medicineName = "";
//   File? _imageFile;
//   final ImagePicker _picker = ImagePicker();
//   bool _isProcessing = false;

//   Future<void> _processImage(File image) async {
//     setState(() {
//       _isProcessing = true;
//     });

//     try {
//       // Create a multipart request
//       var request = http.MultipartRequest(
//         'POST',
//         Uri.parse('http://10.131.73.105:5000/detect-medicine'), // Update with your API URL
//       );
//       request.files.add(await http.MultipartFile.fromPath('file', image.path));

//       print("Sending image to: ${Uri.parse('http://10.131.73.105/detect-medicine')}");
//       print("Image path: ${image.path}");

//       // Send the request
//       var response = await request.send();
//       print("Response status: ${response.statusCode}");

//       if (response.statusCode == 200) {
//         final responseData = await response.stream.bytesToString();
//         print("Response data: $responseData");
//         final decodedData = json.decode(responseData);

//         setState(() {
//           _medicineName = decodedData['medicine_name'] ?? "Unknown Medicine";
//         });
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text("Failed to detect medicine. Please try again.")),
//         );
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("Error processing image: $e")),
//       );
//     } finally {
//       setState(() {
//         _isProcessing = false;
//       });
//     }
//   }

//   Future<void> _pickImage(ImageSource source) async {
//     try {
//       final XFile? pickedFile = await _picker.pickImage(source: source);
//       if (pickedFile != null) {
//         final File imageFile = File(pickedFile.path);
//         setState(() {
//           _imageFile = imageFile;
//         });
//         await _processImage(imageFile);
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("Error picking image: $e")),
//       );
//     }
//   }

//   Future<void> _saveMedicine() async {
//     if (_medicineName.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("Please enter medicine name")),
//       );
//       return;
//     }

//     try {
//       String? imageUrl;

//       if (_imageFile != null) {
//         final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
//         final imagePath = 'medicine_images/${widget.userID}/$timestamp.jpg';
//         final storageRef = FirebaseStorage.instance.ref().child(imagePath);

//         await storageRef.putFile(_imageFile!);
//         imageUrl = await storageRef.getDownloadURL();
//       }

//       await FirebaseFirestore.instance.collection('Medicine').add({
//         'userID': widget.userID,
//         'name': _medicineName.toLowerCase(),
//         'imageData': imageUrl ?? '',
//       });

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("Medicine saved successfully")),
//       );

//       Navigator.pop(context);
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("Error saving medicine: $e")),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text("Scan Medicine"),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           children: [
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: [
//                 ElevatedButton.icon(
//                   onPressed: () => _pickImage(ImageSource.camera),
//                   icon: Icon(Icons.camera_alt),
//                   label: Text("Camera"),
//                 ),
//                 ElevatedButton.icon(
//                   onPressed: () => _pickImage(ImageSource.gallery),
//                   icon: Icon(Icons.photo_library),
//                   label: Text("Gallery"),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 16),
//             if (_isProcessing)
//               CircularProgressIndicator()
//             else if (_imageFile != null)
//               Image.file(
//                 _imageFile!,
//                 height: 150,
//                 width: 150,
//                 fit: BoxFit.cover,
//               ),
//             const SizedBox(height: 16),
//             TextFormField(
//               decoration: InputDecoration(labelText: "Medicine Name"),
//               controller: TextEditingController(text: _medicineName),
//               onChanged: (value) => _medicineName = value,
//             ),
//             const SizedBox(height: 20),
//             ElevatedButton(
//               onPressed: _saveMedicine,
//               child: Text("Save Medicine"),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }


import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ScanPage extends StatefulWidget {
  final String userID;
  ScanPage({required this.userID});
  @override
  _ScanPageState createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  String _medicineName = "";
  File? _imageFile;
  final TextRecognizer _textRecognizer = TextRecognizer();
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _processImage(File image) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final InputImage inputImage = InputImage.fromFile(image);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      // Initialize variables for best match
      String bestMatch = "";
      double bestConfidence = 0;
      double largestHeight = 0;

      for (TextBlock block in recognizedText.blocks) {
        // Get the text and normalize it
        String text = block.text.toLowerCase().trim();
        double height = block.boundingBox?.height ?? 0;
        
        // Calculate a confidence score based on multiple factors
        double confidence = _calculateConfidence(text, height, block);

        // Update if this is the best match so far
        if (confidence > bestConfidence) {
          bestConfidence = confidence;
          bestMatch = text;
          largestHeight = height;
        }
      }

      // Clean and format the detected medicine name
      if (bestMatch.isNotEmpty) {
        setState(() {
          _medicineName = _cleanMedicineName(bestMatch);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error processing image: $e")),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  double _calculateConfidence(String text, double height, TextBlock block) {
    double confidence = 0;
    
    // Normalize text for comparison
    text = text.toLowerCase().trim();
    
    // Check for common medicine name patterns
    if (text.contains('panadol') || 
        text.contains('pil chi kit') || 
        text.contains('loratadine') ||
        _isMedicineName(text)) {
      confidence += 5;
    }

    // Consider text height (larger text likely to be the medicine name)
    confidence += height / 100;

    // Consider position (medicine names often appear at the top or center)
    if (block.boundingBox != null) {
      double centerY = block.boundingBox!.center.dy;
      if (centerY < 300) confidence += 2; // Higher score for text near the top
    }

    // Consider text length (medicine names usually aren't too long or too short)
    if (text.length > 3 && text.length < 30) confidence += 2;

    return confidence;
  }

  bool _isMedicineName(String text) {
    // Check for common medicine name patterns
    RegExp medicinePattern = RegExp(
      r'^[a-zA-Z\s\-]+$', // Letters, spaces, and hyphens only
      caseSensitive: false,
    );
    
    return medicinePattern.hasMatch(text) && 
           !text.contains('warning') && 
           !text.contains('dose') &&
           !text.contains('mg');
  }

  String _cleanMedicineName(String text) {
    // Remove common unrelated words and clean up the text
    final wordsToRemove = [
      'tablet', 'tablets', 'capsule', 'capsules', 'mg', 'ml',
      'adult', 'children', 'warning', 'dose', 'dosage'
    ];
    
    String cleaned = text.toLowerCase();
    for (String word in wordsToRemove) {
      cleaned = cleaned.replaceAll(word, '');
    }
    
    // Remove special characters except hyphens
    cleaned = cleaned.replaceAll(RegExp(r'[^\w\s\-]'), '');
    
    // Clean up multiple spaces and trim
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    // Capitalize first letter of each word
    cleaned = cleaned.split(' ').map((word) {
      if (word.isNotEmpty) {
        return word[0].toUpperCase() + word.substring(1);
      }
      return word;
    }).join(' ');
    
    return cleaned;
  }

  // Rest of the code remains the same (pickImage, saveMedicine, and build methods)
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        final File imageFile = File(pickedFile.path);
        setState(() {
          _imageFile = imageFile;
        });
        await _processImage(imageFile);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error picking image: $e")),
      );
    }
  }

  Future<void> _saveMedicine() async {
    if (_medicineName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter medicine name")),
      );
      return;
    }

    try {
      String? imageUrl;
      if (_imageFile != null) {
        final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        final imagePath = 'medicine_images/${widget.userID}/$timestamp.jpg';
        final storageRef = FirebaseStorage.instance.ref().child(imagePath);

        await storageRef.putFile(_imageFile!);
        imageUrl = await storageRef.getDownloadURL();
      }

      await FirebaseFirestore.instance.collection('Medicine').add({
        'userID': widget.userID,
        'name': _medicineName.toLowerCase(),
        'imageData': imageUrl ?? '',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Medicine saved successfully")),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving medicine: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Scan Medicine"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: Icon(Icons.camera_alt),
                  label: Text("Camera"),
                ),
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: Icon(Icons.photo_library),
                  label: Text("Gallery"),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isProcessing)
              CircularProgressIndicator()
            else if (_imageFile != null)
              Image.file(
                _imageFile!,
                height: 150,
                width: 150,
                fit: BoxFit.cover,
              ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(labelText: "Medicine Name"),
              controller: TextEditingController(text: _medicineName),
              onChanged: (value) => _medicineName = value,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveMedicine,
              child: Text("Save Medicine"),
            ),
          ],
        ),
      ),
    );
  }
}