import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:medicine_assistant_app/class/user.dart';
import 'package:medicine_assistant_app/page/login.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart' as f_User;

class ProfilePage extends StatefulWidget {
  final String userID;

  const ProfilePage({Key? key, required this.userID}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  
  bool _isEditing = false;
  bool _isScanning = false;
  bool _isSeniorMode = false;
  String? _scannedCode;

  User? _currentUser;
  String? _currentAvatarUrl;
  
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _emergencyContactController;
  late TextEditingController _passwordController;
  
  List<User> _connectedGuardians = [];
  List<User> _connectedSeniors = [];

  // Add these controllers at the top of _ProfilePageState
  late TextEditingController _oldPasswordController;
  late TextEditingController _newPasswordController;

  User? _priorityGuardian;
  List<User> _otherGuardians = [];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadUserData();
  }

  void _initializeControllers() {
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _emergencyContactController = TextEditingController();

    _oldPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
  }

  // Add phone formatting helpers
  String formatPhoneNumberForDisplay(String phone) {
    // Remove any non-digit characters and '60' prefix if present
    String digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.startsWith('60')) {
      digits = digits.substring(2);
    }
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    
    // Format the phone number with dashes
    String formatted = digits;
    if (digits.length == 10) {
    // Format for numbers like 11 1229 3796
    formatted = '${digits.substring(0, 2)} ${digits.substring(2, 6)} ${digits.substring(6)}';
    } else if (digits.length == 9) {
      // Format for numbers like 16 294 2336
      formatted = '${digits.substring(0, 2)} ${digits.substring(2, 5)} ${digits.substring(5)}';
    } else if (digits.length > 6) {
      // Generic format for numbers with more than 6 digits
      formatted = '${digits.substring(0, 3)}-${digits.substring(3, 6)}-${digits.substring(6)}';
    } else if (digits.length > 3) {
      // Generic format for numbers with 4 to 6 digits
      formatted = '${digits.substring(0, 3)}-${digits.substring(3)}';
    }
    
