import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ScanPage extends StatefulWidget {
  final String userID;

  ScanPage({required this.userID});

  @override
  _ScanPageState createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  String _medicineName = "";
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;

  Future<void> _processImage(File image) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // Create a multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://192.168.0.96:5000/detect-medicine'), // Update with your API URL
      );
      request.files.add(await http.MultipartFile.fromPath('file', image.path));

      print("Sending image to: ${Uri.parse('http://192.168.0.96/detect-medicine')}");
      print("Image path: ${image.path}");

      // Send the request
      var response = await request.send();
      print("Response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        print("Response data: $responseData");
        final decodedData = json.decode(responseData);

        setState(() {
          _medicineName = decodedData['medicine_name'] ?? "Unknown Medicine";
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to detect medicine. Please try again.")),
        );
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
