import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:string_similarity/string_similarity.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:math';
import 'package:image_picker/image_picker.dart';
import 'dart:io'; // To use File for picked images
import 'package:medicine_assistant_app/widget/chat_dialog.dart';

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  _ChatbotPageState createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [
  {
    'sender': "Bot",
    'message': "Hi! Ask me a question.",
    'avatarUrl': "https://xiaoxintv.cc/template/mytheme/statics/image/20211025/25ef538a6.png",
    'image': null, // Initially no image
  }
];


  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;
  
  final CollectionReference _usersCollection =
      FirebaseFirestore.instance.collection('User');
  final CollectionReference _remindersCollection =
      FirebaseFirestore.instance.collection('Reminder');
  final CollectionReference _medicineCollection =
      FirebaseFirestore.instance.collection('Medicine');

  // Speech recognition variables
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _spokenText = "";

  List<String> _seniorNames = [];
  List<String> _medicineNames = [];

  // Variable to hold image file
  File? _image;
  // Initialize the image picker
  final ImagePicker _picker = ImagePicker();


@override
void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _fetchNamesFromFirestore();

    // Initialize animation controller
    _animationController = AnimationController(
      duration: const Duration(seconds: 60), // Animation runs for 60 seconds
      vsync: this,
    );

    // Create a rotation animation for 360 degrees (2 * pi radians) to complete in 60 seconds
    _rotationAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.linear, // Smooth constant speed for rotation
      ),
    );

    // Add listener to ensure animation runs for the full 60 seconds
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isListening = false; // Stop listening when the animation completes
        });
        _animationController.stop(); // Ensure the animation stops after 60 seconds
      }
    });
  }

  Future<void> _fetchNamesFromFirestore() async {
    try {
      // Fetch senior names
      QuerySnapshot userSnapshot = await _usersCollection.get();
      _seniorNames = userSnapshot.docs
          .map((doc) => doc['name'].toString().toLowerCase())
          .toList();

      // Fetch medicine names
      QuerySnapshot medicineSnapshot = await _medicineCollection.get();
      _medicineNames = medicineSnapshot.docs
          .map((doc) => doc['name'].toString().toLowerCase())
          .toList();
    } catch (e) {
      print("Error fetching names: $e");
    }
  }

@override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

