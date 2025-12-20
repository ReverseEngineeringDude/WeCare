// ignore_for_file: unnecessary_underscores

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skeletonsplus/skeletonsplus.dart';
import '../services/api_service.dart';
import 'video_player_screen.dart';

class VideosScreen extends StatefulWidget {
  const VideosScreen({super.key});

  @override
  State<VideosScreen> createState() => _VideosScreenState();
}

class _VideosScreenState extends State<VideosScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allVideos = [];
  List<Map<String, dynamic>> _filteredVideos = [];
  String _error = '';

  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadVideos();
    _searchController.addListener(_filterVideos);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterVideos);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadVideos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('useremail') ?? '';
      final response = await ApiService.regularVideos(email);

      if (mounted) {
        if (response['statusCode'] == 200) {
          final List items = (response['data']['result'] as List?) ?? [];
          setState(() {
            _allVideos = List<Map<String, dynamic>>.from(items);
            _filteredVideos = _allVideos;
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = 'Failed to load videos (${response['statusCode']})';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'An error occurred: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _filterVideos() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredVideos = _allVideos.where((video) {
        final title = video['title']?.toString().toLowerCase() ?? '';
        return title.contains(query);
      }).toList();
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
      }
    });
  }

  AppBar _buildAppBar() {
    if (_isSearching) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _toggleSearch,
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search videos...',
            border: InputBorder.none,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _searchController.clear(),
          ),
        ],
      );
    } else {
      return AppBar(
        title: const Text('Regular Videos'),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: _toggleSearch),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: _buildAppBar(), body: _buildBody());
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Skeleton(
        isLoading: true,
        skeleton: _buildSkeleton(),
        child: const SizedBox.shrink(),
      );
    }
    if (_error.isNotEmpty) {
      return Center(child: Text(_error));
    }
    if (_filteredVideos.isEmpty) {
      return Center(
        child: Text(_isSearching ? 'No videos found.' : 'No videos available.'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadVideos,
      child: GridView.builder(
        padding: const EdgeInsets.all(8.0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8.0,
          mainAxisSpacing: 8.0,
          childAspectRatio: 0.75, // Adjust this ratio to your liking
        ),
        itemCount: _filteredVideos.length,
        itemBuilder: (context, i) {
          final v = _filteredVideos[i];
          final title = v['title']?.toString() ?? 'Untitled';
          final thumb = v['thumnail_image']?.toString();
          final url = v['video_url']?.toString();

          return Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: (thumb != null && thumb.isNotEmpty)
                        ? Image.network(
                            thumb,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (context, error, stackTrace) =>
                                const Center(
                                  child: Icon(Icons.play_circle_fill),
                                ),
                          )
                        : const Center(child: Icon(Icons.play_circle_fill)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      'Views: ${v['views']}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSkeleton() {
    return GridView.builder(
      padding: const EdgeInsets.all(8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
        childAspectRatio: 0.75,
      ),
      itemCount: 8,
      itemBuilder: (context, i) {
        return SkeletonItem(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: SkeletonAvatar(
                  style: SkeletonAvatarStyle(width: double.infinity),
                ),
              ),
              const SizedBox(height: 8),
              SkeletonLine(
                style: SkeletonLineStyle(
                  height: 16,
                  width: MediaQuery.of(context).size.width / 3,
                ),
              ),
              const SizedBox(height: 4),
              const SkeletonLine(
                style: SkeletonLineStyle(height: 12, width: 64),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
