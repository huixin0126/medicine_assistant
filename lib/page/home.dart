import 'package:flutter/material.dart';
import 'package:medicine_assistant_app/page/chatlist.dart';
import 'package:medicine_assistant_app/page/home.dart';
import 'package:medicine_assistant_app/page/indexhome.dart';
import 'package:medicine_assistant_app/page/reminder.dart';
import 'package:medicine_assistant_app/page/profil.dart';
import 'package:medicine_assistant_app/class/user.dart';
import 'package:medicine_assistant_app/page/recognize.dart';

class HomePage extends StatefulWidget {
  final String userID;
  final User user; // Add user to the widget
  const HomePage({Key? key, required this.userID, required this.user}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      IndexHome(userID: widget.userID),
      RecognizePage(userID: widget.userID),
      ChatListPage(userID: widget.userID),
      MedicationReminderScreen(userID: widget.userID),
      ProfilePage(userID: widget.userID, user: widget.user,),  // Assuming ProfilePage takes userID
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.purple,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
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
      ),
    );
  }
}