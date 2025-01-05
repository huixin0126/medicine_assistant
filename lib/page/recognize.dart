import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  Future<void> _editMedicine(String docId, String currentName) async {
    _nameController.text = currentName;
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Medicine'),
        content: TextField(
          controller: _nameController,
          decoration: InputDecoration(labelText: 'Medicine Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (_nameController.text.isNotEmpty) {
                try {
                  await FirebaseFirestore.instance
                      .collection('Medicine')
                      .doc(docId)
                      .update({'name': _nameController.text});
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Medicine updated successfully')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating medicine: $e')),
                  );
                }
              }
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Recognize & Medicines"),
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
                              onPressed: () => _editMedicine(docId, name),
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
                                return child; // The image is fully loaded.
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