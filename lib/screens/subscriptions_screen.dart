// ignore_for_file: unnecessary_underscores

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skeletonsplus/skeletonsplus.dart';
import '../providers/download_provider.dart';
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

  /// Helper to generate a unique key for tracking
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

      if (mounted && response['statusCode'] == 200) {
        final List items = (response['data']['result'] as List?) ?? [];

        // --- AUTO-CLEANUP LOGIC ---
        // Verify local files against expiry dates and current active subscriptions
        final downloadedVideos = await DownloadService.getDownloadedVideos();
        final now = DateTime.now();
        final activeIds = items.map((s) => s['id']?.toString()).toSet();

        for (var video in downloadedVideos) {
          final localPath = video['local_path'] ?? '';
          final videoId = video['id']?.toString();
          final expiryStr = video['expiry_date'];

          bool shouldDelete = false;

          // 1. Delete if expired
          if (expiryStr != null) {
            final expiryDate = DownloadService.parseExpiryDate(expiryStr);
            if (expiryDate != null && now.isAfter(expiryDate)) {
              shouldDelete = true;
            }
          }

          // 2. Delete if no longer in the subscription list (access revoked)
          // We only perform this check if the video has a valid ID
          if (!shouldDelete &&
              videoId != null &&
              videoId != 'unknown' &&
              !activeIds.contains(videoId)) {
            shouldDelete = true;
          }

          if (shouldDelete && localPath.isNotEmpty) {
            await DownloadService.deleteVideo(localPath);
          }
        }

        // Refresh provider state after potential cleanup
        if (mounted) {
          context.read<DownloadProvider>().refreshDownloads();
        }

        setState(() {
          _allSubscriptions = List<Map<String, dynamic>>.from(items);
          _filteredSubscriptions = _allSubscriptions;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load library content';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Network error. Please try again.';
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
                  hintText: 'Search library...',
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search, size: 20),
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            )
          : const Text(
              'Subscriptions',
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
    if (_filteredSubscriptions.isEmpty) return _buildEmptyState();

    return RefreshIndicator(
      onRefresh: _loadSubscriptions,
      strokeWidth: 3,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 24,
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

    final downloadProvider = Provider.of<DownloadProvider>(context);
    final videoKey = _getVideoKey(s);
    final progress = downloadProvider.downloadProgress[videoKey];

    // FIXED BUG: prioritized ID check to prevent same-URL testing collisions
    final isDownloaded = downloadProvider.downloads.any((v) {
      final downloadedId = v['id']?.toString();
      final currentId = s['id']?.toString();

      // If we have unique IDs, they MUST match. This stops different videos
      // with the same URL from looking like they are all downloaded.
      if (downloadedId != null && currentId != null) {
        return downloadedId == currentId;
      }

      // Fallback to URL only if IDs are missing
      return v['video_url'] == url;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Stack(
            children: [
              GestureDetector(
                onTap: () async {
                  if (url != null) {
                    final localPath = await DownloadService.getLocalPath(
                      url,
                      videoId: s['id']?.toString(),
                    );
                    if (!mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VideoPlayerScreen(
                          videoUrl: url,
                          title: title,
                          localPath: localPath,
                        ),
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
                            Icons.card_membership,
                            color: Colors.grey,
                          ),
                        )
                      : null,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: (progress != null || isDownloaded)
                      ? null
                      : () {
                          downloadProvider.startDownload(s);
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
                        if (progress != null && progress < 2.0)
                          Text(
                            '${(progress * 100).toInt()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        Icon(
                          isDownloaded || progress == 2.0
                              ? Icons.check_circle_rounded
                              : progress == null
                              ? Icons.download_rounded
                              : Icons.hourglass_top_rounded,
                          size: 16,
                          color: isDownloaded || progress == 2.0
                              ? Colors.greenAccent
                              : Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (expiry != null)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha((255 * 0.6).round()),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      expiry,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 10, left: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Premium Access',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
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
          Icon(
            Icons.error_outline_rounded,
            size: 60,
            color: Colors.red.shade200,
          ),
          const SizedBox(height: 16),
          Text(_error, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          TextButton(onPressed: _loadSubscriptions, child: const Text('Retry')),
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
            Icons.auto_awesome_motion_rounded,
            size: 60,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            _isSearching ? 'No matches found' : 'No active subscriptions',
            style: const TextStyle(color: Colors.grey, fontSize: 16),
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
        mainAxisSpacing: 24,
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
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SkeletonLine(
              style: SkeletonLineStyle(
                height: 16,
                width: 100,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 6),
            SkeletonLine(
              style: SkeletonLineStyle(
                height: 12,
                width: 60,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
