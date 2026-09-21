import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class VideoPlayerDialog extends StatefulWidget {
  final String? videoUrl; // Network video URL
  final File? videoFile; // Local video file

  const VideoPlayerDialog({
    Key? key,
    this.videoUrl,
    this.videoFile,
  }) : super(key: key);

  @override
  _VideoPlayerDialogState createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<VideoPlayerDialog> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;

  /// Set when initialisation fails. Previously an exception from
  /// [VideoPlayerController.initialize] escaped `_initializePlayer`, so the
  /// `setState` below never ran and the dialog sat on its spinner forever -
  /// a black box with no way to tell a slow network from a dead one.
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    if (mounted) setState(() => _error = null);
    try {
      if (widget.videoFile != null) {
        _videoPlayerController = VideoPlayerController.file(widget.videoFile!);
      } else if (widget.videoUrl != null) {
        // networkUrl, not the deprecated network(String).
        _videoPlayerController =
            VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl!));
      } else {
        throw Exception('Either videoUrl or videoFile must be provided.');
      }

      await _videoPlayerController!.initialize();
      if (!mounted) return;

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        allowPlaybackSpeedChanging: true,
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      // A streamed video that stalls used to leave the spinner running with no
      // explanation and no way back except closing the dialog.
      setState(() => _error = 'Could not load this video. Please try again.');
    }
  }

  Future<void> _retry() async {
    await _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _videoPlayerController = null;
    _chewieController = null;
    await _initializePlayer();
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      child: IntrinsicWidth(
        child: IntrinsicHeight(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(00),
                child: _error != null
                    ? Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.white70, size: 40),
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: _retry,
                              child: const Text('Retry',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      )
                    : (_chewieController != null &&
                            _chewieController!
                                .videoPlayerController.value.isInitialized)
                        ? AspectRatio(
                            aspectRatio:
                                _videoPlayerController!.value.aspectRatio,
                            child: Chewie(controller: _chewieController!),
                          )
                        : const Padding(
                            padding: EdgeInsets.all(60),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SpinKitFadingCircle(
                                    color: Colors.white, size: 40.0),
                                SizedBox(height: 16),
                                // Says what the wait is for: a streamed clip
                                // can take a while, and a bare spinner on
                                // black reads as a frozen screen.
                                Text('Loading video...',
                                    style: TextStyle(color: Colors.white70)),
                              ],
                            ),
                          ),
              ),
              Positioned(
                top: -50, // Moves the close button above the container
                right: 0,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
