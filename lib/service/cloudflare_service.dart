import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:medicine_assistant_app/page/helpAddReminder.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreChatbotService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Medicine Information Database (Hardcoded for medicines not in Firestore)
  final Map<String, Map<String, dynamic>> _medicineDatabase = {
    'paracetamol': {
      'generic_name': 'Acetaminophen',
      'usage': 'Used to treat mild to moderate pain and reduce fever. It helps relieve conditions such as headaches, muscle aches, arthritis, backaches, toothaches, colds, and menstrual cramps.',
      'side_effects': [
        'Nausea',
        'Stomach pain',
        'Loss of appetite',
        'Headache',
        'Unusual tiredness or weakness'
      ],
      'warnings': [
        'Do not exceed recommended dosage',
        'Avoid alcohol while taking this medication',
        'Consult a doctor if symptoms persist'
      ]
    },
    'ibuprofen': {
      'generic_name': 'Ibuprofen',
      'usage': 'A nonsteroidal anti-inflammatory drug (NSAID) used to reduce pain, fever, and inflammation. Commonly used for headaches, muscle aches, arthritis, menstrual cramps, and minor injuries.',
      'side_effects': [
        'Stomach upset or pain',
        'Nausea',
        'Vomiting',
        'Diarrhea',
        'Dizziness',
        'Mild heartburn'
      ],
      'warnings': [
        'May increase risk of heart attack or stroke',
        'Do not use for prolonged periods without medical supervision',
        'Avoid if you have a history of stomach ulcers'
      ]
    }
  };

  // Fetch comprehensive user data including connected users and reminders
Future<String> fetchUserData(String targetUserID) async {
  String details = '';
  try {
    // Fetch primary user details
    DocumentSnapshot userSnapshot = await _firestore
        .collection('User')
        .doc(targetUserID)
        .get();

    if (userSnapshot.exists) {
      // User Basic Information
      details += '''
User Profile:
- Name: ${userSnapshot['name'] ?? 'Unknown'}
- Email: ${userSnapshot['email'] ?? 'Not provided'}
- Phone: ${userSnapshot['phoneNo'] ?? 'Not provided'}
- Emergency Contact: ${userSnapshot['emergencyContact'] ?? 'Not set'}
''';

      // Fetch and add medicines for the user
      details += await _fetchUserMedicineDetails(targetUserID);

      // Fetch reminder details for the user
      String reminderDetails = await fetchReminderDetails(targetUserID);
      details += reminderDetails.isNotEmpty ? reminderDetails : "No reminders set.\n";

      // Fetch connected users (seniors and guardians)
      details += await _fetchConnectedUsersDetails(userSnapshot);
    } else {
      details = "No user found with the given ID.";
    }
  } catch (e) {
    print("Error fetching data for user $targetUserID: $e");
    details = "Error retrieving user information.";
  }
  return details;
}

  // Fetch medicine details for a specific user
