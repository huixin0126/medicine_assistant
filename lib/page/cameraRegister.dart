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
    _capturedImage = null;
    super.dispose();
  }

  Future<void> _captureImage() async {
    if (_isCapturing) return;

    setState(() {
      _isCapturing = true;
    });

    try {
      final picker = ImagePicker();
      
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 70,  // Reduced quality
        maxWidth: 800,    // Reduced size
        maxHeight: 800,
      );

      if (!mounted) return;

      if (pickedFile != null) {
        final imageFile = File(pickedFile.path);
        
        if (mounted) {
          setState(() {
            _capturedImage = imageFile;
          });
          
          // Only return the image, don't call onCapture
          Navigator.pop(context, imageFile);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No image was selected")),
          );
        }
      }
    } catch (e) {
      print('Camera error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Camera error. Please try again"),
          ),
        );
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_capturedImage != null)
              Container(
                height: 200,
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                child: Image.file(
                  _capturedImage!,
                  fit: BoxFit.cover,
                ),
              ),
            Center(
              child: ElevatedButton.icon(
                onPressed: _isCapturing ? null : _captureImage,
                icon: _isCapturing 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.camera_alt),
                label: Text(_isCapturing ? 'Capturing...' : 'Take Photo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}