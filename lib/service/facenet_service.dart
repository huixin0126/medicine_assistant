import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class FaceNetService {
  static final FaceNetService _faceNetService = FaceNetService._internal();
  Interpreter? _interpreter;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );
  
  factory FaceNetService() => _faceNetService;
  FaceNetService._internal();

  Future<void> loadModel() async {
    try {
      final options = InterpreterOptions()..threads = 4;
      _interpreter = await Interpreter.fromAsset('assets/models/facenet_model.tflite', options: options);
    } catch (e) {
      print('Error loading model: $e');
      throw Exception('Failed to load face recognition model');
    }
  }

  Future<List<double>?> getFaceEmbedding(File imageFile) async {
    try {
      // Detect face first
      final inputImage = InputImage.fromFile(imageFile);
      final faces = await _faceDetector.processImage(inputImage);
      
      if (faces.isEmpty) {
        throw Exception('No face detected');
      }

      // Crop face area
      final face = faces.first;
      final image = img.decodeImage(imageFile.readAsBytesSync());
      if (image == null) throw Exception('Failed to decode image');
      
      final croppedFace = img.copyCrop(
        image,
        x: face.boundingBox.left.toInt(),
        y: face.boundingBox.top.toInt(),
        width: face.boundingBox.width.toInt(),
        height: face.boundingBox.height.toInt(),
      );

      // Resize to required dimensions
      final resized = img.copyResize(croppedFace, width: 160, height: 160);
      
      // Generate embedding
      final input = imageToByteListFloat32(resized);
      final output = List.filled(128, 0).reshape([1, 128]);
      _interpreter?.run(input, output);
      
      return List<double>.from(output[0]);

    } catch (e) {
      print('Error generating face embedding: $e');
      return null;
    }
  }

  List imageToByteListFloat32(img.Image image) {
    var convertedBytes = Float32List(1 * 160 * 160 * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;

    for (var i = 0; i < 160; i++) {
      for (var j = 0; j < 160; j++) {
        var pixel = image.getPixel(j, i);
        buffer[pixelIndex++] = (pixel.r.toDouble() - 128) / 128;
        buffer[pixelIndex++] = (pixel.g.toDouble() - 128) / 128;
        buffer[pixelIndex++] = (pixel.b.toDouble() - 128) / 128;
      }
    }
    return convertedBytes.reshape([1, 160, 160, 3]);
  }

  double euclideanDistance(List<double> e1, List<double> e2) {
    if (e1.length != e2.length) throw Exception('Embedding dimensions do not match');
    double sum = 0.0;
    for (int i = 0; i < e1.length; i++) {
      sum += (e1[i] - e2[i]) * (e1[i] - e2[i]);
    }
    return sqrt(sum);
  }

  void dispose() {
    _interpreter?.close();
    _faceDetector.close();
  }
}