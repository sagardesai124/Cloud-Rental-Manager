import 'package:three_zero_two_property/services/app_log.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

// Unified Camera Interface for capturing both photos and videos
class CameraCaptureScreen extends StatefulWidget {
  final CameraDescription camera;
  final Function(File) onImageCaptured;
  final Function(File) onVideoCaptured;

  const CameraCaptureScreen({
    Key? key,
    required this.camera,
    required this.onImageCaptured,
    required this.onVideoCaptured,
  }) : super(key: key);

  @override
  _CameraCaptureScreenState createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  CameraController? _controller;
  bool _isRecording = false;
  bool _isFlashOn = false;
  bool _isFrontCamera = false;
  List<CameraDescription>? _cameras;
  String _captureMode = 'photo'; // 'photo' or 'video'
  int _recordingDuration = 0;
  Timer? _recordingTimer;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      // Dispose existing controller if any
      await _controller?.dispose();

      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        if (mounted) {
          setState(() {
            _isInitialized = false;
          });
        }
        return;
      }

      // Use the appropriate camera (back camera by default, front if requested)
      final camera = _cameras![_isFrontCamera && _cameras!.length > 1 ? 1 : 0];

      _controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: true,
      );

      await _controller!.initialize().timeout(
        Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Camera initialization timeout');
        },
      );
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      logError('Error initializing camera: $e');
      if (mounted) {
        setState(() {
          _isInitialized = false;
        });
        // Show error dialog
        _showCameraErrorDialog();
      }
    }
  }

  void _showCameraErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Camera Error'),
        content: Text(
            'Failed to initialize camera. Please check camera permissions and try again.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Close camera screen
            },
            child: Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _initializeCamera(); // Retry initialization
            },
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    if (_controller == null || !_isInitialized) {
      return;
    }

    try {
      final XFile photo = await _controller!.takePicture();
      widget.onImageCaptured(File(photo.path));
      Navigator.pop(context);
    } catch (e) {
      logError('Error capturing photo: $e');
    }
  }

  Future<void> _startVideoRecording() async {
    if (_controller == null || !_isInitialized) {
      return;
    }

    try {
      await _controller!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _recordingDuration = 0;
      });

      _recordingTimer = Timer.periodic(Duration(seconds: 1), (timer) {
        setState(() {
          _recordingDuration++;
        });
      });
    } catch (e) {
      logError('Error starting video recording: $e');
    }
  }

  Future<void> _stopVideoRecording() async {
    if (_controller == null || !_isInitialized) {
      return;
    }

    try {
      final XFile video = await _controller!.stopVideoRecording();
      setState(() {
        _isRecording = false;
        _recordingDuration = 0;
      });
      _recordingTimer?.cancel();

      // The camera plugin writes the recording to a temp path that often has
      // no video extension (e.g. a `.temp` file on Android). Without a known
      // video extension the upload can't detect its MIME type and the server
      // rejects it as `application/octet-stream`. Ensure the file carries a
      // `.mp4` extension so it is recognised as a video, matching how
      // gallery-picked videos already upload successfully.
      final File recorded = await _ensureVideoExtension(File(video.path));

      widget.onVideoCaptured(recorded);
      Navigator.pop(context);
    } catch (e) {
      logError('Error stopping video recording: $e');
    }
  }

  // Returns a File whose name ends in a recognised video extension. If the
  // recorded file already has one (e.g. iOS `.mov`) it is returned unchanged;
  // otherwise the file is copied to a sibling `.mp4` path so the upload can
  // detect its video MIME type. Falls back to the original file if the copy
  // fails for any reason.
  Future<File> _ensureVideoExtension(File file) async {
    const videoExtensions = ['.mp4', '.mov', '.webm', '.m4v'];
    final String lowerPath = file.path.toLowerCase();
    final bool hasVideoExtension =
        videoExtensions.any((ext) => lowerPath.endsWith(ext));
    if (hasVideoExtension) {
      return file;
    }
    try {
      final String newPath = '${file.path}.mp4';
      return await file.copy(newPath);
    } catch (e) {
      logError('Error normalising recorded video extension: $e');
      return file;
    }
  }

  void _toggleFlash() {
    if (_controller == null || !_isInitialized) return;

    setState(() {
      _isFlashOn = !_isFlashOn;
    });
    _controller!.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
  }

  void _switchCamera() {
    if (_cameras == null || _cameras!.length <= 1) return;

    setState(() {
      _isFrontCamera = !_isFrontCamera;
      _isInitialized = false;
    });
    _initializeCamera();
  }

  void _toggleCaptureMode() {
    setState(() {
      _captureMode = _captureMode == 'photo' ? 'video' : 'photo';
    });
  }

  String _formatDuration(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 20),
              Text(
                'Initializing Camera...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          Positioned.fill(
            child: CameraPreview(_controller!),
          ),

          // Top controls
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Close button
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: Colors.white, size: 30),
                ),

                // Flash toggle
                IconButton(
                  onPressed: _toggleFlash,
                  icon: Icon(
                    _isFlashOn ? Icons.flash_on : Icons.flash_off,
                    color: Colors.white,
                    size: 30,
                  ),
                ),

                // Switch camera
                if (_cameras!.length > 1)
                  IconButton(
                    onPressed: _switchCamera,
                    icon: Icon(Icons.flip_camera_ios,
                        color: Colors.white, size: 30),
                  ),
              ],
            ),
          ),

          // Recording indicator
          if (_isRecording)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              left: 20,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      _formatDuration(_recordingDuration),
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom controls
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 20,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Capture mode toggle
                Container(
                  margin: EdgeInsets.only(bottom: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildModeButton('photo', Icons.camera_alt),
                      SizedBox(width: 40),
                      _buildModeButton('video', Icons.videocam),
                    ],
                  ),
                ),

                // Capture controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Gallery button
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                          // Open gallery picker
                        },
                        icon: Icon(Icons.photo_library, color: Colors.white),
                      ),
                    ),

                    // Capture button
                    GestureDetector(
                      onTap: _captureMode == 'photo'
                          ? _capturePhoto
                          : (_isRecording
                              ? _stopVideoRecording
                              : _startVideoRecording),
                      onLongPress:
                          _captureMode == 'video' ? _startVideoRecording : null,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: _isRecording ? Colors.red : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: Icon(
                          _captureMode == 'photo'
                              ? Icons.camera_alt
                              : (_isRecording ? Icons.stop : Icons.videocam),
                          color: _captureMode == 'photo'
                              ? Colors.black
                              : Colors.white,
                          size: 30,
                        ),
                      ),
                    ),

                    // Placeholder for symmetry
                    Container(width: 50, height: 50),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(String mode, IconData icon) {
    bool isSelected = _captureMode == mode;
    return GestureDetector(
      onTap: () => _toggleCaptureMode(),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.3),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.black : Colors.white,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              mode.toUpperCase(),
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
