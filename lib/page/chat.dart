import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:math';
import 'package:image_picker/image_picker.dart';
import 'dart:io'; // To use File for picked images
import 'package:medicine_assistant_app/widget/chat_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:medicine_assistant_app/service/chat_service.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';

class ChatPage extends StatefulWidget {
  String chatID;
  final String userID;
  final String receiverID; // Receiver ID passed from ChatListPage

  ChatPage(
      {super.key,
      required this.chatID,
      required this.userID,
      required this.receiverID});

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with TickerProviderStateMixin {
  String _currentUserName = '';
  String _receiverUserName = '';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _messageController = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  // Variable to hold image file
  File? _image;

  // Initialize the image picker
  final ImagePicker _picker = ImagePicker();

  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _spokenText = "";
  bool _isLoading = true;
  String chatID = "";
  bool _isSpeechAvailable = false; // Add this flag
  bool _isSendingMessage = false;

  @override
  void initState() {
    super.initState();
    _fetchUserNames();
    _initializeChatSession();
    _initializeSpeech(); // Add this method call

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
        _animationController
            .stop(); // Ensure the animation stops after 60 seconds
      }
    });
  }

  void updateChatID(String newChatID) {
    setState(() {
      chatID = newChatID;
    });
  }

  // Fetch current user's name from Firestore
  Future<void> _fetchUserNames() async {
    try {
      DocumentSnapshot currentUserSnapshot =
          await _firestore.collection('User').doc(widget.userID).get();
      DocumentSnapshot receiverUserSnapshot =
          await _firestore.collection('User').doc(widget.receiverID).get();

      if (currentUserSnapshot.exists) {
        setState(() {
          _currentUserName = currentUserSnapshot['name'] ?? 'Unknown User';
        });
      } else {
        print("Current user document not found.");
        setState(() {
          _currentUserName = 'Unknown User';
        });
      }

      if (receiverUserSnapshot.exists) {
        setState(() {
          _receiverUserName = receiverUserSnapshot['name'] ?? 'Unknown User';
        });
      } else {
        print("Receiver user document not found.");
        setState(() {
          _receiverUserName = 'Unknown User';
        });
      }
    } catch (e) {
      print("Error fetching user names: $e");
    }
  }

  @override
  void dispose() {
    // if (_animationController.isAnimating) {
    //   _animationController.stop();
    // }
    _animationController.dispose();
    // _speech.stop();
    super.dispose();
  }

 Future<void> _initializeSpeech() async {
  _speech = stt.SpeechToText();
  try {
    _isSpeechAvailable = await _speech.initialize(
      onStatus: (status) {
        print('Speech status: $status');
        if (status == 'notListening' && mounted) {
          setState(() => _isListening = false);
          _animationController.stop();
        }
      },
      onError: (errorNotification) {
        print('Speech error: $errorNotification');
        if (mounted) {
          setState(() {
            _isListening = false;
            _isSpeechAvailable = false;
          });
          _animationController.stop();
          _showSpeechError(errorNotification.errorMsg);
        }
      },
    );
  } catch (e) {
    print('Speech initialization error: $e');
    if (mounted) {
      setState(() {
        _isSpeechAvailable = false;
      });
      _showSpeechError('Speech recognition initialization failed');
    }
  }
}

  void _showSpeechError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _startListening() async {
    print('start');
    if (!_isSpeechAvailable) {
      _showSpeechError('Speech recognition is not available on this device');
      return;
    }

    try {
      setState(() => _isListening = true);
      _animationController.forward();

      await _speech.listen(
        onResult: (result) {
          setState(() {
            _spokenText = result.recognizedWords;
            _messageController.text = _spokenText;
          });
        },
        listenFor: Duration(seconds: 60),
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      );

      await Future.delayed(Duration(milliseconds: 500));

      while ((_speech.isListening)) {
        print('listen');

        await Future.delayed(Duration(milliseconds: 500));
      }
      print('stop');
      _stopListening();
      
    } catch (e) {
      print('Error starting speech recognition: $e');
      if (mounted) {
      setState(() => _isListening = false);
      _animationController.stop();
      _showSpeechError('Failed to start speech recognition');
    }
    }
  }

  void _stopListening() {
    if (_speech.isListening) {
      _speech.stop();
    }

    if(!_isListening)
    {
      return;
    }
    setState(() {
      _isListening = false;
    });
    // Stop the rotation animation
    _animationController.stop();
    _animationController.reset();

    Future.delayed(Duration(milliseconds: 500), () async {
      if (_spokenText.isNotEmpty) {
        // Send the spoken text as a message
        await _sendMessage(_spokenText);
        _spokenText = "";
      }
    });

    print('stop2');
  }

  Future<void> _initializeChatSession() async {
    try {
      print(
          "Initializing chat session for userID: ${widget.userID} and receiverID: ${widget.receiverID}");

      String? existingChatID = await ChatService().getExistingChatSession(
        widget.userID,
        widget.receiverID,
      );

      if (existingChatID != null) {
        print("Existing chat session found: $existingChatID");
        if (mounted) {
          setState(() {
            widget.chatID = existingChatID;
            updateChatID(existingChatID);
          });
        }
      } else {
        print("No existing session. Creating new session...");
        String newChatID = await ChatService().createChatSession(
          userID: widget.userID,
          receiverID: widget.receiverID,
        );
        if (mounted) {
          setState(() {
            widget.chatID = newChatID;
            updateChatID(newChatID);
          });
        }
      }

      print("Chat session initialized with chatID: ${widget.chatID}");
      await _fetchChatHistory();

      // _loadMessages();
    } catch (e) {
      print("Error initializing chat session: $e");
      if (mounted) {
        setState(() {
          _messages = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchChatHistory() async {
    if (widget.chatID.isEmpty) {
      print('No chat ID provided.');
      return;
    }

    try {
      print('Fetching chat history for chatID: ${widget.chatID}');
      final messagesSnapshot = await _firestore
          .collection('Chat')
          .doc(widget.chatID)
          .collection('Messages')
          .orderBy('timestamp', descending: false)
          .get();

      List<Map<String, dynamic>> messages = [];

      for (var doc in messagesSnapshot.docs) {
        Map<String, dynamic> messageData = doc.data() as Map<String, dynamic>;

        // Fetch senderName if it's missing
        if (messageData['senderName'] == null &&
            messageData['senderID'] != null) {
          DocumentSnapshot userSnapshot = await _firestore
              .collection('User')
              .doc(messageData['senderID'])
              .get();

          if (userSnapshot.exists) {
            messageData['senderName'] =
                userSnapshot['name'] ?? 'Unknown Sender';
          } else {
            messageData['senderName'] = 'Unknown Sender';
          }
        }

        messages.add(messageData);
      }

      setState(() {
        _messages = messages;
      });
    } catch (e) {
      print("Error fetching chat history: $e");
    }
  }

  Stream<List<Map<String, dynamic>>> getMessages(String chatID) {
    return _firestore
        .collection('Chat')
        .doc(chatID)
        .collection('Messages')
        .orderBy('timestamp')
        .snapshots()
        .asyncMap((snapshot) async {
      List<Map<String, dynamic>> messages = [];

      for (var doc in snapshot.docs) {
        Map<String, dynamic> messageData = doc.data() as Map<String, dynamic>;

        if (messageData['senderName'] == null &&
            messageData['senderID'] != null) {
          DocumentSnapshot userSnapshot = await _firestore
              .collection('User')
              .doc(messageData['senderID'])
              .get();

          messageData['senderName'] = userSnapshot.exists
              ? userSnapshot['name'] ?? 'Unknown Sender'
              : 'Unknown Sender';
        }

        messages.add(messageData);
      }

      return messages;
    });
  }

  // Send message to chat
// Future<void> _sendMessage(String message, {String? imageUrl}) async {
//   if (message.isEmpty && (imageUrl == null || imageUrl.isEmpty)) return;

//   try {
//     // Fetch the current user's name if not already fetched
//     if (_currentUserName.isEmpty) {
//       DocumentSnapshot currentUserSnapshot =
//           await _firestore.collection('User').doc(widget.userID).get();
//       _currentUserName = currentUserSnapshot['name'] ?? 'Unknown User';
//     }

//     final newMessage = {
//       'textData': message.isNotEmpty ? message : null,
//       'imageUrl': imageUrl,
//       'timestamp': DateTime.now(),
//       'senderID': widget.userID,
//       'senderName': _currentUserName, // Include senderName here
//       'receiverID': widget.receiverID,
//     };

//     await _firestore.collection('Chat').doc(widget.chatID).set({
//       'participants': [widget.userID, widget.receiverID],
//     });

//     // Add message to the Messages subcollection
//     await _firestore
//         .collection('Chat')
//         .doc(widget.chatID)
//         .collection('Messages')
//         .add(newMessage);

//     _messageController.clear();
//     setState(() {
//       _messages.add(newMessage); // Update message list
//       _image = null;  // Clear the image
//     });
//     _addNewMessage(newMessage);

//   } catch (e) {
//     print("Error sending message: $e");
//   }
// }
  Future<void> sendMessageWithImage() async {
    final String message = _messageController.text.trim();
    if (message.isEmpty && _image == null) return;

    setState(() {
      _isSendingMessage = true;
    });

    try {
      String? imageUrl;

      // Upload image if exists
      if (_image != null) {
        imageUrl = await _uploadImageToStorage(_image!);
      }

      // Create message data
      final newMessage = {
        'textData': message.isNotEmpty ? message : null,
        'imageUrl': imageUrl,
        'timestamp': DateTime.now(),
        'senderID': widget.userID,
        'senderName': _currentUserName,
        'receiverID': widget.receiverID,
      };

      // Ensure the chat document exists
      await _firestore.collection('Chat').doc(widget.chatID).set({
        'participants': [widget.userID, widget.receiverID],
      }, SetOptions(merge: true));

      // Add message to the Messages subcollection
      await _firestore
          .collection('Chat')
          .doc(widget.chatID)
          .collection('Messages')
          .add(newMessage);

      // Clear inputs and update UI
      if (mounted) {
        setState(() {
          _messageController.clear();
          _image = null;
          _messages.add(newMessage);
        });
      }

      // Scroll to bottom after sending
      _scrollToBottom();

    } catch (e) {
      print('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message. Please try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingMessage = false;
        });
      }
    }
  }

  Future<void> _sendMessage(String message, {String? imageUrl}) async {
    if (message.isEmpty && (imageUrl == null || imageUrl.isEmpty)) return;

    try {
      // Fetch the current user's name if not already fetched
      if (_currentUserName.isEmpty) {
        DocumentSnapshot currentUserSnapshot =
            await _firestore.collection('User').doc(widget.userID).get();
        _currentUserName = currentUserSnapshot['name'] ?? 'Unknown User';
      }

      final newMessage = {
        'textData': message.isNotEmpty ? message : null,
        'imageUrl': imageUrl,
        'timestamp': DateTime.now(),
        'senderID': widget.userID,
        'senderName': _currentUserName, // Include senderName here
        'receiverID': widget.receiverID,
      };

      // Ensure the chat document exists
      await _firestore.collection('Chat').doc(widget.chatID).set({
        'participants': [widget.userID, widget.receiverID],
      });

      // Add message to the Messages subcollection
      await _firestore
          .collection('Chat')
          .doc(widget.chatID)
          .collection('Messages')
          .add(newMessage);

      // Update the UI after the message is added
      setState(() {
        _messages.add(newMessage); // Add message to the local message list
        _messageController.text = "";
        _spokenText = "";
      });
    } catch (e) {
      print("Error sending message: $e");
    }
  }

  Future<void> updateParticipants(String chatID, String newUserID) async {
    try {
      DocumentReference chatRef =
          FirebaseFirestore.instance.collection('Chat').doc(chatID);

      await chatRef.update({
        'participants': FieldValue.arrayUnion([newUserID]),
      });
    } catch (e) {
      print('Error updating participants: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> getUserChats(String userID) {
    return FirebaseFirestore.instance
        .collection('Chat')
        .where('participants', arrayContains: userID)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  Future<void> sendImageMessage() async {
    try {
      if (_image != null) {
        // Upload image to Firebase Storage
        String imageUrl = await _uploadImageToStorage(_image!);
        // Send the image URL as part of the message
        await _sendMessage('', imageUrl: imageUrl);
        // _scrollToBottom();
      } else {
        print('No image selected.');
      }
    } catch (e) {
      print('Error uploading image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload image. Please try again.')),
      );
    }
  }

Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedImage = await _picker.pickImage(source: source);
      if (pickedImage != null) {
        setState(() {
          _image = File(pickedImage.path);
        });
        // Uncomment if you want to upload the image after selection
        // await uploadImageToFirestore(_image!);
      } else {
        print('No image picked');
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  Future<String?> convertImageToBase64(File imageFile) async {
    try {
      // Read the image as bytes
      Uint8List imageBytes = await imageFile.readAsBytes();

      // Convert the bytes to Base64 string
      String base64String = base64Encode(imageBytes);

      return base64String;
    } catch (e) {
      print('Error converting image to Base64: $e');
      return null;
    }
  }

  Future<void> uploadImageToFirestore(File imageFile) async {
    try {
      // Upload image to Firebase Storage and get the image URL
      String imageUrl = await _uploadImageToStorage(imageFile);

      // Send the message with the image URL
      await _sendMessage('', imageUrl: imageUrl);
    } catch (e) {
      print('Error uploading image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload image. Please try again.')),
      );
    }
  }

  Future<void> storeImageInFirestore(String base64Image) async {
    try {
      // Add the Base64 encoded image to Firestore
      await _firestore
          .collection('Chat')
          .doc(widget.chatID)
          .collection('Messages')
          .add({
        'imageUrl': base64Image,
        'timestamp': FieldValue.serverTimestamp(),
        'senderID': widget.userID,
        'senderName': _currentUserName,
        'receiverID': widget.receiverID,
      });

      print('Image stored successfully in Firestore!');
    } catch (e) {
      print('Error storing image in Firestore: $e');
    }
  }

  Widget buildMessage(Map<String, dynamic> message) {
    final textData = message['textData'];
    final imageUrl =
        message['imageUrl']; // Image URL fetched from Firebase Storage

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl, // Load the image directly from the network
        width: 100,
        height: 100,
        fit: BoxFit.cover,
        cacheHeight: 100,
        cacheWidth: 100,
      );
    } else if (textData != null && textData.isNotEmpty) {
      return Text(textData); // Show the text if there's no image
    } else {
      return Text('No content available.');
    }
  }

  void onSendImage() {
    if (_image != null) {
      sendImageMessage();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('No image selected. Please pick an image first.')),
      );
    }
  }