    return formatted;
  }

  String formatPhoneNumberForStorage(String phone) {
    // Remove any non-digit characters
    String digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // Remove leading 0 if present
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    
    // Add '60' prefix if not present
    if (!digits.startsWith('60')) {
      digits = '60$digits';
    }
    
    return digits;
  }

  Future<void> _loadUserData() async {
    try {
      final userDoc = await _firestore.collection('User').doc(widget.userID).get();
      if (userDoc.exists) {
        setState(() {
          _currentUser = User.fromJson(userDoc.data() as Map<String, dynamic>);
          _currentAvatarUrl = _currentUser?.avatar;

          // Update controllers with the latest data
          _nameController.text = _currentUser?.name ?? '';
          _emailController.text = _currentUser?.email ?? '';
          _phoneController.text = formatPhoneNumberForDisplay(_currentUser?.phoneNo ?? '');
          _emergencyContactController.text = formatPhoneNumberForDisplay(_currentUser?.emergencyContact ?? '');
        });

        _loadConnectedUsers();
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  // Future<void> _loadConnectedUsers() async {
  //   if (_currentUser == null) return;

  //   try {
  //     // Load Guardians
  //     List<User> guardians = [];
  //     for (String guardianPath in _currentUser!.guardianIDs) {
  //       String guardianId = guardianPath.split('/').last;
  //       final guardianDoc = await _firestore.collection('User').doc(guardianId).get();
  //       if (guardianDoc.exists) {
  //         guardians.add(User.fromJson(guardianDoc.data() as Map<String, dynamic>));
  //       }
  //     }

  //     // Load Seniors
  //     List<User> seniors = [];
  //     for (String seniorPath in _currentUser!.seniorIDs) {
  //       String seniorId = seniorPath.split('/').last;
  //       final seniorDoc = await _firestore.collection('User').doc(seniorId).get();
  //       if (seniorDoc.exists) {
  //         seniors.add(User.fromJson(seniorDoc.data() as Map<String, dynamic>));
  //       }
  //     }

  //     setState(() {
  //       _connectedGuardians = guardians;
  //       _connectedSeniors = seniors;
  //     });
  //   } catch (e) {
  //     print('Error loading connected users: $e');
  //   }
  // }

  Future<void> _loadConnectedUsers() async {
  if (_currentUser == null) return;

  try {
    // Get the priorityGuardian path from the current user's document
    final userDoc = await _firestore.collection('User').doc(widget.userID).get();
    final userData = userDoc.data() as Map<String, dynamic>;
    final String? priorityGuardianPath = userData['priorityGuardian'] as String?;

    // Load Guardians
    List<User> guardians = [];
    User? priorityGuardian;
    
    for (String guardianPath in _currentUser!.guardianIDs) {
      String guardianId = guardianPath.split('/').last;
      final guardianDoc = await _firestore.collection('User').doc(guardianId).get();
      
      if (guardianDoc.exists) {
        User guardian = User.fromJson(guardianDoc.data() as Map<String, dynamic>);
        guardians.add(guardian);
        
        // Check if this guardian is the priority guardian
        if (priorityGuardianPath != null && guardianPath == priorityGuardianPath) {
          priorityGuardian = guardian;
        }
      }
    }

    // Separate other guardians (excluding priority guardian)
    List<User> others = guardians
        .where((g) => g.userID != priorityGuardian?.userID)
        .toList();

    // Load Seniors
    List<User> seniors = [];
    for (String seniorPath in _currentUser!.seniorIDs) {
      String seniorId = seniorPath.split('/').last;
      final seniorDoc = await _firestore.collection('User').doc(seniorId).get();
      if (seniorDoc.exists) {
        seniors.add(User.fromJson(seniorDoc.data() as Map<String, dynamic>));
      }
    }

    setState(() {
      _priorityGuardian = priorityGuardian;
      _otherGuardians = others;
      _connectedGuardians = guardians;
      _connectedSeniors = seniors;
    });
  } catch (e) {
    print('Error loading connected users: $e');
  }
}

  Future _dropPriorityGuardian() async {
  try {
    if (_priorityGuardian == null) return;

    // Remove priority guardian from Firestore
    await _firestore.collection('User').doc(widget.userID).update({
      'priorityGuardian': FieldValue.delete(), // Remove the priorityGuardian field
    });

    setState(() {
      if (_priorityGuardian != null) {
        _otherGuardians.add(_priorityGuardian!);
        _otherGuardians.sort((a, b) => a.name.compareTo(b.name)); // Optional: sort by name
        _priorityGuardian = null;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Priority guardian removed successfully')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error removing priority guardian: $e')),
    );
  }
}

Future _setPriorityGuardian(User guardian) async {
  try {
    // Check if the user is a senior
    if (_connectedSeniors.any((senior) => senior.userID == guardian.userID)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connected seniors cannot be set as priority guardians')),
      );
      return;
    }

    // Update the priorityGuardian field in Firestore
    await _firestore.collection('User').doc(widget.userID).update({
      'priorityGuardian': '/User/${guardian.userID}', // Set the priority guardian
    });

    setState(() {
      _priorityGuardian = guardian;
      _otherGuardians = _connectedGuardians
          .where((g) => g.userID != guardian.userID)
          .toList();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Priority guardian updated successfully')),
    );

    await _loadConnectedUsers();
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error updating priority guardian: $e')),
    );
  }
}


Future<void> _updateProfile() async {
    try {
          // Format phone numbers for storage
      final String formattedPhone = formatPhoneNumberForStorage(_phoneController.text);
      final String formattedEmergency = formatPhoneNumberForStorage(_emergencyContactController.text);
      await _firestore.collection('User').doc(widget.userID).update({
        'name': _nameController.text,
        'email': _emailController.text,
        'phoneNo': formattedPhone,
        'emergencyContact': formattedEmergency,
        'avatar': _currentAvatarUrl,
      });

      setState(() {
        _isEditing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile updated successfully')),
      );

      await _loadUserData(); // Reload data after updating
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: $e')),
      );
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      final File imageFile = File(image.path);
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = _storage.ref().child('profile_images/$fileName');

      await storageRef.putFile(imageFile);
      final String downloadUrl = await storageRef.getDownloadURL();

      setState(() {
        _currentAvatarUrl = downloadUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile image updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile image: $e')),
      );
    }
  }

 @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
                title: const Text(
                  'Profile',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  ),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: () {
              if (_isEditing) {
                _updateProfile();
              } else {
                setState(() {
                  _isEditing = true;
                });
              }
            },
          ),
          IconButton(
  icon: Icon(Icons.logout),
  onPressed: () async {
    try {
      // Clear all stored login states
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('userID');
      await prefs.remove('keepSignedIn');
      await prefs.remove('faceLoginUserID');
      await prefs.remove('keepSignedInFace');

      // Navigate to login page and clear navigation stack
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginPage()),
        (route) => false,
      );
    } catch (e) {
      // Show error if clearing preferences fails
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error logging out: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  },
)
        ],
      ),
      body: _currentUser == null
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Profile Image and Details
                  _buildProfileHeader(),

                  // Profile Information Form
                  _buildProfileForm(),

                  // QR Code Connection Section
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              icon: Icon(Icons.qr_code_scanner),
                              label: Text('Guardian Mode'),
                              onPressed: _toggleGuardianMode,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isScanning 
                                    ? Colors.red  // Changed from Theme.of(context).primaryColor
                                    : null,
                              ),
                            ),
                            ElevatedButton.icon(
                              icon: Icon(Icons.qr_code),
                              label: Text('Senior Mode'),
                              onPressed: _toggleSeniorMode,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isSeniorMode 
                                    ? Colors.red  // Changed from Theme.of(context).primaryColor
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        _buildQRContent(),
                      ],
                    ),
                  ),

                  // Connected Users
                  _buildConnectedUsersSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: GestureDetector(
        onTap: _isEditing ? _pickAndUploadImage : null,
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage: _currentAvatarUrl?.isNotEmpty == true
                  ? NetworkImage(_currentAvatarUrl!)
                  : null,
              child: _currentAvatarUrl?.isEmpty ?? true
                  ? Text(_currentUser?.name[0].toUpperCase() ?? '',
                      style: TextStyle(fontSize: 36))
                  : null,
            ),
            if (_isEditing)
              Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.camera_alt, color: Colors.white, size: 20),
              ),
          ],
        ),
      ),
    );
  }

  // Add password validation method
String? validatePassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Please enter your password';
  }
  if (value.length < 8) {
    return 'Password must be at least 8 characters long';
  }
  if (!value.contains(RegExp(r'[A-Z]'))) {
    return 'Password must contain at least 1 uppercase letter';
  }
  if (!value.contains(RegExp(r'[a-z]'))) {
    return 'Password must contain at least 1 lowercase letter';
  }
  if (!value.contains(RegExp(r'[0-9]'))) {
    return 'Password must contain at least 1 number';
  }
  if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
    return 'Password must contain at least 1 special character';
  }
  return null;
}

// Add password change method
Future<void> _changePassword() async {
  // Validate new password
  String? validationError = validatePassword(_newPasswordController.text);
  if (validationError != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(validationError), backgroundColor: Colors.red),
    );
    return;
  }

  try {
    // Get current user
    f_User.User? currentUser = f_User.FirebaseAuth.instance.currentUser;
    
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No user currently signed in'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Get user email from Firestore since we need it for reauthentication
    DocumentSnapshot userDoc = await _firestore.collection('User').doc(widget.userID).get();
    String userEmail = (userDoc.data() as Map<String, dynamic>)['email'] as String;

    // Create credentials for reauthentication
    f_User.AuthCredential credential = f_User.EmailAuthProvider.credential(
      email: userEmail,
      password: _oldPasswordController.text,
    );

    try {
      // Reauthenticate user
      await currentUser.reauthenticateWithCredential(credential);
      
      // If reauthentication successful, update password
      await currentUser.updatePassword(_newPasswordController.text);

      // Clear controllers
      _oldPasswordController.clear();
      _newPasswordController.clear();

      // Close the dialog only if the widget is still mounted
      if (mounted) {
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password changed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on f_User.FirebaseAuthException catch (e) {
      String errorMessage = 'An error occurred';
      
      switch (e.code) {
        case 'wrong-password':
          errorMessage = 'Current password is incorrect';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many attempts. Please try again later';
          break;
        case 'requires-recent-login':
          errorMessage = 'Please log in again and retry';
          break;
        default:
          errorMessage = e.message ?? 'An error occurred';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error changing password: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// Add show password dialog method
void _showChangePasswordDialog() {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Change Password'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _oldPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                  helperText: 'Password must contain at least:\n'
                      '- 8 characters\n'
                      '- 1 uppercase letter\n'
                      '- 1 lowercase letter\n'
                      '- 1 number\n'
                      '- 1 special character',
                  helperMaxLines: 6,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _oldPasswordController.clear();
              _newPasswordController.clear();
            },
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: _changePassword,
            child: Text('Change Password'),
          ),
        ],
      );
    },
  );
}

  Widget _buildProfileForm() {
  return Padding(
    padding: EdgeInsets.all(16),
    child: Column(
      children: [
        _buildTextField(_nameController, 'Name', Icons.person),
        _buildTextField(_emailController, 'Email', Icons.email),
        _buildTextField(_phoneController, 'Phone', Icons.phone),
        _buildTextField(_emergencyContactController, 'Emergency Contact',
            Icons.emergency),
        if (_isEditing)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: TextButton.icon(
              icon: Icon(Icons.lock),
              label: Text('Change Password'),
              onPressed: _showChangePasswordDialog,
            ),
          ),
      ],
    ),
  );
}

  // Widget _buildConnectedUsersSection() {
  //   return Padding(
  //     padding: EdgeInsets.all(16),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Text('Connected Guardians',
  //             style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
  //         SizedBox(height: 8),
  //         _buildConnectedUsersList(_connectedGuardians),
  //         SizedBox(height: 16),
  //         Text('Connected Seniors',
  //             style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
  //         SizedBox(height: 8),
  //         _buildConnectedUsersList(_connectedSeniors),
  //       ],
  //     ),
  //   );
  // }

