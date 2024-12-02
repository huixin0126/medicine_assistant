import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:medicine_assistant_app/page/chat.dart';
import 'package:medicine_assistant_app/page/chatbotapi.dart';
import 'package:medicine_assistant_app/service/chat_service.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  _ChatListPageState createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  var chatIDs = <String>[];

  late Future<List<Map<String, dynamic>>> _chatsFuture;

  @override
  void initState() {
    super.initState();
    // Fetch the chat list initially
    _chatsFuture = _fetchConnectedUsers('1'); // Replace '2' with the current user ID
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-fetch chat data when returning from the chat page
    setState(() {
      _chatsFuture = _fetchConnectedUsers('1'); // Replace '2' with the current user ID
    });
  }

  Future<void> _refreshChats() async {
    // Manually trigger a refresh
    setState(() {
      _chatsFuture = _fetchConnectedUsers('1'); // Replace '2' with the current user ID
    });
  }

  Future<String> _generateChatbotID() async {
    try {
      DocumentReference chatbotRef = await _firestore.collection('ChatbotSessions').add({
        'createdAt': FieldValue.serverTimestamp(),
      });
      return chatbotRef.id;
    } catch (e) {
      print("Error generating chatbot ID: $e");
      return 'chatbotUniqueID';
    }
  }

Future<List<Map<String, dynamic>>> _fetchConnectedUsers(String userId) async {
  try {
    // Fetch the current user's document
    DocumentSnapshot userSnapshot = await _firestore.collection('User').doc(userId).get();

    if (!userSnapshot.exists) {
      print("User document not found");
      return [];
    }

    // Combine guardian and senior IDs, defaulting to empty lists if null
    List<dynamic> connectedUsers = [
      ...(userSnapshot['guardianIDs'] ?? []),
      ...(userSnapshot['seniorIDs'] ?? []),
    ];

    List<Map<String, dynamic>> users = [];

    for (var connectedUserRef in connectedUsers) {
      if (connectedUserRef == null || (connectedUserRef is String && connectedUserRef.isEmpty)) {
        print("Skipping invalid connected user reference: $connectedUserRef");
        continue; // Skip invalid references
      }

      try {
        // Resolve connected user references
        DocumentReference connectedUserDocRef = connectedUserRef is String
            ? _firestore.collection('User').doc(connectedUserRef)
            : connectedUserRef as DocumentReference;

        // Fetch the connected user's document
        DocumentSnapshot connectedUserSnapshot = await connectedUserDocRef.get();

        if (connectedUserSnapshot.exists) {
          String connectedUserID = connectedUserSnapshot.id;

          // Check for an existing chat session where both users are participants
          String? chatID = await ChatService().getExistingChatSession(userId, connectedUserID);

          // Validate the chat session participants
          if (chatID != null) {
            DocumentSnapshot chatSessionSnapshot = await _firestore.collection('ChatSession').doc(chatID).get();

            if (chatSessionSnapshot.exists) {
              List<dynamic> participants = chatSessionSnapshot['participants'] ?? [];
              if (!participants.contains(userId) || !participants.contains(connectedUserID)) {
                chatID = null; // Reset chatID if the participants are incorrect
              }
            }
          }

          // Add the connected user's details along with the chat ID (if valid)
          users.add({
            'userID': connectedUserID,
            'userName': connectedUserSnapshot['name'] ?? 'Unknown User',
            'userAvatar': connectedUserSnapshot['avatar'] ?? '',
            'chatID': chatID ?? '', // Leave blank if no valid chat session
          });
        } else {
          print("Connected user document not found: ${connectedUserDocRef.id}");
        }
      } catch (e) {
        print("Error fetching connected user: $e");
      }
    }

    // Add chatbot details with a unique chatbot ID
    users.add({
      'userID': 'chatbot',
      'userName': 'Chatbot',
      'userAvatar': 'https://example.com/chatbot-avatar.png', // Replace with your chatbot avatar
      'chatID': '', // Leave blank as the chatbot session is dynamic
    });

    return users;
  } catch (e) {
    print("Error fetching connected users: $e");
    return [];
  }
}

  // Function to fetch the most recent message for a given chat ID
  Future<String> _getMostRecentMessage(String chatID) async {
    try {
      if (chatID.isEmpty) {
        return 'No recent message';
      }

      QuerySnapshot querySnapshot = await _firestore
          .collection('Chat')
          .doc(chatID)
          .collection('Messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        var messageData = querySnapshot.docs.first.data() as Map<String, dynamic>;
        String message = messageData['textData'] ?? 'No message content';
        return message;
      }

      return 'No recent message';
    } catch (e) {
      return 'Error fetching message';
    }
  }

Future<String> getReceiverID(String chatID, String userID) async {
  try {
    QuerySnapshot chatSnapshot = await _firestore
        .collection('Chat')
        .where('chatID', isEqualTo: chatID)
        .limit(1)
        .get();

    if (chatSnapshot.docs.isNotEmpty) {
      var data = chatSnapshot.docs.first.data() as Map<String, dynamic>;

      if (data == null || !data.containsKey('participants')) {
        print("No participants found for chatID: $chatID");
        return 'chatbot';  // Return 'chatbot' if no participants are found
      }

      List<dynamic> participants = data['participants'] ?? [];

      // Look for the participant who is not the current user
      for (var participant in participants) {
        if (participant != userID) {
          print("Found receiver ID: $participant");
          return participant;
        }
      }

      // If we reach this point and no valid receiver was found, return 'chatbot'
      print("Receiver ID not found, returning 'chatbot'");
      return 'chatbot';
    } else {
      print("No chat found for chatID: $chatID");
      return 'chatbot';  // Return 'chatbot' if the chat doesn't exist
    }
  } catch (e) {
    print("Error fetching chat participants: $e");
    return 'chatbot';  // Return 'chatbot' in case of an error
  }
}

