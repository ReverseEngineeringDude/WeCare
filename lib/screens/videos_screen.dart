// ignore_for_file: unnecessary_underscores, deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skeletonsplus/skeletonsplus.dart';
import '../services/api_service.dart';
import '../services/download_service.dart';
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

  // Track download progress using a unique key per video
  final Map<String, double> _downloadProgress = {};

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

  // Helper to generate a unique key for each video item
  String _getVideoKey(Map<String, dynamic> video) {
    return video['id']?.toString() ??
        video['video_url']?.toString() ??
        'unknown';
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
            _error = 'Failed to load content (${response['statusCode']})';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'No internet connection. Check your downloads.';
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

  Future<void> _startDownload(Map<String, dynamic> video) async {
    final url = video['video_url'];
    final videoKey = _getVideoKey(video);

    if (url == null) return;

    final existingPath = await DownloadService.getLocalPath(url);
    if (existingPath != null) {
      _showSnackBar('Video already available offline');
      return;
    }

    try {
      await DownloadService.downloadVideo(video, (progress) {
        setState(() {
          _downloadProgress[videoKey] = progress;
        });
      });
      setState(() => _downloadProgress.remove(videoKey));
      _showSnackBar('${video['title']} downloaded!');
    } catch (e) {
      setState(() => _downloadProgress.remove(videoKey));
      _showSnackBar('Download failed. Check your storage.');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      centerTitle: false,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      title: _isSearching
          ? Container(
              height: 45,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Search videos...',
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search_rounded, size: 20),
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            )
          : const Text(
              'Discover',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 28,
                letterSpacing: -1,
              ),
            ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: IconButton(
            onPressed: _toggleSearch,
            icon: Icon(
              _isSearching ? Icons.close_rounded : Icons.search_rounded,
            ),
            style: IconButton.styleFrom(
              backgroundColor: Colors.grey.withOpacity(0.1),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: _buildAppBar(), body: _buildBody());
  }

  Widget _buildBody() {
    if (_isLoading) return _buildSkeletonGrid();
    if (_error.isNotEmpty) return _buildErrorState();
    if (_filteredVideos.isEmpty) return _buildEmptyState();

    return RefreshIndicator(
      onRefresh: _loadVideos,
      strokeWidth: 3,
      displacement: 20,
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 28,
          childAspectRatio: 0.75,
        ),
        itemCount: _filteredVideos.length,
        itemBuilder: (context, i) => _buildModernVideoItem(_filteredVideos[i]),
      ),
    );
  }

  Widget _buildModernVideoItem(Map<String, dynamic> v) {
    final title = v['title']?.toString() ?? 'Untitled';
    final thumb = v['thumnail_image']?.toString();
    final url = v['video_url']?.toString();
    final views = v['views']?.toString() ?? '0';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final videoKey = _getVideoKey(v);
    final progress = _downloadProgress[videoKey];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Premium Media Container
        Expanded(
          child: Stack(
            children: [
              GestureDetector(
                onTap: () => _handleVideoTap(url, title),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    image: (thumb != null && thumb.isNotEmpty)
                        ? DecorationImage(
                            image: NetworkImage(thumb),
                            fit: BoxFit.cover,
                          )
                        : null,
                    color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                  ),
                  child: (thumb == null || thumb.isEmpty)
                      ? const Center(
                          child: Icon(
                            Icons.video_library_outlined,
                            color: Colors.grey,
                            size: 40,
                          ),
                        )
                      : null,
                ),
              ),

              // Glass-morphic Download Action
              Positioned(
                top: 10,
                right: 10,
                child: GestureDetector(
                  onTap: progress != null ? null : () => _startDownload(v),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (progress != null)
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 2,
                              color: Colors.white,
                              backgroundColor: Colors.white24,
                            ),
                          ),
                        Icon(
                          progress != null
                              ? Icons.hourglass_empty_rounded
                              : Icons.arrow_downward_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Play Badge (Bottom Left)
              Positioned(
                bottom: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Polished Metadata Area
        Padding(
          padding: const EdgeInsets.only(top: 12, left: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$views views',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleVideoTap(String? url, String title) async {
    if (url == null) return;
    String? localPath = await DownloadService.getLocalPath(url);

    if (localPath != null) {
      final file = File(localPath);
      if (!await file.exists()) {
        localPath = null;
      }
    }

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          videoUrl: url,
          title: title,
          localPath: localPath,
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.wifi_off_rounded,
              size: 48,
              color: Colors.red.shade300,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _error,
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadVideos,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Retry Connection'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.video_collection_outlined,
            size: 80,
            color: Colors.grey.shade200,
          ),
          const SizedBox(height: 16),
          Text(
            _isSearching ? 'No matching videos' : 'No videos available',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 28,
        childAspectRatio: 0.75,
      ),
      itemCount: 6,
      itemBuilder: (context, i) => SkeletonItem(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SkeletonAvatar(
                style: SkeletonAvatarStyle(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SkeletonLine(
              style: SkeletonLineStyle(
                height: 18,
                width: 120,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 6),
            SkeletonLine(
              style: SkeletonLineStyle(
                height: 12,
                width: 80,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
