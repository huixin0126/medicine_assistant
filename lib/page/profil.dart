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
  final User user;
  final String userID;

  const ProfilePage({Key? key, required this.userID, required this.user}) : super(key: key);

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
  
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _emergencyContactController;
  late TextEditingController _passwordController;
  
  List<User> _connectedGuardians = [];
  List<User> _connectedSeniors = [];
  String? _currentAvatarUrl;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadConnectedUsers();
    _currentAvatarUrl = widget.user.avatar;
  }

  void _initializeControllers() {
    _nameController = TextEditingController(text: widget.user.name);
    _emailController = TextEditingController(text: widget.user.email);
    _phoneController = TextEditingController(text: widget.user.phoneNo);
    _emergencyContactController = TextEditingController(text: widget.user.emergencyContact ?? '');
    _passwordController = TextEditingController();
  }

  Future<void> _loadConnectedUsers() async {
    try {
      // Load Guardians
      for (String guardianPath in widget.user.guardianIDs) {
        String guardianId = guardianPath.split('/').last;
        final guardianDoc = await _firestore.collection('User').doc(guardianId).get();
        if (guardianDoc.exists) {
          setState(() {
            _connectedGuardians.add(User.fromJson(guardianDoc.data() as Map<String, dynamic>));
          });
        }
      }

      // Load Seniors
      for (String seniorPath in widget.user.seniorIDs) {
        String seniorId = seniorPath.split('/').last;
        final seniorDoc = await _firestore.collection('User').doc(seniorId).get();
        if (seniorDoc.exists) {
          setState(() {
            _connectedSeniors.add(User.fromJson(seniorDoc.data() as Map<String, dynamic>));
          });
        }
      }
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
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Image Section
            Padding(
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
                          ? Text(widget.user.name[0].toUpperCase(),
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
            ),

            // Profile Information Form
            Padding(
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
            ),

            // Mode Selection Buttons
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.qr_code_scanner),
                      label: Text('Guardian Mode'),
                      onPressed: () => _toggleGuardianMode(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isScanning ? Colors.red : null,
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.qr_code),
                      label: Text('Senior Mode'),
                      onPressed: () => _toggleSeniorMode(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isSeniorMode ? Colors.red : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // QR Scanner or QR Code Display
            if (_isScanning || _isSeniorMode)
              Padding(
                padding: EdgeInsets.all(16),
                child: _buildQRContent(),
              ),

            // Connected Users Section
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Connected Guardians',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  _buildConnectedUsersList(_connectedGuardians),
                  SizedBox(height: 16),
                  Text('Connected Seniors',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  _buildConnectedUsersList(_connectedSeniors),
                ],
              ),
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
            'Scanned Code: $_scannedCode',
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
    final qrData = jsonEncode({
      'userID': widget.user.userID,
      'type': 'senior',
      'name': widget.user.name,
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
    final String seniorUserID = seniorData['userID'];
    final String guardianUserID = widget.userID;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Connect with Senior'),
        content: Text('Do you want to connect with ${seniorData['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _updateConnection(seniorUserID, guardianUserID);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Successfully connected with ${seniorData['name']}'),
                    backgroundColor: Colors.green,
                  ),
                );
                await _loadConnectedUsers(); // Refresh the lists
              } catch (e) {
                print('Error in _handleSeniorScanned: $e');
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error connecting: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text('Connect'),
          ),
        ],
      ),
    );
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

  Future<void> _removeConnection(String connectedUserId) async {
    try {
      // Remove from current user's document
      await _firestore.collection('User').doc(widget.userID).update({
        'guardianIDs': FieldValue.arrayRemove(['/User/$connectedUserId']),
        'seniorIDs': FieldValue.arrayRemove(['/User/$connectedUserId']),
      });

      // Remove from connected user's document
      await _firestore.collection('User').doc(connectedUserId).update({
        'guardianIDs': FieldValue.arrayRemove(['/User/${widget.userID}']),
        'seniorIDs': FieldValue.arrayRemove(['/User/${widget.userID}']),
      });

      // Refresh the lists
      setState(() {
        _connectedGuardians.removeWhere((user) => user.userID == connectedUserId);
        _connectedSeniors.removeWhere((user) => user.userID == connectedUserId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection removed successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error removing connection: $e')),
      );
    }
  }

  Future<void> _confirmAndRemoveConnection(String connectedUserId) async {
  bool? confirm = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Confirm Removal'),
        content: Text('Are you sure you want to remove this connection?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false), // Cancel
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true), // Confirm
            child: Text('Remove'),
          ),
        ],
      );
    },
  );

  if (confirm == true) {
    await _removeConnection(connectedUserId);
  }
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