// ignore_for_file: unnecessary_underscores

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'video_player_screen.dart'; // we'll create this

class VideosScreen extends StatefulWidget {
  const VideosScreen({super.key});

  @override
  State<VideosScreen> createState() => _VideosScreenState();
}

class _VideosScreenState extends State<VideosScreen> {
  late Future<Map<String, dynamic>> _future;

  Future<Map<String, dynamic>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('useremail') ?? '';
    return ApiService.regularVideos(email);
  }

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Regular Videos')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final status = snapshot.data!['statusCode'] as int;
          final data = snapshot.data!['data'];

          if (status != 200) {
            return Center(child: Text('Failed to load videos ($status)'));
          }

          // API returns {"result":[...]}
          final List items = (data['result'] as List?) ?? [];

          if (items.isEmpty) {
            return const Center(child: Text('No videos found.'));
          }

          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final v = items[i];
              final title = v['title']?.toString() ?? 'Untitled';
              final thumb = v['thumnail_image']?.toString();
              final url = v['video_url']?.toString();

              return ListTile(
                leading: thumb != null
                    ? Image.network(thumb, width: 60, fit: BoxFit.cover)
                    : const Icon(Icons.play_circle_fill),
                title: Text(title),
                subtitle: Text(
                  'Posted on ${v['postedon']} • Views: ${v['views']}',
                ),
                onTap: () {
                  if (url != null) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            VideoPlayerScreen(videoUrl: url, title: title),
                      ),
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
