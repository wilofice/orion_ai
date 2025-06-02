import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../chat/chat_screen.dart'; // Adjust path
import '../events/event_list_screen.dart'; // Adjust path
import './../preferences/parameters_screen.dart'; // Adjust path

class MainTabsScreen extends StatefulWidget {
  final StatefulNavigationShell navigationShell; // Provided by GoRouter for nested navigation

  const MainTabsScreen({super.key, required this.navigationShell});

  @override
  State<MainTabsScreen> createState() => _MainTabsScreenState();
}

class _MainTabsScreenState extends State<MainTabsScreen> {
  void _onItemTapped(int index) {
    // Use the StatefulNavigationShell to navigate to the correct branch
    widget.navigationShell.goBranch(
      index,
      // A common pattern when using branch navigation with goBranch
      // is to navigate to the initial location of the branch on tap,
      // especially if you want to preserve navigation history within each tab.
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The body is now the StatefulNavigationShell's child
      body: widget.navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: 'Events',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Parameters',
          ),
        ],
        currentIndex: widget.navigationShell.currentIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}