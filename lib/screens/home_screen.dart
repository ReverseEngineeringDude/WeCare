// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'videos_screen.dart';
import 'subscriptions_screen.dart';
import 'settings_screen.dart';
import 'downloads_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Using IndexedStack is more modern as it preserves the state (scroll position, etc.)
  // of each screen when you switch tabs.
  final List<Widget> _pages = const [
    VideosScreen(),
    SubscriptionsScreen(),
    DownloadsScreen(),
    SettingsScreen(),
  ];

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      // IndexedStack keeps all pages "alive" in the background
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: theme.dividerColor.withOpacity(0.1),
              width: 0.5,
            ),
          ),
        ),
        child: NavigationBar(
          elevation: 0,
          backgroundColor: theme.scaffoldBackgroundColor,
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onDestinationSelected,
          indicatorColor: theme.primaryColor.withOpacity(0.1),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          height: 65,
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.explore_outlined, color: Colors.grey.shade600),
              selectedIcon: Icon(Icons.explore, color: theme.primaryColor),
              label: 'Videos',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.video_library_outlined,
                color: Colors.grey.shade600,
              ),
              selectedIcon: Icon(
                Icons.video_library,
                color: theme.primaryColor,
              ),
              label: 'Subscriptions',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.download_for_offline_outlined,
                color: Colors.grey.shade600,
              ),
              selectedIcon: Icon(
                Icons.download_for_offline,
                color: theme.primaryColor,
              ),
              label: 'Offline',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined, color: Colors.grey.shade600),
              selectedIcon: Icon(Icons.settings, color: theme.primaryColor),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
