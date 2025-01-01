import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CameraRegisterPage extends StatefulWidget {
  final Function(File) onCapture;

  CameraRegisterPage({required this.onCapture});

  @override
  _CameraRegisterPageState createState() => _CameraRegisterPageState();
}

class _CameraRegisterPageState extends State<CameraRegisterPage> {
  File? _capturedImage;
  bool _isCapturing = false;

  @override
  void dispose() {
    // Ensure any camera resources are released
    super.dispose();
  }

  Future<void> _captureImage() async {
    if (_isCapturing) return; // Prevent multiple simultaneous captures

    final picker = ImagePicker();
    setState(() {
      _isCapturing = true;
    });

    try {
      // Add a small delay to ensure previous camera instances are released
      await Future.delayed(Duration(milliseconds: 200));

      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 85, // Reduce quality slightly to improve performance
        maxWidth: 1200,   // Limit image size
        maxHeight: 1200,
      );
      
      if (!mounted) return; // Check if widget is still mounted

      if (pickedFile != null) {
        final imageFile = File(pickedFile.path);
        
        if (mounted) {
          setState(() {
            _capturedImage = imageFile;
          });
        }
        
        // Make sure to check if widget is still mounted before callbacks
        if (mounted) {
          // Call the callback function with the captured image
          widget.onCapture(imageFile);
          
          // Add a small delay before navigation to ensure resources are released
          await Future.delayed(Duration(milliseconds: 100));
          
          // Check mounted state again before navigation
          if (mounted) {
            Navigator.pop(context, imageFile);
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("No image was selected."),
            duration: Duration(seconds: 2),
          ));
        }
      }
    } catch (e) {
      print('Camera error: $e'); // Log the error for debugging
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Camera is in use or not available. Please try again."),
          duration: Duration(seconds: 2),
        ));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Ensure clean navigation back
        Navigator.of(context).pop(_capturedImage);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Camera'),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pop(_capturedImage);
            },
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_capturedImage != null)
                Container(
                  height: 200,
                  width: double.infinity,
                  margin: EdgeInsets.all(16),
                  child: Image.file(
                    _capturedImage!,
                    fit: BoxFit.cover,
                  ),
                ),
              ElevatedButton(
                onPressed: _isCapturing ? null : _captureImage,
                child: _isCapturing 
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text('Capture Image'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