Widget _buildConnectedUsersSection() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Connected Guardians',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          
          // Priority Guardian Section
          if (_priorityGuardian != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Priority Guardian',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).primaryColor
                    )),
                TextButton.icon(
                  icon: Icon(Icons.star_half, color: Colors.orange),
                  label: Text('Drop Priority'),
                  onPressed: _dropPriorityGuardian,
                ),
              ],
            ),
            _buildGuardianTile(_priorityGuardian!, isPriority: true),
            Divider(),
          ],
          
          // Other Guardians Section
          if (_otherGuardians.isNotEmpty) ...[
            Text('Other Guardians',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _otherGuardians.length,
              itemBuilder: (context, index) => _buildGuardianTile(_otherGuardians[index]),
            ),
          ] else if (_priorityGuardian == null && _otherGuardians.isEmpty) ...[
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No connected guardians'),
              ),
            ),
          ],
          
          SizedBox(height: 16),
          Text('Connected Seniors',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          _buildConnectedUsersList(_connectedSeniors),
        ],
      ),
    );
  }

  Widget _buildGuardianTile(User guardian, {bool isPriority = false}) {
    // Check if the user is a connected senior
    bool isConnectedSenior = _connectedSeniors.any((senior) => senior.userID == guardian.userID);

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: guardian.avatar?.isNotEmpty == true
              ? NetworkImage(guardian.avatar!)
              : null,
          child: guardian.avatar?.isEmpty ?? true
              ? Text(guardian.name[0].toUpperCase())
              : null,
        ),
        title: Text(guardian.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('60${formatPhoneNumberForDisplay(guardian.phoneNo)}'),
            if (isPriority)
              Text('Priority Guardian',
                  style: TextStyle(color: Theme.of(context).primaryColor))
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isPriority && !isConnectedSenior)
              IconButton(
                icon: Icon(Icons.star_border),
                onPressed: () => _setPriorityGuardian(guardian),
                tooltip: 'Set as Priority Guardian',
              ),
            IconButton(
              icon: Icon(Icons.remove_circle_outline, color: Colors.red),
              onPressed: () => _confirmAndRemoveConnection(guardian.userID),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQRScanner() {
    return Column(
      children: [
        ElevatedButton(
          onPressed: _startQRScanning,
          child: Text("Start Scanning"),
        ),
        SizedBox(height: 16),
        if (_scannedCode != null) 
          Text(
            'Successful Scan Code',
            style: TextStyle(fontSize: 16),
          ),
      ],
    );
  }

  Widget _buildQRContent() {
    if (_isScanning) {
      return _buildQRScanner();
    } else if (_isSeniorMode) {
      return _buildQRCode();
    } else {
      return Center(
        child: Text(
          'Select a mode to start scanning or display QR code',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 16,
          ),
        ),
      );
    }
  }

