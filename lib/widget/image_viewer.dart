import 'dart:io'; // For File
import 'package:flutter/material.dart';
import 'dart:convert'; // For base64 decoding

class ImageViewerScreen extends StatelessWidget {
  final String? imageUrl; // For URL images
  final File? imageFile;  // For local image files

  // Constructor to accept both imageUrl and imageFile
  ImageViewerScreen({this.imageUrl, this.imageFile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Image Viewer"),
      ),
      body: Center(
        child: imageFile != null
            ? Image.file(imageFile!) // Display the local image file if imageFile is not null
            : imageUrl != null
                ? imageUrl!.startsWith('data:image')
                    ? Image.memory(
                        base64Decode(imageUrl!.split(',').last), // If the imageUrl is base64
                        fit: BoxFit.cover,
                      )
                    : Image.network(imageUrl!) // Display image from the URL
                : Icon(Icons.image, size: 100), // Fallback icon if neither is provided
      ),
    );
  }
}
