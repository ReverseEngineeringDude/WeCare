// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/client_selection_screen.dart';
import 'services/theme_provider.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize dynamic API base URL from storage
  final prefs = await SharedPreferences.getInstance();
  final savedBasePath = prefs.getString('base_path');
  if (savedBasePath != null) {
    ApiService.baseUrl = savedBasePath;
  }

  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const GoFastApp(),
    ),
  );
}

class GoFastApp extends StatelessWidget {
  const GoFastApp({super.key});

  // Check both client configuration and user login status
  Future<Map<String, bool>> _getAppState() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'hasClient': prefs.getString('client_key') != null,
      'isLoggedIn': prefs.getString('useremail') != null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Primary color used throughout the app
    const primarySeed = Colors.blueAccent;

    return MaterialApp(
      title: 'GoFast',
      theme: ThemeData(
        brightness: Brightness.light,
        colorSchemeSeed: primarySeed,
        useMaterial3: true,
        // Global styling for text input fields
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: primarySeed, width: 2),
          ),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: primarySeed,
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade900.withOpacity(0.4),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.white10),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.white10),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: primarySeed, width: 2),
          ),
        ),
      ),
      themeMode: themeProvider.themeMode,
      debugShowCheckedModeBanner: false,
      home: FutureBuilder<Map<String, bool>>(
        future: _getAppState(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final hasClient = snapshot.data!['hasClient'] ?? false;
          final isLoggedIn = snapshot.data!['isLoggedIn'] ?? false;

          // Flow: Client Selection -> Login -> Home
          if (!hasClient) {
            return const ClientSelectionScreen();
          }

          return isLoggedIn ? const HomeScreen() : const LoginScreen();
        },
      ),
    );
  }
}