Widget _buildQRCode() {
  if (_currentUser == null) {
    return Center(
      child: Text(
        'User data is not available',
        style: TextStyle(color: Colors.grey, fontSize: 16),
      ),
    );
  }

  final qrData = jsonEncode({
    'userID': _currentUser!.userID,
    'type': 'senior',
    'name': _currentUser!.name,
  });

  return Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 2,
              blurRadius: 5,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: QrImageView(
          data: qrData,
          version: QrVersions.auto,
          size: 200.0,
          backgroundColor: Colors.white,
        ),
      ),
      SizedBox(height: 16),
      Text(
        'Show this QR code to your guardian',
        style: TextStyle(fontSize: 16),
      ),
    ],
  );
}

  void _toggleGuardianMode() {
    setState(() {
      _isScanning = !_isScanning;
      _isSeniorMode = false;
    });
  }

  void _toggleSeniorMode() {
    setState(() {
      _isSeniorMode = !_isSeniorMode;
      _isScanning = false;
    });
  }

  Future<void> _startQRScanning() async {
    String scannedCode = await FlutterBarcodeScanner.scanBarcode(
      '#ff6666',
      'Cancel',
      true,
      ScanMode.QR,
    );

    if (scannedCode != '-1') {
      setState(() {
        _scannedCode = scannedCode;
      });

      try {
        final Map<String, dynamic> qrData = jsonDecode(scannedCode);
        if (qrData['type'] == 'senior') {
          _handleSeniorScanned(qrData);
        }
      } catch (e) {
        print('Error processing QR code: $e');
      }
    }
  }

