import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:string_similarity/string_similarity.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:math';
import 'package:image_picker/image_picker.dart';
import 'dart:io'; // To use File for picked images
import 'package:medicine_assistant_app/widget/chat_dialog.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:medicine_assistant_app/service/cloudflare_service.dart';

class ChatbotapiPage extends StatefulWidget {
  final String chatID;
  final String userID;
  const ChatbotapiPage({super.key, required this.chatID, required this.userID});

  @override
  _ChatbotapiPageState createState() => _ChatbotapiPageState();
}

class _ChatbotapiPageState extends State<ChatbotapiPage> with TickerProviderStateMixin {
  String chatID = ""; // Assign the chatbot's unique ID here
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [
  {
    'sender': "Bot",
    'message': "Hi! Ask me a question.",
    'avatar': "https://xiaoxintv.cc/template/mytheme/statics/image/20211025/25ef538a6.png",
    'image': null, // Initially no image
  }
];
final FirestoreChatbotService _firestoreChatbotService = FirestoreChatbotService();

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

  String currentUserName = '';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
 String generateRandomChatID() {
  final random = Random();
  const characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  return List.generate(10, (index) => characters[random.nextInt(characters.length)]).join();
}

@override
void initState() {
    super.initState();
    chatID = widget.chatID;
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

  Future<Stream<String>> _fetchResponseFromCloudflareStreaming(String message) async {
  String enhancedPrompt = await _firestoreChatbotService.preparePromptForCloudflare(message, widget.userID);
  const String accountId = "ae23db3966af53e871a0d1d3959af663";
  const String apiToken = "fZFo1LiOwtABSvLHu8W2ZcxJiiL4a5GrhHCbEGqR";
  const String model = "@cf/meta/llama-3.1-8b-instruct";

  final String url =
      "https://api.cloudflare.com/client/v4/accounts/$accountId/ai/run/$model";

  final streamController = StreamController<String>();

  try {
    final request = http.Request('POST', Uri.parse(url));
    request.headers.addAll({
      "Authorization": "Bearer $apiToken",
      "Content-Type": "application/json",
    });
    request.body = json.encode({"prompt": enhancedPrompt, "stream": true});

    final streamedResponse = await request.send();

    streamedResponse.stream
        .transform(utf8.decoder)
        .listen(
      (chunk) {
        try {
          // Remove 'data: ' prefix and parse JSON
          final lines = chunk.trim().split('\n');
          for (var line in lines) {
            if (line.startsWith('data: ')) {
              final jsonString = line.substring(6).trim();
              try {
                final jsonData = json.decode(jsonString);
                if (jsonData['response'] != null) {
                  streamController.add(jsonData['response']);
                }
              } catch (parseError) {
                print('Error parsing JSON: $parseError');
                print('Problematic line: $line');
              }
            }
          }
        } catch (e) {
          print("Error processing streaming response: $e");
        }
      },
      onDone: () {
        streamController.close();
      },
      onError: (error) {
        streamController.addError(error);
        streamController.close();
      },
    );

    return streamController.stream;
  } catch (e) {
    streamController.addError(e);
    streamController.close();
    return streamController.stream;
  }
}

// Fetch current user's name from Firestore
  Future<void> _fetchUserName(String currentUserID) async {
    try {
      // Query Firestore to find the user document by userID
      QuerySnapshot userSnapshot = await _firestore
          .collection('User')
          .where('userID', isEqualTo: currentUserID)
          .get();

      if (userSnapshot.docs.isNotEmpty) {
        // Extract the name from the user document
        setState(() {
          currentUserName = userSnapshot.docs[0]['name'] ?? 'Unknown User';
        });
      } else {
        setState(() {
          currentUserName = 'User not found';
        });
      }
    } catch (e) {
      print("Error fetching user name: $e");
      setState(() {
        currentUserName = 'Error fetching user name';
      });
    }
  }

  Future<void> _fetchNamesFromFirestore() async {
    try {
      // Fetch senior names
      QuerySnapshot userSnapshot = await _usersCollection.get();
      _seniorNames = userSnapshot.docs
          .map((doc) => doc['Name'].toString().toLowerCase())
          .toList();

      // Fetch medicine names
      QuerySnapshot medicineSnapshot = await _medicineCollection.get();
      _medicineNames = medicineSnapshot.docs
          .map((doc) => doc['Name'].toString().toLowerCase())
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

Future<void> _sendMessage(String message, {bool isFromChatbot = false}) async {
  if (message.trim().isNotEmpty || _image != null) {
    // Add the user's message to the local messages list
    setState(() {
      _messages.add({
        'sender': isFromChatbot ? 'Bot' : 'You',
        'message': message,
        'avatar': isFromChatbot
            ? "https://xiaoxintv.cc/template/mytheme/statics/image/20211025/25ef538a6.png"
            : "https://example.com/user-avatar.png", // Adjust user avatar URL if needed
        'image': _image,
        'timestamp': FieldValue.serverTimestamp(),
      });
    });

    // Clear the message input and reset the image
    if (!isFromChatbot) {
      _messageController.clear();
      setState(() {
        _image = null;
      });
    }

    try {
      // Generate a random chatID for user messages
      String randomChatID = generateRandomChatID();

      if (!isFromChatbot) {
        // Save the user message to the UserMessages collection
        await _firestore.collection('UserMessages').add({
          'conversationID': randomChatID,
          'userID': widget.userID,
          'textData': message,
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Fetch and handle the chatbot's response
        await _sendChatbotMessage(randomChatID, message);
      }
    } catch (e) {
      // Handle errors gracefully
      print("Error sending message: $e");
    }
  }
}

// Future<void> _sendChatbotMessage(String conversationID, String userMessage) async {
//       // Create a bot message placeholder in local state
//     final botMessageIndex = _messages.length;
//   try {
//     // Simulate fetching a response from a chatbot API or use actual chatbot logic
//     final responseStream = await _fetchResponseFromCloudflareStreaming(userMessage);
//     String fullResponse = '';


//     setState(() {
//       _messages.add({
//         'sender': 'Bot',
//         'message': '',  // Initially empty, will be updated in real-time
//         'avatar': "https://xiaoxintv.cc/template/mytheme/statics/image/20211025/25ef538a6.png",
//         'image': null,
//         'timestamp': FieldValue.serverTimestamp(),
//       });
//     });

//     // Listen to the streaming response and update the bot's message dynamically
//     await for (var chunk in responseStream) {
//       fullResponse += chunk;
//       setState(() {
//         // Update the bot message with the accumulated response
//         _messages[botMessageIndex]['message'] = fullResponse;
//       });
//     }

//     // Once the response is complete, save it to Firestore
//     await _firestore.collection('ChatbotResponses').add({
//       'conversationID': conversationID,
//       'chatbotID': chatID,  // Replace with actual chatbot ID
//       'receiverID': widget.userID,    // Target user for the response
//       'textData': fullResponse,
//       'timestamp': FieldValue.serverTimestamp(),
//     });

//   } catch (e) {
//     // Handle errors gracefully and update the UI
//     setState(() {
//       _messages[botMessageIndex]['message'] = 'Error: $e';
//     });
//     print("Error sending chatbot message: $e");
//   }
// }

Future<void> _sendChatbotMessage(String conversationID, String userMessage) async {
  // Add a placeholder for the bot's message
  final botMessageIndex = _messages.length;

  setState(() {
    _messages.add({
      'sender': 'Bot',
      'message': '', // Empty at first, to be updated dynamically
      'avatar': "https://xiaoxintv.cc/template/mytheme/statics/image/20211025/25ef538a6.png",
      'image': null,
      'timestamp': FieldValue.serverTimestamp(),
    });
  });

  try {
    // Use the FirestoreChatbotService to prepare a detailed prompt with user-specific context
    String enhancedPrompt =
        await _firestoreChatbotService.preparePromptForCloudflare(userMessage, widget.userID);

    // Fetch response from Cloudflare AI
    final responseStream = await _fetchResponseFromCloudflareStreaming(enhancedPrompt);
    String fullResponse = '';

    // Listen to the streaming response and update the bot's message dynamically
    await for (var chunk in responseStream) {
      fullResponse += chunk;
      setState(() {
        _messages[botMessageIndex]['message'] = fullResponse;
      });
    }

    // Save the bot's response to Firestore
    await _firestore.collection('ChatbotResponses').add({
      'conversationID': conversationID,
      'chatbotID': chatID,
      'receiverID': widget.userID,
      'textData': fullResponse,
      'timestamp': FieldValue.serverTimestamp(),
    });
  } catch (e) {
    // Handle errors gracefully and update the bot's message with an error notification
    setState(() {
      _messages[botMessageIndex]['message'] = 'Error: $e';
    });
    print("Error fetching chatbot response: $e");
  }
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

ScrollController _scrollController = ScrollController();

 @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Chat with Bot'),
    ),
    body: Column(
      children: [
        // Display Chatbot ID at the top
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text('Chatbot ID: $chatID'),
        ),
        
        // Display the chat messages and input area
        Expanded(
          child: ListView.builder(
            reverse: false,
            controller: _scrollController,
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final messageData = _messages[index];
              return chatDialog(
                avatar: messageData['avatar']!,
                name: messageData['sender']!,
                message: messageData['message']!,
                image: messageData['image'],
                isLeft: messageData['sender'] == 'Bot',
                context: context,
              );
            },
          ),
        ),
        
        // The input area for sending messages and voice control
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              // Show selected image if any
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
              
              // Message input field and buttons
              Row(
                children: [
                  // Voice button for long press to start listening
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