Future<String> _fetchUserMedicineDetails(String userID) async {
  String medicineDetails = '';
  try {
    // Fetch medicines for the user
    QuerySnapshot medicineSnapshot = await _firestore
        .collection('Medicine')
        .where('seniorID', isEqualTo: _firestore.doc('/User/$userID'))
        .get();

    if (medicineSnapshot.docs.isNotEmpty) {
      medicineDetails += "Medicines:\n";
      for (var medDoc in medicineSnapshot.docs) {
        String medicineName = medDoc['name']?.toLowerCase() ?? 'unknown';
        
        // Fetch corresponding reminder details for this medicine
        // String reminderInfo = await fetchReminderDetails(userID);

        // Get additional medicine information (hardcoded or from Firestore)
        Map<String, dynamic>? medicineInfo = _getMedicineInformation(medicineName);

        medicineDetails += '''
  Medicine:
  - Name: ${medDoc['name'] ?? 'Unknown'}
  - Dosage: ${medDoc['dosage'] ?? 'Not specified'}

  ${medicineInfo != null ? _formatMedicineInfo(medicineInfo) : 'No additional medicine information available'}
''';
      }
    } else {
      medicineDetails += "No medicines assigned.\n";
    }
  } catch (e) {
    print("Error fetching medicine details: $e");
    medicineDetails += "Error retrieving medicine information.\n";
  }
  return medicineDetails;
}


  // Fetch details for connected users
  Future<String> _fetchConnectedUsersDetails(DocumentSnapshot userSnapshot) async {
    String connectedUserDetails = '';
    
    // Process Senior IDs
    List<dynamic> seniorIDs = userSnapshot['seniorIDs'] ?? [];
    List<dynamic> guardianIDs = userSnapshot['guardianIDs'] ?? [];
    
    if (seniorIDs.isNotEmpty || guardianIDs.isNotEmpty) {
      connectedUserDetails += "\nConnected Users:\n";
      
      // Process Senior IDs
      for (var seniorRef in seniorIDs) {
        if (seniorRef != "") {
          String seniorID = (seniorRef as DocumentReference).id;
          connectedUserDetails += await _getFullConnectedUserDetails(seniorID, 'Senior');
        }
      }
      
      // Process Guardian IDs
      for (var guardianRef in guardianIDs) {
        if (guardianRef != "") {
          String guardianID = (guardianRef as DocumentReference).id;
          connectedUserDetails += await _getFullConnectedUserDetails(guardianID, 'Guardian');
        }
      }
    }
    
    return connectedUserDetails;
  }

  // Get full details for a connected user
  Future<String> _getFullConnectedUserDetails(String userID, String userType) async {
    String details = '';
    try {
      DocumentSnapshot connectedUserSnapshot = await _firestore
          .collection('User')
          .doc(userID)
          .get();

      if (connectedUserSnapshot.exists) {
        details += '''
$userType Details:
- Name: ${connectedUserSnapshot['name'] ?? 'Unknown'}
- Email: ${connectedUserSnapshot['email'] ?? 'Not provided'}
- Phone: ${connectedUserSnapshot['phoneNo'] ?? 'Not provided'}
''';
        // Add medicines for connected user
        details += await _fetchUserMedicineDetails(userID);

        details += await fetchReminderDetails(userID);
      }
    } catch (e) {
      print("Error fetching connected user details: $e");
    }
    return details;
  }

  // Get medicine information from database or hardcoded source
  Map<String, dynamic>? _getMedicineInformation(String medicineName) {
    // Normalize medicine name for lookup
    medicineName = medicineName.toLowerCase().trim();
    
    // Check in hardcoded database
    return _medicineDatabase[medicineName];
  }

  // Format medicine information
  String _formatMedicineInfo(Map<String, dynamic> medicineInfo) {
    return '''
  Additional Medicine Information:
  - Generic Name: ${medicineInfo['generic_name'] ?? 'Not available'}
  
  Usage:
  ${medicineInfo['usage'] ?? 'No usage information available'}
  
  Potential Side Effects:
  ${(medicineInfo['side_effects'] as List?)?.map((effect) => '  - $effect').join('\n') ?? 'No side effects information available'}
  
  Warnings:
  ${(medicineInfo['warnings'] as List?)?.map((warning) => '  - $warning').join('\n') ?? 'No specific warnings available'}
''';
  }

  Future<String> fetchReminderDetails(String userID) async {
  String reminderDetails = '';
  try {
    // Fetch reminders for the specific user
    QuerySnapshot reminderSnapshot = await _firestore
        .collection('Reminder')
        .where('userID', isEqualTo: userID)
        .get();

        print("Reminders fetched: ${reminderSnapshot.docs.length}");

    if (reminderSnapshot.docs.isNotEmpty) {
      reminderDetails += "Reminder Details:\n";
      for (var reminderDoc in reminderSnapshot.docs) {
        reminderDetails += '''
- Medicine Name: ${reminderDoc['name'] ?? 'Unknown'}
- Dose: ${reminderDoc['dose'] ?? 'Not specified'}
- Meal Timing: ${reminderDoc['mealTiming'] ?? 'Not specified'}
- Status: ${reminderDoc['status'] ?? 'Unknown'}
- Reminder Time: ${_formatReminderTimes(reminderDoc['times'])}
''';
      }
    } else {
      reminderDetails = "No reminders found for the user.";
    }
  } catch (e) {
    print("Error fetching reminder details: $e");
    reminderDetails = "Error retrieving reminder information.";
  }
  return reminderDetails;
}

  // Format reminder times
