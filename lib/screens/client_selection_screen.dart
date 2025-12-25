// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class ClientSelectionScreen extends StatefulWidget {
  const ClientSelectionScreen({super.key});

  @override
  State<ClientSelectionScreen> createState() => _ClientSelectionScreenState();
}

class _ClientSelectionScreenState extends State<ClientSelectionScreen> {
  final _clientKeyController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _fetchClientConfig() async {
    final key = _clientKeyController.text.trim();
    if (key.isEmpty) {
      setState(() => _errorMessage = "Please enter your Client ID.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiService.getClientConfig(key);

      if (res['statusCode'] == 200) {
        final List results = res['data']['result'] ?? [];
        if (results.isNotEmpty) {
          final clientData = results[0];
          final prefs = await SharedPreferences.getInstance();

          // Save client details
          await prefs.setString('client_key', key);
          await prefs.setString('client_name', clientData['client_name'] ?? '');
          await prefs.setString('client_logo', clientData['client_logo'] ?? '');
          await prefs.setString('base_path', clientData['base_path'] ?? '');

          // Update API Service Base URL
          ApiService.baseUrl = clientData['base_path'] ?? ApiService.baseUrl;

          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        } else {
          setState(
            () => _errorMessage =
                "Invalid Client ID. Please check and try again.",
          );
        }
      } else {
        setState(
          () => _errorMessage =
              "Server error (${res['statusCode']}). Please contact support.",
        );
      }
    } on SocketException {
      setState(
        () => _errorMessage =
            "No internet connection. Please check your network.",
      );
    } on FormatException {
      setState(
        () => _errorMessage = "Invalid response from server. Please try again.",
      );
    } catch (e) {
      // General error fallback
      setState(
        () => _errorMessage =
            "Connection failed. Ensure Internet is enabled in Manifest.",
      );
      debugPrint("Setup Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Background Aesthetic Gradient
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [Colors.blue.shade900.withOpacity(0.15), Colors.black]
                      : [Colors.blue.shade50.withOpacity(0.4), Colors.white],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Modern Branding Container
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 25,
                            offset: const Offset(0, 10),
                          ),
                        ],
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.business_rounded,
                        size: 50,
                        color: Colors.blueAccent,
                      ),
                    ),

                    const SizedBox(height: 32),

                    const Text(
                      'Environment Setup',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.0,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Enter your organizational Client ID to continue.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Modern Input Field
                    TextField(
                      controller: _clientKeyController,
                      decoration: const InputDecoration(
                        labelText: 'Client ID',
                        hintText: 'e.g. TECHMAGE',
                        prefixIcon: Icon(Icons.vpn_key_rounded, size: 22),
                      ),
                      onSubmitted: (_) => _fetchClientConfig(),
                    ),

                    // Error Message Display
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.1),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 36),

                    // Primary Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _fetchClientConfig,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
                            : const Text(
                                'Connect Environment',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