Future<void> _startListening() async {
    bool available = await _speech.initialize(
      onStatus: (status) {
        print('Speech status: $status');
        if (status == 'notListening') {
          setState(() => _isListening = false);
          _animationController.stop(); // Stop the animation when done listening
        }
      },
      onError: (errorNotification) {
        print('Speech error: $errorNotification');
        setState(() => _isListening = false);
        _animationController.stop(); // Stop on error
      },
    );

    if (available) {
      setState(() {
        _isListening = true;
      });

      // Start the rotation animation, ensuring it completes the full duration
      _animationController.forward();

      await _speech.listen(
        onResult: (result) {
          setState(() {
            _spokenText = result.recognizedWords;
            _messageController.text = _spokenText;
          });
        },
        listenFor: Duration(seconds: 60), // Listen for exactly 60 seconds
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      );
    } else {
      print('Speech recognition not available');
    }
  }

  void _stopListening() {
    if (_speech.isListening) {
      _speech.stop();
      setState(() {
        _isListening = false;
      });

      // Stop the rotation animation
      _animationController.stop();
      _animationController.reset();

      Future.delayed(Duration(milliseconds: 500), () {
        if (_spokenText.isNotEmpty) {
          _sendMessage(_spokenText);
          _spokenText = "";
        }
      });
    }
  }

  // Pick an image
  Future<void> _pickImage() async {
    // Pick an image from the gallery
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> _sendMessage(String message) async {
    if (message.trim().isNotEmpty || _image != null) {
      setState(() {
        _messages.add({
          'sender': 'You',
          'message': message,
          'avatarUrl': 
                "https://xiaoxintv.cc/template/mytheme/statics/image/20211025/25ef538a6.png",
          'image': _image, // Add image data
        });
      });
      _messageController.clear();
      setState(() {
        _image = null; // Reset the image after sending it
      });

      // Fetch an answer from Firebase
      String answer = await _getAnswerFromFirebase(message);
      setState(() {
        _messages.add({
          'sender': 'Bot',
          'message': answer,
          'avatarUrl':
              "https://xiaoxintv.cc/template/mytheme/statics/image/20211025/25ef538a6.png",
          'image': null,
        });
      });
    }
  }
  
Future<String> _getAnswerFromFirebase(String question) async {
  try {
    // Lowercase the question for case-insensitive processing
    final lowerCaseQuestion = question.toLowerCase();

    // Define possible keywords for each field, including medicine
    final fieldKeywords = {
      'phoneNo': {'phone', 'number', 'telephone', 'mobile', 'contact'},
      'time': {'time', 'schedule', 'timing', 'what time', 'when'},
      'date': {'date', 'day', 'which date', 'schedule', 'when'},
      'status': {'status', 'state', 'condition', 'progress', 'completed'},
      'dose': {'dose'},
      'dosage': {'dosage', 'amount', 'quantity', 'how many', 'how much'},
      'medicine': {'medicine', 'take'} // Added new keywords for 'medicine'
    };

    // Dynamically fetch senior names and medicine names from Firestore
    List<String> seniorNames = await _fetchAllSeniorNames();
    List<String> medicineNames = await _fetchAllMedicineNames();

    // Extract the field, senior name, and medicine name
    String? field = _extractField(lowerCaseQuestion, fieldKeywords);
    String? seniorName = _extractKeyword(lowerCaseQuestion, seniorNames);
    String? medicineName = _extractKeyword(lowerCaseQuestion, medicineNames);

    // Handle the case when no field is identified
    if (field == null) {
      if (seniorName != null && medicineName != null) {
        // Fetch the Senior's ID from the database
        QuerySnapshot userSnapshot = await _usersCollection
            .where('name', isEqualTo: seniorName)
            .get();
        
        if (userSnapshot.docs.isNotEmpty) {
          String seniorId = userSnapshot.docs.first['SeniorID'];

          // Find the medicines that the senior is supposed to take
          QuerySnapshot medicineSnapshot = await _medicineCollection
              .where('SeniorID', isEqualTo: seniorId)
              .get();

          if (medicineSnapshot.docs.isNotEmpty) {
            List<String> medicines = medicineSnapshot.docs
                .map((doc) => doc['name'].toString())
                .toList();
            return "${seniorName} will take the following medicines: ${medicines.join(', ')}.";
          } else {
            return "I couldn't find any medicines for $seniorName.";
          }
        } else {
          return "I couldn't find any senior with the name $seniorName.";
        }
      } else {
        return "I couldn't determine what you're asking. Can you rephrase your question?";
      }
    }

    // Handle specific fields
    if (field == 'phoneNo' && seniorName != null) {
      // Fetch senior's phone number
      QuerySnapshot userSnapshot = await _usersCollection
          .where('name', isEqualTo: seniorName)
          .get();

      if (userSnapshot.docs.isNotEmpty) {
        String phoneNo = userSnapshot.docs.first['phoneNo'];
        return "$seniorName's phone number is $phoneNo.";
      }
    } 

    // Handle medicine-related queries (like dose, status, time, date, dosage)
    if (medicineName != null) {
      if (field == 'dose') {
        // Fetch the medicine dose
        QuerySnapshot medicineSnapshot = await _medicineCollection
            .where('name', isEqualTo: medicineName)
            .get();

        if (medicineSnapshot.docs.isNotEmpty) {
          String dose = medicineSnapshot.docs.first['dose'];
          return "The dose for $medicineName is $dose.";
        }
      } else if ((field == 'status' || field == 'time' || field == 'date') &&
          seniorName != null) {
        // Fetch reminder information
        QuerySnapshot userSnapshot = await _usersCollection
            .where('name', isEqualTo: seniorName)
            .get();

        if (userSnapshot.docs.isNotEmpty) {
          String seniorId = userSnapshot.docs.first['SeniorID'];
          QuerySnapshot medicineSnapshot = await _medicineCollection
              .where('name', isEqualTo: medicineName)
              .where('SeniorID', isEqualTo: seniorId)
              .get();

          if (medicineSnapshot.docs.isNotEmpty) {
            String medicineId = medicineSnapshot.docs.first['MedicineID'];
            QuerySnapshot reminderSnapshot = await _remindersCollection
                .where('SeniorID', isEqualTo: seniorId)
                .where('MedicineID', isEqualTo: medicineId)
                .get();

            if (reminderSnapshot.docs.isNotEmpty) {
              var reminderData = reminderSnapshot.docs.first;
              if (field == 'status') {
                return "The status for $seniorName taking $medicineName is: ${reminderData['Status']}.";  
              } else if (field == 'Time') {
                return "The time for $medicineName reminder is: ${reminderData['Time']}.";
              } else if (field == 'Date') {
                return "The date for $medicineName reminder is: ${reminderData['Date']}.";
              }
            }
          }
        }
      } else if (field == 'dosage' && seniorName != null) {
        // Fetch dosage information
        QuerySnapshot userSnapshot = await _usersCollection
            .where('name', isEqualTo: seniorName)
            .get();

        if (userSnapshot.docs.isNotEmpty) {
          String seniorId = userSnapshot.docs.first['SeniorID'];
          QuerySnapshot medicineSnapshot = await _medicineCollection
              .where('name', isEqualTo: medicineName)
              .where('SeniorID', isEqualTo: seniorId)
              .get();

          if (medicineSnapshot.docs.isNotEmpty) {
            String medicineId = medicineSnapshot.docs.first['MedicineID'];
            QuerySnapshot reminderSnapshot = await _remindersCollection
                .where('SeniorID', isEqualTo: seniorId)
                .where('MedicineID', isEqualTo: medicineId)
                .get();

            if (reminderSnapshot.docs.isNotEmpty) {
              String dosage = reminderSnapshot.docs.first['dosage'];
              return "The dosage for $seniorName to take $medicineName is $dosage.";
            }
          }
        }
      }
    }

    // Final checks for missing senior or medicine name
    if (seniorName == null) {
      return "I couldn't identify the senior citizen you're referring to.";
    }

    if (medicineName == null) {
      return "I couldn't identify the medicine you're asking about.";
    }

    // If no other conditions matched
    return "I couldn't find an answer. Please check the data in the database.";
    
  } catch (e) {
    return "An error occurred while fetching the answer: $e";
  }
}

Future<List<String>> _fetchAllSeniorNames() async {
  try {
    QuerySnapshot snapshot = await _usersCollection.get();
    return snapshot.docs.map((doc) => doc['Name'].toString().toLowerCase()).toList();
  } catch (e) {
    return [];
  }
}

Future<List<String>> _fetchAllMedicineNames() async {
  try {
    QuerySnapshot snapshot = await _medicineCollection.get();
    return snapshot.docs.map((doc) => doc['Name'].toString().toLowerCase()).toList();
  } catch (e) {
    return [];
  }
}

String? _extractKeyword(String question, List<String> possibleKeywords) {
  question = question.toLowerCase();
  double threshold = 0.7; // Lower threshold for better matching

  // First try exact matches
  for (var keyword in possibleKeywords) {
    if (question.contains(keyword.toLowerCase())) {
      return keyword;
    }
  }

  // If no exact match, try similarity matching
  String? bestMatch;
  double bestScore = 0.0;

  for (var keyword in possibleKeywords) {
    double similarity = question.similarityTo(keyword);
    if (similarity > bestScore && similarity >= threshold) {
      bestMatch = keyword;
      bestScore = similarity;
    }
  }
  return bestMatch;
}

String? _extractField(String question, Map<String, Set<String>> fieldKeywords) {
  question = question.toLowerCase();
  double threshold = 0.7; // Lower threshold for better matching
  String? bestField;
  double bestScore = 0.0;

  for (var field in fieldKeywords.keys) {
    for (var keyword in fieldKeywords[field]!) {
      // Check for exact substring matches first
      if (question.contains(keyword.toLowerCase())) {
        return field;
      }
      
      // If no exact match, try similarity matching
      double similarity = question.similarityTo(keyword);
      if (similarity > bestScore && similarity >= threshold) {
        bestField = field;
        bestScore = similarity;
      }
    }
  }
  return bestField;
}

  Widget _buildVoiceButton() {
  return SizedBox(
    width: 70,
    height: 70,
    child: Stack(
      alignment: Alignment.center,
      children: [
        // Static microphone button
        CircleAvatar(
          radius: 30,
          backgroundColor: _isListening ? Colors.red : Colors.blue,
          child: const Icon(
            Icons.mic,
            color: Colors.white,
            size: 25,
          ),
        ),
        // Rotating ring
        if (_isListening)
          AnimatedBuilder(
            animation: _rotationAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotationAnimation.value,
                child: CustomPaint(
                  size: const Size(70, 70),
                  painter: RingPainter(angle: _rotationAnimation.value * 2 * pi),
                ),
              );
            },
          ),
      ],
    ),
  );
}

  @override
Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat with Bot'),
      ),
      body: Column(
  children: [
    Expanded(
      child: ListView.builder(
        reverse: false,
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final messageData = _messages[index];
          return chatDialog(
            avatar: messageData['avatarUrl']!,
            name: messageData['sender']!,
            message: messageData['message']!,
            image: messageData['image'],
            isLeft: messageData['sender'] == 'Bot',
            context: context,
          );
        },
      ),
    ),
    Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          if (_image != null)
            Column(
              children: [
                Image.file(
                  _image!,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                ),
                const SizedBox(height: 8),
              ],
            ),
          Row(
            children: [
              GestureDetector(
                onLongPressStart: (details) {
                  _startListening();
                },
                onLongPressEnd: (details) {
                  _stopListening();
                },
                child: _buildVoiceButton(),
              ),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: 'Type your question...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.image),
                onPressed: _pickImage, // Open image picker
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: () => _sendMessage(_messageController.text),
              ),
            ],
          ),
        ],
      ),
    ),
  ],
),
    );
  }
}

// Custom painter for the rotating ring
class RingPainter extends CustomPainter {
  final double angle;

  RingPainter({required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color.fromARGB(255, 11, 0, 0).withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0; // Solid stroke for the ring

    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final double radius = size.width / 2 - 2;

    // Normalize the angle to prevent overflow (i.e., ensuring it's between 0 and 360 degrees)
    double normalizedAngle = angle % (2 * pi);

    // Draw a solid ring with the current rotation angle
    canvas.drawArc(
      Rect.fromCircle(center: Offset(centerX, centerY), radius: radius),
      -pi / 2,
      normalizedAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