String _formatReminderTimes(dynamic times) {
  if (times is Timestamp) {
    // Single Timestamp case
    return times.toDate().toString();
  } else if (times is List<dynamic>) {
    // List of Timestamps case
    return times
        .map((time) => (time as Timestamp).toDate().toString())
        .join(', ');
  } else {
    // Fallback for unexpected types or null values
    return "No valid times available";
  }
}

// Future<String> handleAddReminderRequest(String userMessage, BuildContext? context) async {
//   String response = "";

//   try {
//     List<String> keywords = ["set reminder", "add reminder", "make reminder"];
//     bool containsKeyword = keywords.any((keyword) => userMessage.toLowerCase().contains(keyword));

//     if (containsKeyword) {
//       final nameMatch = RegExp(r"(?:for|to)\s+(.+?)(?:\s+to|\s*$)", caseSensitive: false).firstMatch(userMessage);
//       final name = nameMatch?.group(1)?.trim();

//       if (name != null) {
//         // Query user by name to get the userID
//         QuerySnapshot userSnapshot = await FirebaseFirestore.instance
//             .collection('User')
//             .where('name', isEqualTo: name.toLowerCase())
//             .get();

//         if (userSnapshot.docs.isNotEmpty) {
//           final userID = userSnapshot.docs.first.id;

//           // Enhanced context and ScaffoldMessenger check
//             if (context != null) {
//               ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(
//                   content: Text("Would you like to add a reminder for $name?"),
//                   action: SnackBarAction(
//                     label: "Add Reminder",
//                     onPressed: () {
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (context) => HelpAddReminderScreen(
//                             userID: userID,
//                             name: name,
//                           ),
//                         ),
//                       );
//                     },
//                   ),
//                   duration: Duration(seconds: 10),
//                 ),
//               );
//             } else {
//               print("Context is null.");
//             }


//           response = "Tap 'Add Reminder' to set a reminder for $name.";
//         } else {
//           response = "No user found with the name $name.";
//         }
//       } else {
//         response = "Could not extract a name from the request.";
//       }
//     } else {
//       response = "Could not understand your request. Please include keywords like 'set reminder', 'add reminder', or 'make reminder'.";
//     }
//   } catch (e) {
//     print("Error handling reminder request: $e");
//     response = "An error occurred while processing the request.";
//   }

//   return response;
// }

Future<String?> getCurrentUserID() async {
  User? user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    return user.uid;  // Returns the current user's UID
  } else {
    return null;  // If no user is logged in
  }
}

