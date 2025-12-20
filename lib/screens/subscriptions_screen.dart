// ignore_for_file: unnecessary_underscores

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'video_player_screen.dart'; // Added import for VideoPlayerScreen

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  late Future<Map<String, dynamic>> _future;

  Future<Map<String, dynamic>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('useremail') ?? '';
    return ApiService.subscriptions(email);
  }

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subscriptions')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final status = snapshot.data!['statusCode'] as int;
          final data = snapshot.data!['data'];

          if (status != 200) {
            return Center(
              child: Text('Failed to load subscriptions ($status)'),
            );
          }

          final List subs = data['result'] ?? [];
          if (subs.isEmpty) {
            return const Center(child: Text('No subscriptions.'));
          }

          return ListView.separated(
            itemCount: subs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final s = subs[i];
              final title = s['title']?.toString() ?? 'Subscription';
              final expiry = s['expiry_date']?.toString();
              final imageUrl = s['thumnail_image']?.toString();
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage:
                      imageUrl != null ? NetworkImage(imageUrl) : null,
                  onBackgroundImageError:
                      imageUrl != null ? (_, __) {} : null,
                  child: imageUrl == null ? const Icon(Icons.card_membership) : null,
                ),
                title: Text(title),
                subtitle: Text(
                  expiry != null ? 'Expires: $expiry' : 'No expiry date',
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VideoPlayerScreen(
                        videoUrl: s['video_url']?.toString() ?? '',
                        title: title,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}