import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreChatbotService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Method to retrieve contextual information from Firestore
  Future<String> prepareContextualInformation() async {
    try {
      // Fetch users
      QuerySnapshot userSnapshot = await _firestore.collection('User').get();
      
      // Fetch medicines
      QuerySnapshot medicineSnapshot = await _firestore.collection('Medicine').get();
      
      // Fetch reminders
      QuerySnapshot reminderSnapshot = await _firestore.collection('Reminder').get();

      // Prepare context data
      Map<String, dynamic> contextData = {};

      for (var userDoc in userSnapshot.docs) {
        String userId = userDoc.id;
        String name = userDoc['name'] ?? 'Unknown';
        String phoneNo = userDoc['phoneNo'] ?? 'No contact information';
        String emergencyContact = userDoc['emergencyContact'] ?? 'No emergency contact';

        // Fetch medicines for this user efficiently
        List<Map<String, dynamic>> userMedicines = medicineSnapshot.docs
            .where((medDoc) => medDoc['seniorID'].path.contains(userId))
            .map((medDoc) {
          // Find corresponding reminder (improved null handling)
          QueryDocumentSnapshot? relatedReminder;
          try {
            relatedReminder = reminderSnapshot.docs.firstWhere(
              (reminderDoc) => reminderDoc['medicineID'].path.contains(medDoc.id),
            );
          } catch (e) {
            relatedReminder = null;
          }

          return {
            'name': medDoc['name'] ?? 'Unknown Medicine',
            'dose': medDoc['dose'] ?? 'Not specified',
            'reminder_details': relatedReminder != null ? {
              'frequency': relatedReminder['frequency'] ?? 'Not specified',
              'dosage': relatedReminder['dosage'] ?? 'Not specified',
              'status': relatedReminder['status'] ?? 'Unknown',
              'times': relatedReminder['times'] ?? []
            } : 'No reminder found'
          };
        }).toList();

        contextData[userId] = {
          'name': name,
          'phone': phoneNo,
          'emergency_contact': emergencyContact,
          'medicines': userMedicines.isEmpty ? 'No medicines assigned' : userMedicines
        };
      }

      // Convert contextual information to a formatted prompt-friendly string
      return _formatContextForPrompt(contextData);
    } catch (e) {
      print("Error retrieving contextual information: $e");
      return "Unable to retrieve contextual information.";
    }
  }

  // Format context data into a prompt-friendly string
  String _formatContextForPrompt(Map<String, dynamic> contextData) {
    List<String> formattedUsers = [];

    contextData.forEach((userId, userData) {
      List<String> medicineDetails = (userData['medicines'] is List)
          ? (userData['medicines'] as List).map((medicine) {
              return "Medicine: ${medicine['name']}, Dose: ${medicine['dose']}, "
                     "Reminder: ${medicine['reminder_details'] is Map 
                      ? "Frequency ${medicine['reminder_details']['frequency']}, "
                        "Status ${medicine['reminder_details']['status']}"
                      : "No specific details"}";
            }).toList()
          : ['No medicines assigned'];

      formattedUsers.add(''' 
      User: ${userData['name']}
      Phone: ${userData['phone']}
      Emergency Contact: ${userData['emergency_contact']}
      Medicines: ${medicineDetails.join(', ')}
            ''');
          });

          return '''
      Contextual User Information:
      ${formattedUsers.join('\n\n')}

      Instructions:
      - Use the above contextual information to answer questions
      - If the information is not sufficient, ask for more details
      - Provide clear and concise responses
      ''';
  }

  // Prepare the final prompt for Cloudflare AI
//   Future<String> preparePromptForCloudflare(String userQuestion) async {
//     // Retrieve contextual information
//     String contextInformation = await prepareContextualInformation();

//     // Create a comprehensive prompt
//     return '''
// $contextInformation

// User Question: $userQuestion

// Detailed Instructions:
// 1. Carefully analyze the contextual information provided
// 2. Answer the user's question using the available context
// 3. If the question cannot be directly answered:
//    - Explain what information is missing
//    - Suggest how the user might get more specific information
// 4. Be helpful, precise, and conversational
// 5. If multiple matches are found, provide a consolidated response
// ''';
//   }

Future<String> preparePromptForCloudflare(String userMessage, String userID) async {
  String userDetails = '';
  String medicineDetails = '';
  String reminderDetails = '';
  String connectedUserDetails = '';

  try {
    // Function to fetch user data, medicines, and reminders
    Future<String> fetchUserData(String targetUserID) async {
      String details = '';
      try {
        // Fetch user details
        DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
            .collection('User')
            .doc(targetUserID)
            .get();
        if (userSnapshot.exists) {
          details += "User: ${userSnapshot['name']}, Email: ${userSnapshot['email']}, Phone: ${userSnapshot['phoneNo']}\n";

          // Fetch medicines for the user
          QuerySnapshot medicineSnapshot = await FirebaseFirestore.instance
              .collection('Medicine')
              .where('seniorID', isEqualTo: FirebaseFirestore.instance.doc('User/$targetUserID'))
              .get();
          if (medicineSnapshot.docs.isNotEmpty) {
            List<String> medicines = medicineSnapshot.docs
                .map((doc) => "${doc['name']} (${doc['dose']})")
                .toList();
            details += "Medicines: ${medicines.join(', ')}\n";
          }

          // Fetch reminders for the user
          QuerySnapshot reminderSnapshot = await FirebaseFirestore.instance
              .collection('Reminder')
              .where('seniorID', isEqualTo: FirebaseFirestore.instance.doc('User/$targetUserID'))
              .get();
          if (reminderSnapshot.docs.isNotEmpty) {
            List<String> reminders = reminderSnapshot.docs.map((doc) {
              String times = (doc['times'] as List<dynamic>)
                  .map((time) => (time as Timestamp).toDate().toString())
                  .join(', ');
              return "Medicine: ${doc['dosage']}, Times: $times";
            }).toList();
            details += "Reminders: ${reminders.join(', ')}\n";
          }
        }
      } catch (e) {
        print("Error fetching data for user $targetUserID: $e");
      }
      return details;
    }

    // Fetch primary user details
    userDetails = await fetchUserData(userID);

    // Fetch connected users (guardians or seniors)
    DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
        .collection('User')
        .doc(userID)
        .get();
    if (userSnapshot.exists) {
      List<dynamic> connectedUsers = userSnapshot['seniorIDs'] ?? [];
      connectedUsers.addAll(userSnapshot['guardianIDs'] ?? []);
      for (var connectedRef in connectedUsers) {
        if (connectedRef != "") {
          String connectedUserID = (connectedRef as DocumentReference).id;
          String connectedDetails = await fetchUserData(connectedUserID);
          connectedUserDetails += "Connected User Details:\n$connectedDetails\n";
        }
      }
    }
  } catch (e) {
    print("Error preparing prompt: $e");
  }

  // Combine all details into a single prompt
  String fullPrompt = """
Context:
Primary User Details:
$userDetails

Connected Users:
$connectedUserDetails

Question: $userMessage
""";
  return fullPrompt;
}


}
