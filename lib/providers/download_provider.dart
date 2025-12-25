import 'dart:async';
import 'package:flutter/material.dart';
import '../services/download_service.dart';

class DownloadProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _downloads = [];
  bool _isLoading = false;

  // Maps a unique key (id or path) to current progress (0.0 to 1.0, or 2.0 for 'Complete')
  final Map<String, double> _downloadProgress = {};

  // Queue to manage multiple download requests sequentially
  final List<Map<String, dynamic>> _downloadQueue = [];
  bool _isDownloading = false;

  List<Map<String, dynamic>> get downloads => _downloads;
  bool get isLoading => _isLoading;
  Map<String, double> get downloadProgress => _downloadProgress;

  DownloadProvider() {
    refreshDownloads();
  }

  /// Fetches the latest list of downloads from storage
  Future<void> refreshDownloads() async {
    _isLoading = true;
    notifyListeners();
    _downloads = await DownloadService.getDownloadedVideos();
    _isLoading = false;
    notifyListeners();
  }

  /// Deletes a specific download using its unique localPath.
  /// Using localPath is essential when testing with videos that share the same URL.
  Future<void> deleteDownload(String localPath) async {
    await DownloadService.deleteVideo(localPath);
    await refreshDownloads();
  }

  /// Entry point to start a download.
  void startDownload(Map<String, dynamic> video) {
    final videoKey = _getVideoKey(video);

    // Prevent duplicates in queue or active downloads
    bool alreadyInQueue = _downloadQueue.any(
      (v) => _getVideoKey(v) == videoKey,
    );
    bool alreadyDownloading = _downloadProgress.containsKey(videoKey);

    if (alreadyInQueue || alreadyDownloading) {
      return;
    }

    _downloadQueue.add(video);
    _processDownloadQueue();
    notifyListeners();
  }

  /// Helper to generate a unique key for tracking progress.
  /// For testing with same URLs, 'id' is preferred if available.
  String _getVideoKey(Map<String, dynamic> video) {
    return video['id']?.toString() ??
        video['video_url']?.toString() ??
        'unknown';
  }

  /// Sequential processing of the download queue
  Future<void> _processDownloadQueue() async {
    if (_isDownloading || _downloadQueue.isEmpty) return;

    _isDownloading = true;
    final video = _downloadQueue.first;
    final videoKey = _getVideoKey(video);

    try {
      _downloadProgress[videoKey] = 0.0;
      notifyListeners();

      await DownloadService.downloadVideo(video, (progress) {
        _downloadProgress[videoKey] = progress;
        notifyListeners();
      });

      // UI 'Complete' state
      _downloadProgress[videoKey] = 2.0;
      notifyListeners();

      await Future.delayed(const Duration(seconds: 2));
      _downloadProgress.remove(videoKey);

      await refreshDownloads();
    } catch (e) {
      debugPrint("Download failed for $videoKey: $e");
      _downloadProgress.remove(videoKey);
    } finally {
      if (_downloadQueue.isNotEmpty) {
        _downloadQueue.removeAt(0);
      }

      _isDownloading = false;
      _processDownloadQueue();
      notifyListeners();
    }
  }
}
