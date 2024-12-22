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
      'dosage': {
        'adults': '500-1000 mg every 4-6 hours as needed (maximum 4000 mg per day)',
        'children': 'Based on age and weight - consult healthcare provider',
        'form': ['Tablets', 'Capsules', 'Liquid', 'Suppositories']
      },
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
      ],
      'contraindications': [
        'Liver disease',
        'Heavy alcohol use',
        'Allergic to acetaminophen'
      ],
      'storage': 'Store at room temperature away from moisture and heat',
      'pregnancy_category': 'Generally considered safe during pregnancy when used as directed'
    },
    'ibuprofen': {
      'generic_name': 'Ibuprofen',
      'usage': 'A nonsteroidal anti-inflammatory drug (NSAID) used to reduce pain, fever, and inflammation. Commonly used for headaches, muscle aches, arthritis, menstrual cramps, and minor injuries.',
      'dosage': {
        'adults': '200-400 mg every 4-6 hours as needed (maximum 1200 mg per day)',
        'children': 'Based on age and weight - consult healthcare provider',
        'form': ['Tablets', 'Capsules', 'Liquid', 'Gel']
      },
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
      ],
      'contraindications': [
        'Heart disease',
        'History of stomach ulcers',
        'Third trimester of pregnancy',
        'Aspirin-sensitive asthma'
      ],
      'storage': 'Store at room temperature away from moisture',
      'pregnancy_category': 'Avoid during third trimester of pregnancy'
    }
  };

  // Fetch comprehensive user data including connected users and reminders
