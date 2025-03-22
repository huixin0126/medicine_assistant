import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:medicine_assistant_app/page/scanMedicine.dart';

class RecognizePage extends StatefulWidget {
  final String userID;

  RecognizePage({required this.userID});

  @override
  _RecognizePageState createState() => _RecognizePageState();
}

class _RecognizePageState extends State<RecognizePage> {
  int _selectedIndex = 0;
  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  String? _currentImageUrl;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _showImageSourceDialog(String docId, StateSetter setState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Image'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt),
              title: Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(docId, ImageSource.camera, setState);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library),
              title: Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(docId, ImageSource.gallery, setState);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMedicine(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('Medicine')
          .doc(docId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Medicine deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting medicine: $e')),
      );
    }
  }

  Future<void> _editMedicine(String docId, String currentName, String currentImageUrl) async {
    _nameController.text = currentName;
    _selectedImage = null;
    _currentImageUrl = currentImageUrl;
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Edit Medicine'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: 'Medicine Name'),
                  enabled: !_isSaving, // Disable when saving
                ),
                SizedBox(height: 16),
                Container(
                  height: 200,
                  width: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _selectedImage != null
                      ? Image.file(_selectedImage!, fit: BoxFit.cover)
                      : (_currentImageUrl != null && _currentImageUrl!.isNotEmpty
                          ? Image.network(
                              _currentImageUrl!,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(Icons.broken_image, size: 50);
                              },
                            )
                          : Icon(Icons.image_not_supported, size: 50)),
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isSaving ? null : () => _showImageSourceDialog(docId, setState),
                  child: Text('Change Image'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isSaving 
                  ? null 
                  : () {
                      _selectedImage = null;
                      _currentImageUrl = null;
                      Navigator.pop(context);
                    },
              child: Text('Cancel'),
            ),
            if (_isSaving)
              Container(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
            else
              TextButton(
                onPressed: () async {
                  if (_nameController.text.isNotEmpty) {
                    setState(() {
                      _isSaving = true;
                    });
                    
                    try {
                      // First update the name
                      final updates = {'name': _nameController.text};
                      
                      // If there's a new image, upload it and add to updates
                      if (_selectedImage != null) {
                        final imageUrl = await _uploadImage(_selectedImage!);
                        if (imageUrl != null) {
                          updates['imageData'] = imageUrl;
                        }
                      }

                      // Update Firestore
                      await FirebaseFirestore.instance
                          .collection('Medicine')
                          .doc(docId)
                          .update(updates);
                      
                      if (mounted) {
                        Navigator.pop(context);
                        _selectedImage = null;
                        _currentImageUrl = null;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Medicine updated successfully')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error updating medicine: $e')),
                        );
                      }
                    } finally {
                      if (mounted) {
                        setState(() {
                          _isSaving = false;
                        });
                      }
                    }
                  }
                },
                child: Text('Save'),
              ),
          ],
        ),
      ),
    );
  }

  Future<String?> _uploadImage(File imageFile) async {
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('medicine_images')
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

      await storageRef.putFile(imageFile);
      return await storageRef.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _pickImage(String docId, ImageSource source, StateSetter setState) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
                title: const Text(
                  'Recognize & Medicines',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildRecognizeTab(context),
          _buildMedicineListTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTabSelected,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt),
            label: "Recognize",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: "Medicine List",
          ),
        ],
      ),
    );
  }

  Widget _buildRecognizeTab(BuildContext context) {
    return Center(
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ScanPage(userID: widget.userID),
            ),
          );
        },
        child: Text("Recognize"),
      ),
    );
  }

  Widget _buildMedicineListTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Medicine')
          .where('userID', isEqualTo: widget.userID)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text("No medicines available."));
        }

        final medicines = snapshot.data!.docs;

        return ListView.builder(
          itemCount: medicines.length,
          itemBuilder: (context, index) {
            final medicine = medicines[index];
            final name = medicine['name'];
            final imageUrl = medicine['imageData'];
            final docId = medicine.id;

            return Card(
              margin: EdgeInsets.all(8.0),
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editMedicine(docId, name, imageUrl),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('Delete Medicine'),
                                  content: Text('Are you sure you want to delete this medicine?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _deleteMedicine(docId);
                                      },
                                      child: Text('Delete'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Center(
                        child: Container(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.of(context).size.width * 0.6,
                            maxWidth: MediaQuery.of(context).size.width * 0.8,
                          ),
                          child: imageUrl != null && imageUrl.isNotEmpty
                              ? Image.network(
                                  imageUrl,
                                  fit: BoxFit.contain,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) {
                                      return child;
                                    }
                                    return Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress.expectedTotalBytes != null
                                            ? loadingProgress.cumulativeBytesLoaded /
                                                loadingProgress.expectedTotalBytes!
                                            : null,
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.broken_image,
                                      color: Colors.grey,
                                    );
                                  },
                                )
                              : Icon(
                                  Icons.image_not_supported,
                                  color: Colors.grey,
                                  size: 100,
                                ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}