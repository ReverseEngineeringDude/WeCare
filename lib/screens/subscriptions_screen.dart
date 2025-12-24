// ignore_for_file: unnecessary_underscores, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skeletonsplus/skeletonsplus.dart';
import '../services/api_service.dart';
import '../services/download_service.dart';
import 'video_player_screen.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allSubscriptions = [];
  List<Map<String, dynamic>> _filteredSubscriptions = [];
  String _error = '';

  // Track download progress for specific videos using a unique key
  final Map<String, double> _downloadProgress = {};

  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
    _searchController.addListener(_filterSubscriptions);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterSubscriptions);
    _searchController.dispose();
    super.dispose();
  }

  // Helper to get a unique identifier for a video
  String _getVideoKey(Map<String, dynamic> video) {
    return video['id']?.toString() ??
        video['video_url']?.toString() ??
        'unknown';
  }

  Future<void> _loadSubscriptions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('useremail') ?? '';
      final response = await ApiService.subscriptions(email);

      if (mounted) {
        if (response['statusCode'] == 200) {
          final List items = (response['data']['result'] as List?) ?? [];

          // Cleanup logic for expired downloads
          final downloadedVideos = await DownloadService.getDownloadedVideos();
          final activeSubscriptionUrls = items
              .map((sub) => sub['video_url'])
              .toList();

          for (var video in downloadedVideos) {
            final videoUrl = video['video_url'];
            if (!activeSubscriptionUrls.contains(videoUrl)) {
              await DownloadService.deleteVideo(videoUrl);
            }
          }

          setState(() {
            _allSubscriptions = List<Map<String, dynamic>>.from(items);
            _filteredSubscriptions = _allSubscriptions;
            _isLoading = false;
          });
        } else {
          setState(() {
            _error =
                'Failed to load library content (${response['statusCode']})';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Network error. Please check your connection.';
          _isLoading = false;
        });
      }
    }
  }

  void _filterSubscriptions() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredSubscriptions = _allSubscriptions.where((sub) {
        final title = sub['title']?.toString().toLowerCase() ?? '';
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

  Future<void> _downloadVideo(Map<String, dynamic> videoData) async {
    final url = videoData['video_url'];
    final videoKey = _getVideoKey(videoData);

    if (url == null) return;

    try {
      await DownloadService.downloadVideo(videoData, (progress) {
        setState(() {
          _downloadProgress[videoKey] = progress;
        });
      });
      setState(() => _downloadProgress.remove(videoKey));
      _showSnackBar('${videoData['title']} added to offline!');
    } catch (e) {
      setState(() => _downloadProgress.remove(videoKey));
      _showSnackBar('Download failed: $e');
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
                  hintText: 'Search your library...',
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search_rounded, size: 20),
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            )
          : const Text(
              'My Library',
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
    if (_filteredSubscriptions.isEmpty) return _buildEmptyState();

    return RefreshIndicator(
      onRefresh: _loadSubscriptions,
      strokeWidth: 3,
      displacement: 20,
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 28,
          childAspectRatio: 0.72,
        ),
        itemCount: _filteredSubscriptions.length,
        itemBuilder: (context, i) =>
            _buildModernSubscriptionItem(_filteredSubscriptions[i]),
      ),
    );
  }

  Widget _buildModernSubscriptionItem(Map<String, dynamic> s) {
    final title = s['title']?.toString() ?? 'Subscription';
    final expiry = s['expiry_date']?.toString();
    final imageUrl = s['thumnail_image']?.toString();
    final url = s['video_url']?.toString();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final videoKey = _getVideoKey(s);
    final progress = _downloadProgress[videoKey];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Premium Media Container
        Expanded(
          child: Stack(
            children: [
              GestureDetector(
                onTap: () {
                  if (url != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            VideoPlayerScreen(videoUrl: url, title: title),
                      ),
                    );
                  }
                },
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
                    image: (imageUrl != null && imageUrl.isNotEmpty)
                        ? DecorationImage(
                            image: NetworkImage(imageUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                    color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                  ),
                  child: (imageUrl == null || imageUrl.isEmpty)
                      ? const Center(
                          child: Icon(
                            Icons.card_membership_rounded,
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
                  onTap: progress != null ? null : () => _downloadVideo(s),
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

              // Refined Expiry Badge
              if (expiry != null)
                Positioned(
                  bottom: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          color: Colors.white70,
                          size: 10,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          expiry,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
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
              const SizedBox(height: 3),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'PREMIUM',
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Full Access',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
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
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.cloud_off_rounded,
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
            onPressed: _loadSubscriptions,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Try Again'),
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
            _isSearching ? 'No matching content' : 'Your library is empty',
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
        childAspectRatio: 0.72,
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