Future<String> fetchUserData(String targetUserID) async {
    String details = '';
    try {
      DocumentSnapshot userSnapshot = await _firestore
          .collection('User')
          .doc(targetUserID)
          .get();

      if (userSnapshot.exists) {
        Map<String, dynamic> userData = userSnapshot.data() as Map<String, dynamic>;
        
        details += '''
User Profile:
- Name: ${userData['name'] ?? 'Unknown'}
- Email: ${userData['email'] ?? 'Not provided'}
- Phone: ${userData['phoneNo'] ?? 'Not provided'}
- Emergency Contact: ${userData['emergencyContact'] ?? 'Not set'}
''';

        details += await _fetchUserMedicineDetails(targetUserID);
        String reminderDetails = await fetchReminderDetails(targetUserID);
        details += reminderDetails.isNotEmpty ? reminderDetails : "No reminders set.\n";
        details += await _fetchConnectedUsersDetails(userData);
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
      // Create a proper DocumentReference for the user
      DocumentReference userRef = _firestore.collection('User').doc(userID);
      
      // Query medicines using the DocumentReference
      QuerySnapshot medicineSnapshot = await _firestore
          .collection('Medicine')
          .where('seniorID', isEqualTo: userRef)
          .get();

      if (medicineSnapshot.docs.isNotEmpty) {
        medicineDetails += "Medicines:\n";
        for (var medDoc in medicineSnapshot.docs) {
          Map<String, dynamic> medicineData = medDoc.data() as Map<String, dynamic>;
          String medicineName = medicineData['name']?.toLowerCase() ?? 'unknown';
          
          Map<String, dynamic>? medicineInfo = _getMedicineInformation(medicineName);

          medicineDetails += '''
  Medicine:
  - Name: ${medicineData['name'] ?? 'Unknown'}
  - Dosage: ${medicineData['dosage'] ?? 'Not specified'}

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

  Future<String> _fetchConnectedUsersDetails(Map<String, dynamic> userData) async {
    String connectedUserDetails = '';
    
    try {
      var seniorIDs = userData['seniorIDs'] ?? [];
      var guardianIDs = userData['guardianIDs'] ?? [];
      
      if (seniorIDs.isNotEmpty || guardianIDs.isNotEmpty) {
        connectedUserDetails += "\nConnected Users:\n";
        
        // Process Senior IDs
        for (var seniorRef in seniorIDs) {
          if (seniorRef is DocumentReference) {
            String seniorID = seniorRef.id;
            connectedUserDetails += await _getFullConnectedUserDetails(seniorID, 'Senior');
          } else if (seniorRef is String && seniorRef.startsWith('/User/')) {
            // Handle string path reference
            String seniorID = seniorRef.split('/').last;
            connectedUserDetails += await _getFullConnectedUserDetails(seniorID, 'Senior');
          }
        }
        
        // Process Guardian IDs
        for (var guardianRef in guardianIDs) {
          if (guardianRef is DocumentReference) {
            String guardianID = guardianRef.id;
            connectedUserDetails += await _getFullConnectedUserDetails(guardianID, 'Guardian');
          } else if (guardianRef is String && guardianRef.startsWith('/User/')) {
            // Handle string path reference
            String guardianID = guardianRef.split('/').last;
            connectedUserDetails += await _getFullConnectedUserDetails(guardianID, 'Guardian');
          }
        }
      }
    } catch (e) {
      print("Error in _fetchConnectedUsersDetails: $e");
      connectedUserDetails += "Error retrieving connected users.\n";
    }
    
    return connectedUserDetails;
  }

  Future<String> _getFullConnectedUserDetails(String userID, String userType) async {
    String details = '';
    try {
      DocumentSnapshot connectedUserSnapshot = await _firestore
          .collection('User')
          .doc(userID)
          .get();

      if (connectedUserSnapshot.exists) {
        Map<String, dynamic> userData = connectedUserSnapshot.data() as Map<String, dynamic>;
        details += '''
$userType Details:
- Name: ${userData['name'] ?? 'Unknown'}
- Email: ${userData['email'] ?? 'Not provided'}
- Phone: ${userData['phoneNo'] ?? 'Not provided'}
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

    List<String> keywords = ["set reminder", "add reminder", "make reminder"];
    bool containsKeyword = keywords.any((keyword) => userMessage.toLowerCase().contains(keyword));

    if (containsKeyword) {
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
        DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('User')
          .doc(currentUserID)
          .get();

        if (userSnapshot.exists) {
          // Get the senior IDs from the user document
          final userData = userSnapshot.data() as Map<String, dynamic>;
          final seniorIDs = userData['seniorIDs'] as List<dynamic>;

          // Process each senior ID
          for (var seniorRef in seniorIDs) {
            String seniorID;
            
            // Handle different formats of senior references
            if (seniorRef is String && seniorRef.startsWith('/User/')) {
              // Handle string path format ('/User/xyz')
              seniorID = seniorRef.split('/').last;
            } else if (seniorRef is String) {
              // Handle direct ID format
              seniorID = seniorRef;
            } else {
              continue; // Skip invalid formats
            }

            // Get the senior's document
            DocumentSnapshot seniorSnapshot = await FirebaseFirestore.instance
                .collection('User')
                .doc(seniorID)
                .get();

            if (seniorSnapshot.exists) {
              String seniorName = seniorSnapshot['name'].toString().toLowerCase();
              _seniorNames.add(seniorName);

              if (seniorName == name.toLowerCase()) {
                final displayMedicine = medicine ?? "";
                final displayDose = dose ?? "";
                final displayMealTiming = mealTiming ?? "Before meal";
                DateTime? reminderDateTime;

                if (dateTimeInput != null) {
                  try {
                    reminderDateTime = DateFormat("yyyy-MM-dd HH:mm").parse(dateTimeInput);
                  } catch (_) {
                    reminderDateTime = null;
                  }
                }

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
                                userID: seniorID,
                                name: name,
                                medicine: displayMedicine,
                                dose: displayDose,
                                dateTime: reminderDateTime?.toIso8601String(),
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
                break;
              }
            }
          }

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
    
    // Extract potential medicine names from the user message
    List<String> possibleMedicines = _extractPossibleMedicineNames(userMessage);
    
    // Build medicine information based on mentioned medicines
    String medicineInfo = '';
    for (String medicine in possibleMedicines) {
      if (_medicineDatabase.containsKey(medicine.toLowerCase())) {
        medicineInfo += _formatSpecificMedicineResponse(medicine.toLowerCase(), userMessage);
      } else if (medicine.isNotEmpty) {
        medicineInfo += _provideGeneralMedicineResponse(medicine, userMessage);
      }
    }

    String fullPrompt = """
Contextual Information for AI Assistant:

$userDetails

${medicineInfo.isNotEmpty ? 'Relevant Medicine Information:\n$medicineInfo' : ''}

User Query: $userMessage

AI Interaction Guidelines:
1. Use the above contextual information to provide personalized and accurate responses.
2. Reference specific user details and any existing reminders when relevant.
3. If medicines are mentioned in the query:
   - Provide specific information for known medicines
   - Offer general guidance for unknown medicines
   - Always emphasize the importance of consulting healthcare providers
4. Respect user privacy and maintain confidentiality.
5. For reminder requests, guide users through the reminder creation process.
6. If information is unavailable, clearly explain limitations and suggest next steps.

Please provide a relevant and helpful response based on the available context.
""";

    return fullPrompt;
  }

  List<String> _extractPossibleMedicineNames(String message) {
    Set<String> medicines = {};
    
    // Convert message to lowercase for case-insensitive matching
    String normalizedMessage = message.toLowerCase();
    
    // Common keywords that might precede medicine names
    List<String> medicineKeywords = [
      'medicine',
      'medication',
      'tablet',
      'pill',
      'capsule',
      'take',
      'taking',
      'prescribed',
      'about',
      'using'
    ];

    // Split message into words
    List<String> words = normalizedMessage.split(' ');
    
    // Look for words that follow medicine-related keywords
    for (int i = 0; i < words.length - 1; i++) {
      if (medicineKeywords.contains(words[i])) {
        // Add the next word as a potential medicine name
        if (i + 1 < words.length) {
          medicines.add(words[i + 1]);
        }
      }
    }
    
    // Also check if any known medicine names from the database appear in the message
    for (String knownMedicine in _medicineDatabase.keys) {
      if (normalizedMessage.contains(knownMedicine)) {
        medicines.add(knownMedicine);
      }
    }
    
    return medicines.toList();
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

  String provideMedicineResponse(String query) {
    // Normalize query and extract medicine name
    String normalizedQuery = query.toLowerCase();
    String medicineName = _extractMedicineNameFromQuery(normalizedQuery);
    
    // If medicine exists in database, provide specific information
    if (_medicineDatabase.containsKey(medicineName.toLowerCase())) {
      return _formatSpecificMedicineResponse(medicineName.toLowerCase(), normalizedQuery);
    } else {
      // For unknown medicines, provide general medical guidance
      return _provideGeneralMedicineResponse(medicineName, normalizedQuery);
    }
  }

  String _extractMedicineNameFromQuery(String query) {
    // Common patterns to identify medicine names in queries
    List<String> patterns = [
      'about',
      'is',
      'are',
      'take',
      'using',
      'medicine',
      'medication'
    ];
    
    List<String> words = query.split(' ');
    for (String pattern in patterns) {
      int index = words.indexOf(pattern);
      if (index != -1 && index < words.length - 1) {
        return words[index + 1];
      }
    }
    
    // Default to first word that's not a common word
    return words.firstWhere(
      (word) => !['what', 'how', 'when', 'where', 'why', 'is', 'are', 'the', 'a', 'an'].contains(word),
      orElse: () => 'medicine'
    );
  }

  String _formatSpecificMedicineResponse(String medicineName, String query) {
    var medicine = _medicineDatabase[medicineName]!;
    
    // Check query type and provide relevant information
    if (query.contains('side effect') || query.contains('risk')) {
      return '''
${medicine['generic_name']} (${medicineName.toUpperCase()}) - Safety Information:

Side Effects:
${medicine['side_effects'].map((e) => '• $e').join('\n')}

Warnings:
${medicine['warnings'].map((e) => '• $e').join('\n')}

Contraindications:
${medicine['contraindications'].map((e) => '• $e').join('\n')}

Pregnancy Category:
${medicine['pregnancy_category']}

Please consult your healthcare provider for personalized medical advice.
''';
    } else if (query.contains('dosage') || query.contains('how to take')) {
      return '''
${medicine['generic_name']} (${medicineName.toUpperCase()}) - Dosage Information:

Adult Dosage:
${medicine['dosage']['adults']}

Available Forms:
${medicine['dosage']['form'].map((e) => '• $e').join('\n')}

Storage:
${medicine['storage']}

Note: These are general guidelines. Follow your healthcare provider's specific instructions.
''';
    } else {
      return '''
${medicine['generic_name']} (${medicineName.toUpperCase()}) - Complete Information:

Usage:
${medicine['usage']}

Dosage:
• Adults: ${medicine['dosage']['adults']}
• Forms: ${medicine['dosage']['form'].join(', ')}

Safety Information:
• Side Effects: ${medicine['side_effects'].join(', ')}
• Key Warnings: ${medicine['warnings'].join(', ')}

Storage: ${medicine['storage']}

Important: This information is for reference only. Consult your healthcare provider for personal medical advice.
''';
    }
  }

  String _provideGeneralMedicineResponse(String medicineName, String query) {
    return '''
Regarding $medicineName:

While I don't have specific information about this medication in my database, here are some general guidelines:

1. Always consult your healthcare provider or pharmacist for:
   • Proper dosage information
   • Potential side effects
   • Drug interactions
   • Usage instructions

2. General Safety Tips:
   • Follow prescribed dosage strictly
   • Complete the full course as prescribed
   • Store medications properly
   • Check expiration dates
   • Report any adverse effects to your healthcare provider

3. Important Reminders:
   • Keep a list of all your medications
   • Inform your healthcare provider about any allergies
   • Mention any other medications you're taking
   • Discuss any chronic conditions you have

For specific information about this medication, please:
1. Consult your healthcare provider
2. Read the medication package insert
3. Speak with your pharmacist

Note: This is general guidance only. Always seek professional medical advice for specific medication information.
''';
  }
}