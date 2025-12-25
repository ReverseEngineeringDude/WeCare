import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:skeletonsplus/skeletonsplus.dart';
import '../providers/download_provider.dart';
import 'video_player_screen.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  /// Handles the deletion confirmation and triggers the provider to update state
  Future<void> _confirmAndDelete(
    BuildContext context,
    DownloadProvider provider,
    String localPath,
    String title,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Download?'),
        content: Text(
          'Are you sure you want to delete "$title" from your device?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await provider.deleteDownload(localPath);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted $title'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // This makes the UI rebuild automatically whenever the provider calls notifyListeners()
    final downloadProvider = Provider.of<DownloadProvider>(context);
    final downloads = downloadProvider.downloads;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: const Text(
          'Downloads',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 28,
            letterSpacing: -1,
          ),
        ),
      ),
      body: _buildBody(context, downloadProvider, downloads),
    );
  }

  Widget _buildBody(
    BuildContext context,
    DownloadProvider provider,
    List<Map<String, dynamic>> downloads,
  ) {
    if (provider.isLoading && downloads.isEmpty) {
      return _buildSkeletonGrid(context);
    }

    if (downloads.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.download_for_offline_rounded,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            const Text(
              'No offline videos yet',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Videos you download from the discover tab will appear here for offline viewing.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.refreshDownloads(),
      strokeWidth: 2,
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 24,
          childAspectRatio: 0.75,
        ),
        itemCount: downloads.length,
        itemBuilder: (context, i) =>
            _buildDownloadItem(context, provider, downloads[i]),
      ),
    );
  }

  Widget _buildDownloadItem(
    BuildContext context,
    DownloadProvider provider,
    Map<String, dynamic> v,
  ) {
    final title = v['title']?.toString() ?? 'Untitled';
    final thumb = v['thumnail_image']?.toString();
    final url = v['video_url']?.toString();
    final localPath = v['local_path']?.toString();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Stack(
            children: [
              GestureDetector(
                onTap: () {
                  if (url != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VideoPlayerScreen(
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
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha((255 * 0.06).round()),
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
                            Icons.offline_pin_rounded,
                            color: Colors.grey,
                            size: 40,
                          ),
                        )
                      : null,
                ),
              ),

              const Center(
                child: IgnorePointer(
                  child: Icon(
                    Icons.play_circle_outline_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),

              Positioned(
                top: 10,
                right: 10,
                child: GestureDetector(
                  onTap: () {
                    if (localPath != null) {
                      _confirmAndDelete(context, provider, localPath, title);
                    }
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
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              Positioned(
                bottom: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withAlpha((255 * 0.9).round()),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.offline_pin_rounded,
                        color: Colors.white,
                        size: 10,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'OFFLINE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
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
          padding: const EdgeInsets.only(top: 12, left: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Available offline',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (v['expiry_date'] != null && v['expiry_date'].isNotEmpty)
                Builder(
                  builder: (context) {
                    try {
                      final expiryDateString = v['expiry_date'].replaceAll(RegExp(r'\s+'), ' ');
                      final expiryDate = DateFormat('MMMM d, yyyy hh:mm a').parse(expiryDateString);
                      return Text(
                        'Expires: ${DateFormat('MMM d, yyyy').format(expiryDate)}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    } catch (e) {
                      // ignore: avoid_print
                      print('Error parsing expiry date for downloaded video: $e');
                      return const SizedBox.shrink(); // Hide if parsing fails
                    }
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonGrid(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 24,
        childAspectRatio: 0.75,
      ),
      itemCount: 4,
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
                height: 16,
                width: 100,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 6),
            SkeletonLine(
              style: SkeletonLineStyle(
                height: 12,
                width: 60,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