// Upload image to Firebase Storage and return the URL
  Future<String> _uploadImageToStorage(File imageFile) async {
    try {
      String fileName = DateTime.now()
          .millisecondsSinceEpoch
          .toString(); // Unique filename based on timestamp
      Reference storageRef =
          FirebaseStorage.instance.ref().child('chat_images').child(fileName);

      // Upload the image file
      UploadTask uploadTask = storageRef.putFile(imageFile);
      TaskSnapshot taskSnapshot = await uploadTask.whenComplete(() => null);

      // Get the download URL of the uploaded image
      String imageUrl = await taskSnapshot.ref.getDownloadURL();
      return imageUrl;
    } catch (e) {
      print('Error uploading image: $e');
      return '';
    }
  }

  ScrollController _scrollController = ScrollController();

// Call this method after a new message is added to scroll to the bottom
  void _scrollToBottom() async {
    if (_scrollController.hasClients) {
      // Scroll to the bottom of the ListView

      while (_scrollController.position.maxScrollExtent >
          _scrollController.position.pixels) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );

        await Future.delayed(
          const Duration(milliseconds: 310),
        );
      }
    }
  }

// Call this when new messages are added or fetched
  void _addNewMessage(Map<String, dynamic> newMessage) {
    setState(() {
      _messages.add(newMessage);
    });

    // Scroll to the bottom after adding the new message
    _scrollToBottom();
  }

   Widget _buildMessageList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_messages.isEmpty) {
      return const Center(child: Text('No messages yet.'));
    }

    return ListView.builder(
      reverse: false,
      controller: _scrollController,
      itemCount: _messages.length,
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final messageData = _messages[index];
        final isCurrentUser = messageData['senderID'] == widget.userID;
        
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: chatDialog(
            name: messageData['senderName'] ?? 'Unknown User',
            message: messageData['textData'],
            imageUrl: messageData['imageUrl'],
            isLeft: !isCurrentUser,
            context: context,
            avatar: '', // Add avatar URL if you have one
          ),
        );
      },
    );
  }

  Widget _buildVoiceButton() {
    return SizedBox(
      width: 70,
      height: 70,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: !_isSpeechAvailable
                ? Colors.grey // Disabled state
                : _isListening
                    ? Colors.red
                    : Colors.blue,
            child: Icon(
              Icons.mic,
              color: _isSpeechAvailable ? Colors.white : Colors.black38,
              size: 25,
            ),
          ),
          if (_isListening)
            AnimatedBuilder(
              animation: _rotationAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _rotationAnimation.value,
                  child: CustomPaint(
                    size: const Size(70, 70),
                    painter:
                        RingPainter(angle: _rotationAnimation.value * 2 * pi),
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
    updateChatID(widget.chatID);
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat with $_receiverUserName'),
      ),
      body: Column(
        children: [
          // Display current user name or loading indicator
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: _currentUserName.isEmpty
                ? const CircularProgressIndicator()
                : Text('Hello, $_currentUserName. ChatID: $chatID'),
          ),

          // Message List
          Expanded(
            child: _buildMessageList(),
          ),
          
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                if (_image != null)
                  Column(
                    children: [
                      Stack(
                        alignment: Alignment.topRight,
                        children: [
                          Image.file(
                            _image!,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _image = null;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                Row(
                  children: [
                    GestureDetector(
                      onLongPressStart: _isSpeechAvailable
                          ? (details) => _startListening()
                          : null,
                      onLongPressEnd: _isSpeechAvailable
                          ? (details) => _stopListening()
                          : null,
                      child: _buildVoiceButton(),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        enabled: !_isSendingMessage,
                        decoration: const InputDecoration(
                          hintText: 'Type your message...',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}), // Rebuild for send button state
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.image),
                      onPressed: _isSendingMessage
                          ? null
                          : () {
                              showModalBottomSheet(
                                context: context,
                                builder: (BuildContext context) {
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ListTile(
                                        leading: const Icon(Icons.camera_alt),
                                        title: const Text("Take Photo"),
                                        onTap: () {
                                          Navigator.pop(context);
                                          _pickImage(ImageSource.camera);
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.photo_library),
                                        title: const Text("Choose from Gallery"),
                                        onTap: () {
                                          Navigator.pop(context);
                                          _pickImage(ImageSource.gallery);
                                        },
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                    ),
                    _isSendingMessage
                        ? Container(
                            width: 48,
                            height: 48,
                            padding: const EdgeInsets.all(12),
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.send),
                            onPressed: (_messageController.text.trim().isNotEmpty ||
                                    _image != null)
                                ? () => sendMessageWithImage()
                                : null,
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
