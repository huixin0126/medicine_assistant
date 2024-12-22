// lib/tflite_face_recognition.dart

import 'dart:math';
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';

late Interpreter interpreter;
bool isModelLoaded = false;

Future<void> loadModel() async {
  try {
    interpreter = await Interpreter.fromAsset('assets/models/face_model.tflite');
    isModelLoaded = true; // Set the flag to true when model is loaded
    print('Model loaded successfully');
  } catch (e) {
    print('Failed to load model: $e');
  }
}

Uint8List preprocessImage(Uint8List imageData) {
  // Perform resizing and normalization here
  return imageData; // Preprocessed data
}

List<double> runModel(Uint8List input) {
  if (!isModelLoaded) {
    throw Exception('Model not loaded');
  }

  var output = List<double>.filled(interpreter.getOutputTensor(0).shape[0], 0.0);
  interpreter.run(input, output);
  return output;
}

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