Future<void> _handleSeniorScanned(Map<String, dynamic> seniorData) async {
  if (!mounted) return;  // Add mounted check
  
  final String seniorUserID = seniorData['userID'];
  final String guardianUserID = widget.userID;
  
  // Store context before showing dialog
  final BuildContext currentContext = context;
  
  bool? shouldConnect = await showDialog<bool>(
    context: currentContext,
    builder: (BuildContext context) => AlertDialog(
      title: Text('Connect with Senior'),
      content: Text('Do you want to connect with ${seniorData['name']}?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('Connect'),
        ),
      ],
    ),
  );

  // Check if widget is still mounted before proceeding
  if (!mounted) return;

  if (shouldConnect == true) {
    try {
      await _updateConnection(seniorUserID, guardianUserID);
      if (!mounted) return;  // Check mounted again after async operation
      
      await _loadConnectedUsers();
      if (!mounted) return;  // Check mounted after another async operation
      
      ScaffoldMessenger.of(currentContext).showSnackBar(
        SnackBar(
          content: Text('Successfully connected with ${seniorData['name']}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error in _handleSeniorScanned: $e');
      if (!mounted) return;
      
      ScaffoldMessenger.of(currentContext).showSnackBar(
        SnackBar(
          content: Text('Error connecting: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

Future<void> _confirmAndRemoveConnection(String connectedUserId) async {
  if (!mounted) return;  // Add mounted check
  
  // Store context before showing dialog
  final BuildContext currentContext = context;
  
  bool? confirm = await showDialog<bool>(
    context: currentContext,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Confirm Removal'),
        content: Text('Are you sure you want to remove this connection?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Remove'),
          ),
        ],
      );
    },
  );

  if (!mounted) return;  // Check mounted before proceeding

  if (confirm == true) {
    await _removeConnection(connectedUserId);
  }
}

Future<void> _removeConnection(String connectedUserId) async {
  if (!mounted) return;  // Add mounted check
  
  try {
    await _firestore.collection('User').doc(widget.userID).update({
      'guardianIDs': FieldValue.arrayRemove(['/User/$connectedUserId']),
      'seniorIDs': FieldValue.arrayRemove(['/User/$connectedUserId']),
    });

    await _firestore.collection('User').doc(connectedUserId).update({
      'guardianIDs': FieldValue.arrayRemove(['/User/${widget.userID}']),
      'seniorIDs': FieldValue.arrayRemove(['/User/${widget.userID}']),
    });

    if (!mounted) return;  // Check mounted after async operations

    setState(() {
      _connectedGuardians.removeWhere((user) => user.userID == connectedUserId);
      _connectedSeniors.removeWhere((user) => user.userID == connectedUserId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Connection removed successfully')),
    );
  } catch (e) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error removing connection: $e')),
    );
  }
}

Future<void> _updateConnection(String seniorUserID, String guardianUserID) async {
  // Update senior's document
  await _firestore.collection('User').doc(seniorUserID).set({
    'guardianIDs': FieldValue.arrayUnion(['/User/$guardianUserID']),
  }, SetOptions(merge: true));

  // Update guardian's document
  await _firestore.collection('User').doc(guardianUserID).set({
    'seniorIDs': FieldValue.arrayUnion(['/User/$seniorUserID']),
  }, SetOptions(merge: true));

  // Refresh the lists immediately after updating the connection
  await _loadConnectedUsers();
}

  Widget _buildTextField(TextEditingController controller, String label,
      IconData icon, {bool isPassword = false}) {
    bool isPhoneField = label == 'Phone' || label == 'Emergency Contact';
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        enabled: _isEditing,
        obscureText: isPassword,
        keyboardType: isPhoneField ? TextInputType.phone : TextInputType.text,
        onChanged: isPhoneField ? (value) {
          final formatted = formatPhoneNumberForDisplay(value);
          controller.value = TextEditingValue(
            text: formatted,
            selection: TextSelection.collapsed(offset: formatted.length),
          );
        } : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          prefixText: isPhoneField ? '+60 ' : null,
          border: const OutlineInputBorder(),
          enabled: _isEditing,
          hintText: isPhoneField ? 'Enter phone number without country code' : null,
        ),
      ),
    );
  }

  Widget _buildConnectedUsersList(List<User> users) {
    if (users.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No connected users'),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage:
                  user.avatar?.isNotEmpty == true ? NetworkImage(user.avatar!) : null,
              child: user.avatar?.isEmpty ?? true
                  ? Text(user.name[0].toUpperCase())
                  : null,
            ),
            title: Text(user.name),
            subtitle: Text('60${formatPhoneNumberForDisplay(user.phoneNo)}'),
            trailing: IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
              onPressed: () => _confirmAndRemoveConnection(user.userID),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _emergencyContactController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }
}