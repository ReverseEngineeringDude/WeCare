// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class ClientSelectionScreen extends StatefulWidget {
  const ClientSelectionScreen({super.key});

  @override
  State<ClientSelectionScreen> createState() => _ClientSelectionScreenState();
}

class _ClientSelectionScreenState extends State<ClientSelectionScreen> with SingleTickerProviderStateMixin {
  final _clientKeyController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  
  late AnimationController _bgAnimationController;

  @override
  void initState() {
    super.initState();
    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20), // Slower for a more professional feel
    )..repeat();
  }

  @override
  void dispose() {
    _bgAnimationController.dispose();
    _clientKeyController.dispose();
    super.dispose();
  }

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

          await prefs.setString('client_key', key);
          await prefs.setString('client_name', clientData['client_name'] ?? '');
          await prefs.setString('client_logo', clientData['client_logo'] ?? '');
          await prefs.setString('base_path', clientData['base_path'] ?? '');

          ApiService.baseUrl = clientData['base_path'] ?? ApiService.baseUrl;

          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        } else {
          setState(() => _errorMessage = "Invalid Client ID. Please check and try again.");
        }
      } else {
        setState(() => _errorMessage = "Server error (${res['statusCode']}).");
      }
    } on SocketException {
      setState(() => _errorMessage = "No internet connection detected.");
    } catch (e) {
      setState(() => _errorMessage = "Connection failed. Please try again later.");
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
          // 1. Dynamic Background Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: isDark
                      ? [const Color(0xFF0F172A), Colors.black]
                      : [const Color(0xFFF1F5F9), Colors.white],
                ),
              ),
            ),
          ),
          
          // 2. Refined Floating Background Blobs
          AnimatedBuilder(
            animation: _bgAnimationController,
            builder: (context, child) {
              return Stack(
                children: [
                  Positioned(
                    top: 80 + (40 * math.sin(_bgAnimationController.value * 2 * math.pi)),
                    left: -40 + (30 * math.cos(_bgAnimationController.value * 2 * math.pi)),
                    child: _buildBlob(280, Colors.blueAccent.withOpacity(isDark ? 0.07 : 0.04)),
                  ),
                  Positioned(
                    bottom: 40 + (50 * math.cos(_bgAnimationController.value * 2 * math.pi)),
                    right: -60 + (40 * math.sin(_bgAnimationController.value * 2 * math.pi)),
                    child: _buildBlob(320, Colors.indigoAccent.withOpacity(isDark ? 0.07 : 0.03)),
                  ),
                ],
              );
            },
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOutExpo,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 40 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 3. Premium Rectangular Logo Container
                      Container(
                        constraints: const BoxConstraints(maxWidth: 240, minHeight: 80),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark ? Colors.white.withOpacity(0.08) : Colors.white,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                              blurRadius: 40,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.hub_rounded, size: 32, color: Colors.blueAccent),
                              const SizedBox(width: 12),
                              Text(
                                'Techmage',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                  color: isDark ? Colors.white : Colors.black87,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 56),

                      // 4. Headlines
                      Text(
                        'Techmage',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.0,
                          fontSize: 34,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'Welcome to your enterprise workspace.\nPlease enter your workspace ID to begin.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade600,
                            height: 1.6,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      const SizedBox(height: 48),

                      // 5. Input Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.02) : Colors.white,
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha((255 * 0.02).round()),
                              blurRadius: 50,
                              offset: const Offset(0, 25),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            TextField(
                              controller: _clientKeyController,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                              cursorColor: Colors.blueAccent,
                              decoration: InputDecoration(
                                labelText: 'Workspace Client ID',
                                hintText: 'e.g. TECHMAGE_01',
                                prefixIcon: const Icon(Icons.vpn_key_outlined, size: 20),
                                filled: true,
                                fillColor: isDark ? Colors.black38 : Colors.grey.shade50,
                                labelStyle: const TextStyle(fontWeight: FontWeight.w500),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
                                ),
                              ),
                            ),
                            
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 20),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 28),

                            // 6. Action Button
                            SizedBox(
                              width: double.infinity,
                              height: 64,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _fetchClientConfig,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shadowColor: Colors.blueAccent.withOpacity(0.4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Connect Workspace',
                                            style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Icon(Icons.arrow_forward_ios_rounded, size: 14),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 64),

                      // 7. Footer
                      Text(
                        'POWERED BY TECHMAGE ENTERPRISE',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 3.0,
                          fontWeight: FontWeight.w900,
                          color: Colors.grey.withOpacity(0.4),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}