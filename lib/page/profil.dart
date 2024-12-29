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
    _passwordController = TextEditingController();
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
          _phoneController.text = _currentUser?.phoneNo ?? '';
          _emergencyContactController.text = _currentUser?.emergencyContact ?? '';
        });

        _loadConnectedUsers();
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _loadConnectedUsers() async {
    if (_currentUser == null) return;

    try {
      // Load Guardians
      List<User> guardians = [];
      for (String guardianPath in _currentUser!.guardianIDs) {
        String guardianId = guardianPath.split('/').last;
        final guardianDoc = await _firestore.collection('User').doc(guardianId).get();
        if (guardianDoc.exists) {
          guardians.add(User.fromJson(guardianDoc.data() as Map<String, dynamic>));
        }
      }

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
        _connectedGuardians = guardians;
        _connectedSeniors = seniors;
      });
    } catch (e) {
      print('Error loading connected users: $e');
    }
  }

Future<void> _updateProfile() async {
    try {
      await _firestore.collection('User').doc(widget.userID).update({
        'name': _nameController.text,
        'email': _emailController.text,
        'phoneNo': _phoneController.text,
        'emergencyContact': _emergencyContactController.text,
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
        title: Text('Profile'),
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
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => LoginPage()),
                (route) => false,
              );
            },
          ),
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
            _buildTextField(_passwordController, 'New Password',
                Icons.lock, isPassword: true),
        ],
      ),
    );
  }

  Widget _buildConnectedUsersSection() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Connected Guardians',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          _buildConnectedUsersList(_connectedGuardians),
          SizedBox(height: 16),
          Text('Connected Seniors',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          _buildConnectedUsersList(_connectedSeniors),
        ],
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
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        enabled: _isEditing,
        obscureText: isPassword,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(),
          enabled: _isEditing,
        ),
      ),
    );
  }

  Widget _buildConnectedUsersList(List<User> users) {
    if (users.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No connected users'),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
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
            subtitle: Text(user.phoneNo),
            trailing: IconButton(
              icon: Icon(Icons.remove_circle_outline, color: Colors.red),
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
    _passwordController.dispose();
    super.dispose();
  }
}