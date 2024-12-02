import 'package:cloud_firestore/cloud_firestore.dart';

class Chat {
  final String chatID;
  final List<String> participants;
  final String senderID;
  final String receiverID;
  final String textData;
  final Timestamp timestamp;

  Chat({
    required this.chatID,
    required this.participants,
    required this.senderID,
    required this.receiverID,
    required this.textData,
    required this.timestamp,
  });

  factory Chat.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Chat(
      chatID: data['chatID'] ?? '',
      participants: List<String>.from(data['participants'] ?? []),
      senderID: data['senderID'] ?? '',
      receiverID: data['receiverID'] ?? '',
      textData: data['textData'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
    );
  }
}
