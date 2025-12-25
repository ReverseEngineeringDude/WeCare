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

  // Using IndexedStack preserves the state (scroll position, etc.)
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
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      // IndexedStack keeps all pages "alive" in the background
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          // Added a more pronounced top border to separate the nav bar from content
          border: Border(
            top: BorderSide(
              color: theme.dividerColor.withOpacity(isDark ? 0.1 : 0.05),
              width: 1.0,
            ),
          ),
          // Slight shadow for depth
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBar(
          elevation: 0,
          // Using surface color ensures consistency with Material 3 design
          backgroundColor: theme.colorScheme.surface,
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onDestinationSelected,
          // FIX: Use primaryContainer for the pill background to prevent blending
          indicatorColor: theme.colorScheme.primaryContainer,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          height: 70, // Slightly increased height for better ergonomics
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.explore_outlined, color: Colors.grey.shade600),
              // FIX: Use onPrimaryContainer for high contrast against the indicator
              selectedIcon: Icon(Icons.explore, color: theme.colorScheme.onPrimaryContainer),
              label: 'Videos',
            ),
            NavigationDestination(
              icon: Icon(Icons.video_library_outlined, color: Colors.grey.shade600),
              selectedIcon: Icon(Icons.video_library, color: theme.colorScheme.onPrimaryContainer),
              label: 'Subscriptions',
            ),
            NavigationDestination(
              icon: Icon(Icons.download_for_offline_outlined, color: Colors.grey.shade600),
              selectedIcon: Icon(Icons.download_for_offline, color: theme.colorScheme.onPrimaryContainer),
              label: 'Offline',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined, color: Colors.grey.shade600),
              selectedIcon: Icon(Icons.settings, color: theme.colorScheme.onPrimaryContainer),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}