import 'dart:async';
import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_protector/screen_protector.dart'; // Updated package for better compatibility
import 'package:native_device_orientation/native_device_orientation.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;
  final String? localPath;

  const VideoPlayerScreen({
    super.key,
    required this.videoUrl,
    required this.title,
    this.localPath,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  StreamSubscription<NativeDeviceOrientation>? _orientationSubscription;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _enableScreenSecurity(); // Enable restriction on entry
    _initializePlayer();
  }

  /// Restricts screen recording and screenshots using screen_protector.
  /// preventScreenshotOn() handles both screenshots and screen recording on Android.
  Future<void> _enableScreenSecurity() async {
    try {
      // Prevents screenshots and screen recording on Android and iOS
      await ScreenProtector.preventScreenshotOn();
    } catch (e) {
      debugPrint("Security activation failed: $e");
    }
  }

  /// Disables the restriction when exiting the player
  Future<void> _disableScreenSecurity() async {
    try {
      // Re-allows screenshots and screen recording
      await ScreenProtector.preventScreenshotOff();
    } catch (e) {
      debugPrint("Security deactivation failed: $e");
    }
  }

  Future<void> _initializePlayer() async {
    try {
      if (widget.localPath != null && await File(widget.localPath!).exists()) {
        _videoPlayerController = VideoPlayerController.file(
          File(widget.localPath!),
        );
      } else {
        _videoPlayerController = VideoPlayerController.networkUrl(
          Uri.parse(widget.videoUrl),
        );
      }

      await _videoPlayerController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        autoPlay: true,
        looping: false,
        showControls: true,
        allowedScreenSleep: false,
        allowFullScreen: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.blueAccent,
          handleColor: Colors.blueAccent,
          backgroundColor: Colors.white24,
          bufferedColor: Colors.white54,
        ),
        placeholder: Container(color: Colors.black),
        autoInitialize: true,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.white70,
                  size: 42,
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    errorMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          );
        },
      );

      _orientationSubscription = NativeDeviceOrientationCommunicator()
          .onOrientationChanged(useSensor: true)
          .listen((event) {
            if (!mounted || _chewieController == null) return;

            final isLandscape =
                event == NativeDeviceOrientation.landscapeLeft ||
                event == NativeDeviceOrientation.landscapeRight;
            final isPortrait =
                event == NativeDeviceOrientation.portraitUp ||
                event == NativeDeviceOrientation.portraitDown;

            if (isLandscape && !_chewieController!.isFullScreen) {
              _chewieController!.enterFullScreen();
            } else if (isPortrait && _chewieController!.isFullScreen) {
              _chewieController!.exitFullScreen();
            }
          });

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint("Video initialization failed: $e");
    }
  }

  @override
  void dispose() {
    _disableScreenSecurity(); // Disable restriction on exit
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _orientationSubscription?.cancel();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              if (widget.localPath != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 8,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Offline Mode',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.green.shade300,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        body: Center(
          child: _isInitialized && _chewieController != null
              ? AspectRatio(
                  aspectRatio: _videoPlayerController!.value.aspectRatio,
                  child: Chewie(controller: _chewieController!),
                )
              : const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: Colors.blueAccent,
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 24),
                    Text(
                      "Securing your connection...",
                      style: TextStyle(color: Colors.white60),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
