class Chatbot {
  final String chatbotID;
  final String messageContent;
  final String responseContent;
  final DateTime timestamp;
  final String userID;

  Chatbot({
    required this.chatbotID,
    required this.messageContent,
    required this.responseContent,
    required this.timestamp,
    required this.userID,
  });
}