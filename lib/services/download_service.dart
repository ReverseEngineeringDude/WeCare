import 'dart:convert';
import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;

class DownloadService {
  static const String _key = 'downloaded_videos';

  // Get list of downloaded video metadata
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

  // Check if a video is already downloaded and return valid path
  static Future<String?> getLocalPath(String videoUrl) async {
    final downloads = await getDownloadedVideos();
    for (var video in downloads) {
      if (video['video_url'] == videoUrl) {
        final path = video['local_path'];
        if (path != null && await File(path).exists()) {
          return path;
        }
      }
    }
    return null;
  }

  /// Downloads and converts M3U8 to MP4 using FFmpegKit
  static Future<void> downloadVideo(
    Map<String, dynamic> videoData,
    Function(double) onProgress,
  ) async {
    final String videoUrl = videoData['video_url'];
    final appDir = await getApplicationDocumentsDirectory();

    // Create a unique filename for the MP4
    final fileName = "video_${DateTime.now().millisecondsSinceEpoch}.mp4";
    final savePath = p.join(appDir.path, fileName);

    // FFmpeg command to download and remux/convert to MP4
    // -y: overwrite output file if exists
    // -i: input url
    // -c copy: copy streams without re-encoding (fastest)
    // -bsf:a aac_adtstoasc: fix bitstream for some m3u8 sources
    final String command =
        "-y -i \"$videoUrl\" -c copy -bsf:a aac_adtstoasc \"$savePath\"";

    try {
      // Initial progress feedback (FFmpeg start)
      onProgress(0.1);

      // Execute FFmpeg
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        // Success
        final downloads = await getDownloadedVideos();

        // Prepare metadata for storage
        final Map<String, dynamic> metadata = {
          'title': videoData['title'],
          'video_url': videoUrl,
          'thumnail_image': videoData['thumnail_image'],
          'local_path': savePath,
          'downloaded_at': DateTime.now().toIso8601String(),
        };

        // Avoid duplicates in the list
        downloads.removeWhere((item) => item['video_url'] == videoUrl);
        downloads.add(metadata);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_key, jsonEncode(downloads));
        onProgress(1.0);
      } else if (ReturnCode.isCancel(returnCode)) {
        throw Exception("Download was cancelled.");
      } else {
        final logs = await session.getLogs();
        final lastLog = logs.isNotEmpty
            ? logs.last.getMessage()
            : "No details available";
        throw Exception("FFmpeg conversion failed: $lastLog");
      }
    } catch (e) {
      // Cleanup file if it exists but the process failed
      final file = File(savePath);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  static Future<void> deleteVideo(String videoUrl) async {
    final downloads = await getDownloadedVideos();
    String? pathToDelete;

    downloads.removeWhere((v) {
      if (v['video_url'] == videoUrl) {
        pathToDelete = v['local_path'];
        return true;
      }
      return false;
    });

    if (pathToDelete != null) {
      final file = File(pathToDelete!);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (e) {
          // Log error but continue updating prefs
        }
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(downloads));
  }
}