Future<String> handleAddReminderRequest(String userMessage, BuildContext context, String currentUserID) async {
  String response = "";
  List<String> _seniorNames = [];  // To store senior names

  try {
    if (currentUserID == null) {
      response = "No user is currently logged in.";
      return response;
    }

    // Keywords to detect reminder requests
    List<String> keywords = ["set reminder", "add reminder", "make reminder"];

    // Check if the message contains any of the keywords
    bool containsKeyword = keywords.any((keyword) => userMessage.toLowerCase().contains(keyword));

    if (containsKeyword) {
      // Extract necessary details from the user message dynamically
      final nameMatch = RegExp(r"(?:for|to)\s+(.+?)(?:\s*(?:to|$))", caseSensitive: false).firstMatch(userMessage);
      final medicineMatch = RegExp(r"(?:eat|take)\s+(.+?)(?=\s*(?:at|dose|$))", caseSensitive: false).firstMatch(userMessage);
      final dateTimeMatch = RegExp(r"at\s+(.+?)(?=\s*(?:dose|before meals|after meals|$))", caseSensitive: false).firstMatch(userMessage);
      final doseMatch = RegExp(r"dose\s+(\d+.*?)\s*(?=\s*(?:after meals|before meals|$))", caseSensitive: false).firstMatch(userMessage);
      final mealTiming = userMessage.toLowerCase().contains('after meals') 
          ? 'After meal' 
          : (userMessage.toLowerCase().contains('before meals') ? 'Before meal' : null);

      final name = nameMatch?.group(1)?.trim().toLowerCase();
      final medicine = medicineMatch?.group(1)?.trim();
      final dateTimeInput = dateTimeMatch?.group(1)?.trim();
      final dose = doseMatch?.group(1)?.trim();

      if (name != null) {
        // Query user by userID to get the user document
        DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('User')
          .doc(currentUserID)
          .get();

        if (userSnapshot.exists) {
          // Retrieve senior references (IDs) from the user document
          final seniorReferences = List<DocumentReference>.from(userSnapshot['seniorIDs']);

          // Fetch senior names using senior references
          for (DocumentReference seniorRef in seniorReferences) {
            DocumentSnapshot seniorSnapshot = await seniorRef.get(); // Get the senior document using the reference

            if (seniorSnapshot.exists) {
              String seniorName = seniorSnapshot['name'].toString().toLowerCase();
              _seniorNames.add(seniorName);

              // If the name matches a senior name, display the SnackBar and capture the userID
              if (seniorName == name.toLowerCase()) {
                final userID = seniorRef.id;  // Use seniorRef.id to get the userID

                // ScaffoldMessenger.of(context).showSnackBar(
                //   SnackBar(content: Text("User found: $seniorName")),
                // );

                // Proceed to show the reminder details if a valid userID is found
                final displayMedicine = medicine ?? "";
                final displayDose = dose ?? "";
                final displayMealTiming = mealTiming ?? "Before meal";
                DateTime? reminderDateTime;

                if (dateTimeInput != null) {
                  try {
                    reminderDateTime = DateFormat("yyyy-MM-dd HH:mm").parse(dateTimeInput);
                  } catch (_) {
                    reminderDateTime = null; // Fallback if parsing fails
                  }
                }

                // Display the SnackBar with available information
                if (context != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        "Would you like to add a reminder?\n"
                        "Name: $name\n"
                        "Medicine: $displayMedicine\n"
                        "Dose: $displayDose\n"
                        "Meal Timing: $displayMealTiming\n"
                        "Date/Time: ${reminderDateTime != null ? reminderDateTime.toString() : "Not specified"}",
                      ),
                      action: SnackBarAction(
                        label: "Add Reminder",
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HelpAddReminderScreen(
                                userID: userID, // Pass the correct userID
                                name: name,
                                medicine: displayMedicine,
                                dose: displayDose,
                                dateTime: reminderDateTime?.toIso8601String(), // Handle null date
                                mealTiming: displayMealTiming,
                              ),
                            ),
                          );
                        },
                      ),
                      duration: const Duration(seconds: 10),
                    ),
                  );
                }

                response = "Reminder detected. SnackBar displayed.";
                break;  // Stop the loop after finding the first match
              }
            }
          }

          // If no matching senior found, provide feedback
          if (!_seniorNames.contains(name.toLowerCase())) {
            response = "No senior found with the name: $name. Please check the name or try again.";
          }
        } else {
          response = "No user found with the userID: $currentUserID";
        }
      } else {
        response = "Could not extract the name from your request.";
      }
    } else {
      response = "Could not understand your request. Please include keywords like 'set reminder', 'add reminder', or 'make reminder'.";
    }
  } catch (e) {
    print("Error handling reminder request: $e");
    response = "An error occurred while processing the request.";
  }

  return response;
}


  // Prepare prompt for AI with comprehensive user and medicine information
  Future<String> preparePromptForCloudflare(String userMessage, String userID) async {
    String userDetails = await fetchUserData(userID);

    String fullPrompt = """
Contextual Information for AI Assistant:

$userDetails

Comprehensive Medicine Information Database:
${_formatCompleteMedicineDatabase()}

User Query: $userMessage

AI Interaction Guidelines:
1. Use the above contextual information to provide personalized and accurate responses.
2. Reference specific user, medicine, and reminder details when relevant.
3. For queries about medicines not in the user's profile, use the comprehensive medicine database.
4. Provide detailed information about medicine usage, side effects, and warnings.
5. If any requested information is not available, clearly explain the limitations.
6. Ensure privacy and confidentiality while providing information.
7. If the user asks to set a reminder, invoke the handleAddReminderRequest process to guide them through adding a new reminder.

Please provide a helpful and contextually relevant response.
""";

    return fullPrompt;
  }

  // Format complete medicine database for prompt
  String _formatCompleteMedicineDatabase() {
    StringBuffer medicineInfo = StringBuffer();
    _medicineDatabase.forEach((name, details) {
      medicineInfo.write('''
Medicine: $name
- Generic Name: ${details['generic_name']}
- Usage: ${details['usage']}
- Side Effects: ${(details['side_effects'] as List).join(', ')}
- Warnings: ${(details['warnings'] as List).join(', ')}

''');
    });
    return medicineInfo.toString();
  }
}