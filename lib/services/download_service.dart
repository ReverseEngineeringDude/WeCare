import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:synchronized/synchronized.dart';
import 'package:intl/intl.dart'; // Ensure 'intl' is added to your pubspec.yaml

class DownloadService {
  static const String _key = 'downloaded_videos';
  static final _lock = Lock();

  /// Helper to get a unique identifier for the video data
  static String _getId(Map<String, dynamic> video) {
    return video['id']?.toString() ??
        video['video_url']?.toString() ??
        'unknown';
  }

  /// Get list of downloaded video metadata
  static Future<List<Map<String, dynamic>>> getDownloadedVideos() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_key);
    if (data == null) return [];
    try {
      return List<Map<String, dynamic>>.from(jsonDecode(data));
    } catch (e) {
      return [];
    }
  }

  /// Check if a video is already downloaded and return valid path
  static Future<String?> getLocalPath(
    String videoUrl, {
    String? videoId,
  }) async {
    final downloads = await getDownloadedVideos();
    final targetId = videoId ?? videoUrl;

    for (var video in downloads) {
      final currentId = _getId(video);
      if (currentId == targetId || video['video_url'] == videoUrl) {
        final path = video['local_path'];
        if (path != null && await File(path).exists()) {
          return path;
        }
      }
    }
    return null;
  }

  /// Helper to parse the API's custom date format (e.g., "November  29, 2026 12:00 PM")
  static DateTime? parseExpiryDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return null;
    try {
      // API often sends double spaces (e.g., "November  29").
      // We normalize to single spaces for the DateFormat to work reliably.
      final normalized = dateStr.replaceAll(RegExp(r'\s+'), ' ').trim();
      // Format: Month Day, Year Hour:Minute AM/PM
      return DateFormat("MMMM d, yyyy h:mm a").parse(normalized);
    } catch (e) {
      debugPrint("Date Parsing Error: $e");
      return null;
    }
  }

  /// Get media duration using ffprobe
  static Future<double> _getMediaDuration(String mediaPath) async {
    try {
      final session = await FFprobeKit.getMediaInformation(mediaPath);
      final information = session.getMediaInformation();
      if (information == null) return 0.0;

      final durationStr = information.getDuration();
      return double.tryParse(durationStr ?? '0') ?? 0.0;
    } catch (e) {
      debugPrint("FFprobe error: $e");
      return 0.0;
    }
  }

  /// Downloads and converts M3U8 to MP4 using FFmpegKit with progress
  static Future<void> downloadVideo(
    Map<String, dynamic> videoData,
    Function(double) onProgress,
  ) async {
    final String videoUrl = videoData['video_url'];
    final String videoId = _getId(videoData);
    final appDir = await getApplicationDocumentsDirectory();

    // Create unique filename based on ID
    final fileName = "video_$videoId.mp4";
    final savePath = p.join(appDir.path, fileName);

    // Get duration for progress calculation
    final double duration = await _getMediaDuration(videoUrl);

    // Command to remux/convert
    final String command =
        "-y -i \"$videoUrl\" -c copy -bsf:a aac_adtstoasc \"$savePath\"";

    final completer = Completer<void>();

    try {
      onProgress(0.01); // Signal start

      await FFmpegKit.executeAsync(
        command,
        (session) async {
          final returnCode = await session.getReturnCode();

          if (ReturnCode.isSuccess(returnCode)) {
            await _lock.synchronized(() async {
              final prefs = await SharedPreferences.getInstance();
              final downloads = await getDownloadedVideos();

              final metadata = {
                'id': videoId,
                'title': videoData['title'],
                'video_url': videoUrl,
                'thumnail_image': videoData['thumnail_image'],
                'local_path': savePath,
                'expiry_date':
                    videoData['expiry_date'], // Save expiry string for later cleanup
                'downloaded_at': DateTime.now().toIso8601String(),
              };

              // Overwrite existing record for this specific ID if it exists
              downloads.removeWhere((item) => _getId(item) == videoId);
              downloads.add(metadata);

              await prefs.setString(_key, jsonEncode(downloads));
            });
            onProgress(1.0);
            completer.complete();
          } else if (ReturnCode.isCancel(returnCode)) {
            completer.completeError(Exception("Download cancelled"));
          } else {
            final logs = await session.getAllLogsAsString();
            completer.completeError(Exception("FFmpeg failed: $logs"));
          }
        },
        null, // Log callback
        (Statistics stats) {
          if (duration > 0) {
            // getTime() returns ms of video processed, duration is in seconds
            final double progress = stats.getTime() / (duration * 1000);
            onProgress(progress.clamp(0.0, 0.99));
          }
        },
      );

      return completer.future;
    } catch (e) {
      // Cleanup file on failure
      final file = File(savePath);
      if (await file.exists()) {
        await file.delete().catchError((_) => file);
      }
      rethrow;
    }
  }

  /// Deletes a video record and the physical file using localPath as the unique key.
  /// This ensures that only the specific file is deleted, even if URLs are the same.
  static Future<void> deleteVideo(String localPath) async {
    await _lock.synchronized(() async {
      final downloads = await getDownloadedVideos();

      // Find the specific record by its unique local path
      downloads.removeWhere((v) => v['local_path'] == localPath);

      final file = File(localPath);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (e) {
          debugPrint("File deletion error: $e");
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(downloads));
    });
  }
}
