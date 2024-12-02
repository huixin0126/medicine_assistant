import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:medicine_assistant_app/class/chat.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check for an existing chat session between two users
// Future<String?> getExistingChatSession(String userID, String receiverID) async {
//   try {
//     QuerySnapshot snapshot = await _firestore
//         .collection('ChatSession')
//         .where('participants', arrayContainsAny: [userID, receiverID])
//         .get();

//     if (snapshot.docs.isNotEmpty) {
//       // Assume only one chat session exists between two users
//       return snapshot.docs.first.id;
//     } else {
//       return null; // No existing chat session
//     }
//   } catch (e) {
//     print('Error checking for existing chat session: $e');
//     return null;
//   }
// }

Future<String?> getExistingChatSession(String userID1, String userID2) async {
  QuerySnapshot chatSessions = await _firestore
      .collection('ChatSession')
      .where('participants', arrayContains: userID1)
      .get();

  for (var doc in chatSessions.docs) {
    List<dynamic> participants = doc['participants'] ?? [];
    if (participants.contains(userID2)) {
      return doc.id; // Return the chatID if both users are participants
    }
  }

  return null; // No valid chat session found
}


/// Create a new ChatSession with user and receiver details
Future<String> createChatSession({required String userID, required String receiverID}) async {
  String chatID = _generateRandomChatID();

  try {
    await _firestore.collection('ChatSession').doc(chatID).set({
      'chatID': chatID,
      'participants': [userID, receiverID],
      'timestamp': FieldValue.serverTimestamp(),
    });
    return chatID;
  } catch (e) {
    print('Error creating chat session: $e');
    throw Exception('Failed to create chat session.');
  }
}

  /// Generate a random 8-character alphanumeric ChatID
  String _generateRandomChatID() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(8, (index) => chars[Random().nextInt(chars.length)]).join();
  }

  /// Save a message to Firestore
Future<void> saveMessage({
  required String chatID,
  required String senderID,
  required String receiverID,
  String? message,
  String? imageUrl,
}) async {
  try {
    CollectionReference chatCollection = FirebaseFirestore.instance.collection('Chat');
    await chatCollection.add({
      'chatID': chatID,
      'senderID': senderID,
      'receiverID': receiverID,
      'textData': message,
      'imageUrl': imageUrl, // Save the image URL if provided
      'timestamp': DateTime.now(),
      'participants': [senderID, receiverID],
    });
  } catch (e) {
    print("Error saving message: $e");
  }
}


  Future<List<Map<String, dynamic>>> getChatHistory(String chatID) async {
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('Chat')
          .where('chatID', isEqualTo: chatID)
          .orderBy('timestamp', descending: false)
          .get();

      // Fetch sender names for each message
      List<Map<String, dynamic>> messages = [];
      for (var doc in querySnapshot.docs) {
        var messageData = doc.data() as Map<String, dynamic>;
        
        // Fetch sender name
        DocumentSnapshot senderSnapshot = await FirebaseFirestore.instance
            .collection('User')
            .doc(messageData['senderID'])
            .get();

        messages.add({
          ...messageData,
          'senderName': senderSnapshot['name'] ?? 'Unknown User',
          'timestamp': messageData['timestamp'] ?? DateTime.now(),
        });
      }

      return messages;
    } catch (e) {
      print("Error getting chat history: $e");
      return [];
    }
  }

  Stream<List<Chat>> fetchMessages(String chatID) {
  return FirebaseFirestore.instance
      .collection('Chat') // Ensure this matches your Firestore schema
      .where('chatID', isEqualTo: chatID)
      .orderBy('timestamp', descending: false) // Consider adding an index if needed
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => Chat.fromFirestore(doc)).toList());
}

}