Future<String> _getChatID(String receiverID, String userID) async {
  try {
    // Check if the receiver is the chatbot
    if (receiverID == 'chatbot') {
      return await _generateChatbotID();
    }

    // Check for an existing chat session
    String? existingChatID = await ChatService().getExistingChatSession(userID, receiverID);

    if (existingChatID != null) {
      return existingChatID;
    } else {
      // Create a new chat session if none exists
      return await ChatService().createChatSession(userID: userID, receiverID: receiverID);
    }
  } catch (e) {
    print("Error fetching or creating chat ID: $e");
    return 'ErrorFetchingChatID'; // Fallback value
  }
}

// @override
//   Widget build(BuildContext context) {
//     final String userId = '2'; // Replace with current logged-in user's ID

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Chats'),
//       ),
//       body: FutureBuilder<List<Map<String, dynamic>>>( 
//         future: _fetchConnectedUsers(userId),
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return const Center(child: CircularProgressIndicator());
//           } else if (snapshot.hasError) {
//             return const Center(child: Text('Error fetching chats.'));
//           } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
//             return const Center(child: Text('No chats available.'));
//           } else {
//             final chats = snapshot.data!;

//             return ListView.builder(
//               itemCount: chats.length,
//               itemBuilder: (context, index) {
//                 final chat = chats[index];

//                 // Get the receiverID based on the current userID and participants
//                 final String receiverID = chat['userID'] != userId ? chat['userID'] : 'Unknown';

//                 return FutureBuilder<String>(
//                   future: _getMostRecentMessage(chat['chatID'] ?? ''),
//                   builder: (context, messageSnapshot) {
//                     if (messageSnapshot.connectionState == ConnectionState.waiting) {
//                       return const ListTile(title: Text('Loading...'));
//                     } else if (messageSnapshot.hasError) {
//                       return ListTile(title: Text('Error loading message'));
//                     } else {
//                       String message = messageSnapshot.data ?? 'No message';
//                       return ListTile(
//                         leading: CircleAvatar(
//                           backgroundImage: NetworkImage(chat['userAvatar']),
//                         ),
//                         title: Text(chat['userName']),
//                         subtitle: Text(message),
//                         onTap: () async {
//                           String chatID = chat['chatID'] ?? '';
//                           if (receiverID == 'chatbot') {
//                             String chatbotID = await _generateChatbotID();
//                             Navigator.push(
//                               context,
//                               MaterialPageRoute(
//                                 builder: (context) => ChatbotapiPage(
//                                   chatID: chatbotID, // Use chatbotID here
//                                   userID: userId,
//                                 ),
//                               ),
//                             );
//                           } else {
//                             // Use existing or newly created chatID and navigate to chat page
//                             Navigator.push(
//                               context,
//                               MaterialPageRoute(
//                                 builder: (context) => ChatPage(
//                                   chatID: chatID, // Use the dynamic chatID for regular chats
//                                   userID: userId,
//                                   receiverID: receiverID, // The receiver's ID
//                                 ),
//                               ),
//                             );
//                           }
//                         },
//                       );
//                     }
//                   },
//                 );
//               },
//             );
//           }
//         },
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () async {
//           String chatbotID = await _generateChatbotID();
//           Navigator.push(
//             context,
//             MaterialPageRoute(
//               builder: (context) => ChatbotapiPage(
//                 chatID: chatbotID,
//                 userID: userId,
//               ),
//             ),
//           );
//         },
//         child: const Icon(Icons.chat),
//       ),
//     );
//   }
// }

@override
  Widget build(BuildContext context) {
    final String userId = '1'; // Replace with the current logged-in user's ID

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _chatsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text('Error fetching chats.'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No chats available.'));
          } else {
            final chats = snapshot.data!;
            return RefreshIndicator(
              onRefresh: _refreshChats,
              child: ListView.builder(
                itemCount: chats.length,
                itemBuilder: (context, index) {
                  final chat = chats[index];
                  final String receiverID = chat['userID'] != userId ? chat['userID'] : 'Unknown';

                  return FutureBuilder<String>(
                    future: _getMostRecentMessage(chat['chatID'] ?? ''),
                    builder: (context, messageSnapshot) {
                      if (messageSnapshot.connectionState == ConnectionState.waiting) {
                        return const ListTile(title: Text('Loading...'));
                      } else if (messageSnapshot.hasError) {
                        return ListTile(title: Text('Error loading message'));
                      } else {
                        String message = messageSnapshot.data ?? 'No message';
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: NetworkImage(chat['userAvatar']),
                          ),
                          title: Text(chat['userName']),
                          subtitle: Text(message),
                          onTap: () async {
                            String chatID = chat['chatID'] ?? '';
                            if (receiverID == 'chatbot') {
                              String chatbotID = await _generateChatbotID();
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatbotapiPage(
                                    chatID: chatbotID,
                                    userID: userId,
                                  ),
                                ),
                              );
                            } else {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatPage(
                                    chatID: chatID,
                                    userID: userId,
                                    receiverID: receiverID,
                                  ),
                                ),
                              );
                            }
                            // Trigger a refresh after returning from the chat page
                            _refreshChats();
                          },
                        );
                      }
                    },
                  );
                },
              ),
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          String chatbotID = await _generateChatbotID();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatbotapiPage(
                chatID: chatbotID,
                userID: userId,
              ),
            ),
          );
        },
        child: const Icon(Icons.chat),
      ),
    );
  }
}