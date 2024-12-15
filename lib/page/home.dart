import 'package:flutter/material.dart';
import 'package:medicine_assistant_app/main.dart';
import 'package:medicine_assistant_app/page/chatlist.dart'; // Import the ChatListPage
import 'package:medicine_assistant_app/page/home.dart';
import 'package:medicine_assistant_app/page/chatbot.dart';
import 'package:medicine_assistant_app/page/chat.dart';
import 'package:medicine_assistant_app/page/chatbotapi.dart';
import 'package:medicine_assistant_app/page/chatlist.dart';
import 'package:medicine_assistant_app/page/reminder.dart';
import 'package:medicine_assistant_app/page/helpAddReminder.dart';

class HomePage extends StatefulWidget {
  final String userID;
  const HomePage({super.key, required this.userID});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  List<Widget> get _pages {
    return <Widget>[
      //HomePage(userID: widget.userID),
      Center(child: Text('Home Page')),
      Center(child: Text('Recognize Page')),
      ChatListPage(userID: widget.userID),  // Chat list page is added here
      MedicationReminderScreen(userID: widget.userID),  // Use widget.userID to pass userID
      Center(child: Text('Profile Page')),  // You can add more pages here if needed
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;  // Update the selected index
    });
  }


  void _showSnackBar() {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text("Would you like to add a reminder for John?"),
        action: SnackBarAction(
          label: "Add Reminder",
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => HelpAddReminderScreen(
                  userID: widget.userID,
                  name: "John",
                ),
              ),
            );
          },
        ),
        duration: Duration(seconds: 10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('Medicine Assistant'),
      // ),
      body: _pages[_selectedIndex],  // Display the selected page
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.purple, // Highlighted color
        unselectedItemColor: Colors.grey, // Default color
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Recognize',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time),
            label: 'Reminder',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,  // Set the current selected index
        onTap: _onItemTapped,  // Handle tap to change the page
      ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: _showSnackBar,
      //   child: Icon(Icons.add),
      // ),
    );
  }
}
