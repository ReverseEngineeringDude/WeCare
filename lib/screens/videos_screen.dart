// ignore_for_file: unnecessary_underscores

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skeletonsplus/skeletonsplus.dart';
import '../providers/download_provider.dart';
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
    _searchController.removeListener(_filterSubscriptions);
    _searchController.dispose();
    super.dispose();
  }

  // To fix the error in dispose provided in your snippet
  void _filterSubscriptions() {} 

  String _getVideoKey(Map<String, dynamic> video) {
    return video['id']?.toString() ?? video['video_url']?.toString() ?? 'unknown';
  }

  Future<void> _loadVideos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('useremail') ?? '';
      final response = await ApiService.regularVideos(email);

      if (mounted) {
        if (response['statusCode'] == 200) {
          final List items = (response['data']['result'] as List?) ?? [];
          final now = DateTime.now();
          final format = DateFormat('MMMM d, yyyy hh:mm a');
          
          final validVideos = items.where((video) {
            final expiryDateString = video['expiry_date'] as String?;
            if (expiryDateString == null || expiryDateString.isEmpty) {
              return true; 
            }
            try {
              final sanitizedDateString = expiryDateString.replaceAll(RegExp(r'\s+'), ' ');
              final expiryDate = format.parse(sanitizedDateString);
              return expiryDate.isAfter(now);
            } catch (e) {
              return true;
            }
          }).toList();

          setState(() {
            _allVideos = List<Map<String, dynamic>>.from(validVideos);
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
          _error = 'An error occurred. Check your connection.';
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

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      centerTitle: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      title: _isSearching
          ? Container(
              height: 45,
              decoration: BoxDecoration(
                color: Colors.grey.withAlpha((255 * 0.1).round()),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Search videos...',
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search, size: 20),
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            )
          : const Text(
              'Regular Videos',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 28,
                letterSpacing: -1,
              ),
            ),
      actions: [
        IconButton(
          onPressed: _toggleSearch,
          icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded),
          style: IconButton.styleFrom(
            backgroundColor: Colors.grey.withAlpha((255 * 0.1).round()),
          ),
        ),
        const SizedBox(width: 16),
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
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 24,
          childAspectRatio: 0.72,
        ),
        itemCount: _filteredVideos.length,
        itemBuilder: (context, i) => _buildModernVideoItem(_filteredVideos[i]),
      ),
    );
  }

  Widget _buildModernVideoItem(Map<String, dynamic> video) {
    final title = video['title']?.toString() ?? 'Video';
    final imageUrl = video['thumnail_image']?.toString();
    final url = video['video_url']?.toString();
    final expiry = video['expiry_date']?.toString();

    final downloadProvider = Provider.of<DownloadProvider>(context);
    final videoKey = _getVideoKey(video);
    final progress = downloadProvider.downloadProgress[videoKey];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Stack(
            children: [
              GestureDetector(
                onTap: () async {
                  if (url != null) {
                    final localPath = await DownloadService.getLocalPath(url, videoId: video['id']?.toString());
                    if (!mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            VideoPlayerScreen(videoUrl: url, title: title, localPath: localPath),
                      ),
                    );
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    image: (imageUrl != null && imageUrl.isNotEmpty)
                        ? DecorationImage(
                            image: NetworkImage(imageUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                    color: Colors.grey.shade200,
                  ),
                  child: (imageUrl == null || imageUrl.isEmpty)
                      ? const Center(
                          child: Icon(
                            Icons.videocam_rounded,
                            color: Colors.grey,
                          ),
                        )
                      : null,
                ),
              ),
              
              // Download Progress Overlay
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: progress != null ? null : () {
                    downloadProvider.startDownload(video);
                    _showSnackBar('Download started for $title');
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha((255 * 0.4).round()),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withAlpha((255 * 0.2).round()),
                        width: 1,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (progress != null && progress < 2.0)
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
                          progress == null
                            ? Icons.download_rounded
                            : progress == 2.0
                                ? Icons.check
                                : Icons.hourglass_top_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Expiry Date Badge
              if (expiry != null && expiry.isNotEmpty)
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha((255 * 0.7).round()),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_outlined, color: Colors.orangeAccent, size: 10),
                        const SizedBox(width: 4),
                        Text(
                          expiry,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 10, left: 4),
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 60, color: Colors.red.shade200),
          const SizedBox(height: 16),
          Text(_error, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          TextButton(onPressed: _loadVideos, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.video_library_rounded, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(_isSearching ? 'No matches found' : 'No videos available',
            style: const TextStyle(color: Colors.grey, fontSize: 16)),
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
        mainAxisSpacing: 24,
        childAspectRatio: 0.72,
      ),
      itemCount: 6,
      itemBuilder: (context, i) => SkeletonItem(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: SkeletonAvatar(style: SkeletonAvatarStyle(borderRadius: BorderRadius.circular(18)))),
            const SizedBox(height: 12),
            SkeletonLine(style: SkeletonLineStyle(height: 16, width: 100, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 6),
            SkeletonLine(style: SkeletonLineStyle(height: 12, width: 60, borderRadius: BorderRadius.circular(4))),
          ],
        ),
      ),
    );
  }
}