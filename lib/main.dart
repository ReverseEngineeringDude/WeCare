import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/client_selection_screen.dart';
import 'services/theme_provider.dart';
import 'services/api_service.dart';
import 'providers/download_provider.dart'; // Import the missing provider

void main() async {
  // 1. Ensure Flutter is initialized before async calls
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Pre-initialize the Base URL from storage
  try {
    final prefs = await SharedPreferences.getInstance();
    final savedBasePath = prefs.getString('base_path');
    if (savedBasePath != null && savedBasePath.isNotEmpty) {
      ApiService.baseUrl = savedBasePath;
    }
  } catch (e) {
    debugPrint("Failed to load initial settings: $e");
  }

  runApp(
    // Wrapped in MultiProvider to support both Theme and Downloads
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => DownloadProvider()),
      ],
      child: const GoFastApp(),
    ),
  );
}

class GoFastApp extends StatefulWidget {
  const GoFastApp({super.key});

  @override
  State<GoFastApp> createState() => _GoFastAppState();
}

class _GoFastAppState extends State<GoFastApp> {
  // 3. Store the Future in a variable to prevent it from re-running on every build
  late Future<Map<String, bool>> _appStateFuture;

  @override
  void initState() {
    super.initState();
    _appStateFuture = _getAppState();
  }

  Future<Map<String, bool>> _getAppState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'hasClient': prefs.getString('client_key') != null,
        'isLoggedIn': prefs.getString('useremail') != null,
      };
    } catch (e) {
      return {'hasClient': false, 'isLoggedIn': false};
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    const primarySeed = Colors.blueAccent;

    return MaterialApp(
      title: 'TechMage',
      theme: ThemeData(
        brightness: Brightness.light,
        colorSchemeSeed: primarySeed,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: primarySeed,
        useMaterial3: true,
      ),
      themeMode: themeProvider.themeMode,
      debugShowCheckedModeBanner: false,
      home: FutureBuilder<Map<String, bool>>(
        future: _appStateFuture, // Use the stored future variable
        builder: (context, snapshot) {
          // 4. Handle Loading State
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // 5. Handle Error State
          if (snapshot.hasError || !snapshot.hasData) {
            return const Scaffold(
              body: Center(
                child: Text("Error loading app state. Please restart."),
              ),
            );
          }

          final hasClient = snapshot.data!['hasClient'] ?? false;
          final isLoggedIn = snapshot.data!['isLoggedIn'] ?? false;

          // Flow control: First setup client, then login, then home
          if (!hasClient) {
            return const ClientSelectionScreen();
          }

          return isLoggedIn ? const HomeScreen() : const LoginScreen();
        },
      ),
    );
  }
}
