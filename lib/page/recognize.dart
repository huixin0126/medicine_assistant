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

  void _onTabSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
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

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: DataTable(
            columnSpacing: 16,
            dataRowHeight: 180, // Adjust row height for better image display
            columns: [
              DataColumn(
                label: Text(
                  "Name",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  "Picture",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
            rows: medicines.map((medicine) {
              final name = medicine['name'];
              final imageUrl = medicine['imageData'];

              return DataRow(
                cells: [
                  DataCell(
                    SizedBox(
                      width: 200, // Adjust width for better readability
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(
                    imageUrl != null && imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            width: 150,
                            height: 150,
                            fit: BoxFit.cover,
                          )
                        : Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                          ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      );
    },
  );
}
}